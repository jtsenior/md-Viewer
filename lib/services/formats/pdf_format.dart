import 'dart:io';
import 'dart:typed_data';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/markdown_file.dart';
import '../../utils/markdown_splitter.dart';
import '../export_service.dart';
import '../mermaid_renderer.dart';

class PdfFormat implements ExportFormat {
  pw.Font? _monoFont;
  pw.Font? _unicodeFont;

  @override
  String get label => 'PDF';
  @override
  String get fileExtension => 'pdf';
  @override
  List<String> get utTypes => ['com.adobe.pdf'];
  @override
  bool get skipSavePanel => false;

  // TTC files can leave null glyph state — only attempt plain .ttf/.otf files.
  Future<pw.Font?> _loadFont(List<String> candidates) async {
    for (final path in candidates) {
      try {
        final bytes = File(path).readAsBytesSync();
        return pw.Font.ttf(bytes.buffer.asByteData());
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<Uint8List> generate(MarkdownFile file) async {
    _monoFont = await _loadFont([
      '/System/Library/Fonts/Supplemental/Courier New.ttf',
      '/Library/Fonts/Courier New.ttf',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
      '/Library/Fonts/Andale Mono.ttf',
    ]) ?? pw.Font.courier();

    // Arial Unicode covers the full BMP including ⌘, ⌥, ⇧ and all symbol blocks.
    _unicodeFont = await _loadFont([
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
      '/Library/Fonts/Arial Unicode.ttf',
    ]);

    // Pre-build all widgets, fetching mermaid PNGs asynchronously before
    // entering the synchronous pw.MultiPage builder.
    final segments = MarkdownSplitter.split(file.content);
    final widgets = <pw.Widget>[];

    for (final segment in segments) {
      if (segment.isMermaid) {
        final bytes = await MermaidRenderer.renderToPng(segment.content);
        if (bytes != null) {
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Image(pw.MemoryImage(bytes)),
          ));
        } else {
          widgets.add(_codeBlockWidget(segment.content));
        }
      } else {
        final nodes = md.Document(
          extensionSet: md.ExtensionSet.gitHubFlavored,
        ).parse(segment.content);
        widgets.addAll(_buildNodes(nodes));
      }
    }

    final doc = pw.Document(title: file.name);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => widgets,
      ),
    );

    return doc.save();
  }

  // Splits text into runs: characters inside Latin-1 use the monospace font;
  // characters outside (e.g. ⌘, ⌥, arrows) fall back to the Unicode font so
  // they render instead of appearing as boxes.
  pw.InlineSpan _monoSpans(String text, {double fontSize = 10}) {
    if (_unicodeFont == null) {
      return pw.TextSpan(
        text: text,
        style: pw.TextStyle(font: _monoFont ?? pw.Font.courier(), fontSize: fontSize),
      );
    }
    final spans = <pw.InlineSpan>[];
    final buf = StringBuffer();
    bool inMono = true;

    void flush(bool nextIsMono) {
      if (buf.isNotEmpty) {
        spans.add(pw.TextSpan(
          text: buf.toString(),
          style: pw.TextStyle(
            font: inMono ? (_monoFont ?? pw.Font.courier()) : _unicodeFont!,
            fontSize: fontSize,
          ),
        ));
        buf.clear();
      }
      inMono = nextIsMono; // always update so the first char picks the right font
    }

    for (final rune in text.runes) {
      final wantsMono = rune <= 0xFF;
      if (wantsMono != inMono) flush(wantsMono);
      buf.writeCharCode(rune);
    }
    flush(inMono);

    if (spans.length == 1) return spans.first;
    return pw.TextSpan(children: spans);
  }

  pw.Widget _codeBlockWidget(String code) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.RichText(text: _monoSpans(code)),
        ),
      );

  List<pw.Widget> _buildNodes(List<md.Node> nodes) {
    final widgets = <pw.Widget>[];
    for (final node in nodes) {
      final w = _node(node);
      if (w != null) widgets.add(w);
    }
    return widgets;
  }

  pw.Widget? _node(md.Node node) {
    if (node is md.Element) {
      return _element(node);
    }
    return null;
  }

  pw.Widget? _element(md.Element el) {
    switch (el.tag) {
      case 'h1':
        return _heading(el, 24);
      case 'h2':
        return _heading(el, 20);
      case 'h3':
        return _heading(el, 16);
      case 'h4':
        return _heading(el, 14);
      case 'h5':
        return _heading(el, 13);
      case 'h6':
        return _heading(el, 12);
      case 'p':
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.RichText(text: _inlineSpan(el.children ?? [])),
        );
      case 'pre':
        return _codeBlockWidget(_innerText(el).trim());
      case 'blockquote':
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 3,
                color: PdfColors.grey400,
                margin: const pw.EdgeInsets.only(right: 8),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: _buildNodes(el.children ?? []),
                ),
              ),
            ],
          ),
        );
      case 'ul':
        return _list(el, ordered: false);
      case 'ol':
        return _list(el, ordered: true);
      case 'hr':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Divider(color: PdfColors.grey400),
        );
      case 'table':
        return _table(el);
      default:
        // Recurse into unknown block containers
        if (el.children != null) {
          final children = _buildNodes(el.children!);
          if (children.isNotEmpty) return pw.Column(children: children);
        }
        return null;
    }
  }

  pw.Widget _heading(md.Element el, double size) {
    final style = pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.RichText(text: _bodySpan(_innerText(el), style)),
    );
  }

  pw.Widget _list(md.Element el, {required bool ordered}) {
    final items = (el.children ?? [])
        .whereType<md.Element>()
        .where((e) => e.tag == 'li')
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8, left: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final prefixWidget = ordered
              ? pw.SizedBox(
                  width: 20,
                  child: pw.Text(
                    '${entry.key + 1}.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                )
              : pw.SizedBox(
                  width: 20,
                  child: pw.Align(
                    alignment: pw.Alignment.topLeft,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.SizedBox(
                        width: 3,
                        height: 3,
                        child: pw.DecoratedBox(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.black,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              prefixWidget,
              pw.Expanded(
                child: pw.RichText(
                  text: _inlineSpan(entry.value.children ?? []),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  pw.Widget? _table(md.Element el) {
    final rows = <md.Element>[];
    for (final child in el.children ?? []) {
      if (child is md.Element) {
        if (child.tag == 'thead' || child.tag == 'tbody') {
          rows.addAll(
            (child.children ?? []).whereType<md.Element>().where((e) => e.tag == 'tr'),
          );
        } else if (child.tag == 'tr') {
          rows.add(child);
        }
      }
    }
    if (rows.isEmpty) return null;

    final colCount = rows
        .map((r) => (r.children ?? []).whereType<md.Element>().where((e) => e.tag == 'td' || e.tag == 'th').length)
        .fold(0, (a, b) => a > b ? a : b);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: colCount > 0
            ? {for (int i = 0; i < colCount; i++) i: const pw.FlexColumnWidth(1)}
            : null,
        children: rows.map((row) {
          final cells = (row.children ?? [])
              .whereType<md.Element>()
              .where((e) => e.tag == 'td' || e.tag == 'th');
          return pw.TableRow(
            children: cells.map((cell) {
              final style = cell.tag == 'th'
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
                  : const pw.TextStyle(fontSize: 10);
              return pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.RichText(
                  text: _bodySpan(_innerText(cell), style),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  pw.InlineSpan _inlineSpan(List<md.Node> nodes) {
    if (nodes.isEmpty) return const pw.TextSpan(text: '');
    if (nodes.length == 1) return _singleSpan(nodes.first, const pw.TextStyle());
    return pw.TextSpan(
      children: nodes.map((n) => _singleSpan(n, const pw.TextStyle())).toList(),
    );
  }

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  // Normalise typography; Unicode font handles actual symbol rendering.
  String _sanitize(String s) => _decodeEntities(s)
      .replaceAll('—', '--')  // em dash
      .replaceAll('–', '-')   // en dash
      .replaceAll(' ', ' ');  // non-breaking space


  pw.InlineSpan _singleSpan(md.Node node, pw.TextStyle base) {
    if (node is md.Text) {
      return _bodySpan(_sanitize(node.text), base.copyWith(fontSize: 11));
    }
    if (node is md.Element) {
      pw.TextStyle style = base.copyWith(fontSize: 11);
      switch (node.tag) {
        case 'strong':
          style = style.copyWith(fontWeight: pw.FontWeight.bold);
          break;
        case 'em':
          style = style.copyWith(fontStyle: pw.FontStyle.italic);
          break;
        case 'code':
          final text = _sanitize(
            node.children?.whereType<md.Text>().map((t) => t.text).join() ??
                node.textContent,
          );
          return _monoSpans(text, fontSize: 10);
        case 'a':
          style = style.copyWith(color: PdfColors.blue700);
          break;
      }
      if (node.children == null || node.children!.isEmpty) {
        return _bodySpan(_sanitize(node.textContent), style);
      }
      return pw.TextSpan(
        children: node.children!.map((c) => _singleSpan(c, style)).toList(),
      );
    }
    return const pw.TextSpan(text: '');
  }

  // For body text: characters outside Latin-1 switch to the Unicode font inline.
  pw.InlineSpan _bodySpan(String text, pw.TextStyle style) {
    if (_unicodeFont == null || text.runes.every((r) => r <= 0xFF)) {
      return pw.TextSpan(text: text, style: style);
    }
    final spans = <pw.InlineSpan>[];
    final buf = StringBuffer();
    bool inBase = true;

    void flush(bool nextIsBase) {
      if (buf.isNotEmpty) {
        spans.add(pw.TextSpan(
          text: buf.toString(),
          style: inBase ? style : style.copyWith(font: _unicodeFont),
        ));
        buf.clear();
      }
      inBase = nextIsBase; // always update so the first char picks the right font
    }

    for (final rune in text.runes) {
      final wantsBase = rune <= 0xFF;
      if (wantsBase != inBase) flush(wantsBase);
      buf.writeCharCode(rune);
    }
    flush(inBase);

    return spans.length == 1 ? spans.first : pw.TextSpan(children: spans);
  }

  String _innerText(md.Element el) {
    final buf = StringBuffer();
    for (final child in el.children ?? []) {
      if (child is md.Text) buf.write(_sanitize(child.text));
      if (child is md.Element) buf.write(_innerText(child));
    }
    return buf.toString();
  }
}
