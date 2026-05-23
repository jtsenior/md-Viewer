import 'dart:typed_data';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/markdown_file.dart';
import '../export_service.dart';

class PdfFormat implements ExportFormat {
  @override
  String get label => 'PDF';
  @override
  String get fileExtension => 'pdf';
  @override
  List<String> get utTypes => ['com.adobe.pdf'];
  @override
  bool get skipSavePanel => false;

  @override
  Future<Uint8List> generate(MarkdownFile file) async {
    final doc = pw.Document(title: file.name);
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ).parse(file.content);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => _buildNodes(nodes),
      ),
    );

    return doc.save();
  }

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
        final code = _innerText(el).trim();
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              code,
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 10,
              ),
            ),
          ),
        );
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
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
      child: pw.Text(
        _innerText(el),
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
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
          final bullet = ordered ? '${entry.key + 1}.' : '•';
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 20,
                child: pw.Text(bullet, style: const pw.TextStyle(fontSize: 11)),
              ),
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

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: rows.map((row) {
          final cells = (row.children ?? [])
              .whereType<md.Element>()
              .where((e) => e.tag == 'td' || e.tag == 'th');
          return pw.TableRow(
            children: cells.map((cell) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _innerText(cell),
                  style: cell.tag == 'th'
                      ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
                      : const pw.TextStyle(fontSize: 10),
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

  pw.InlineSpan _singleSpan(md.Node node, pw.TextStyle base) {
    if (node is md.Text) {
      return pw.TextSpan(text: node.text, style: base.copyWith(fontSize: 11));
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
          style = style.copyWith(font: pw.Font.courier(), fontSize: 10);
          break;
        case 'a':
          style = style.copyWith(color: PdfColors.blue700);
          break;
      }
      if (node.children == null || node.children!.isEmpty) {
        return pw.TextSpan(text: node.textContent, style: style);
      }
      return pw.TextSpan(
        children: node.children!.map((c) => _singleSpan(c, style)).toList(),
      );
    }
    return const pw.TextSpan(text: '');
  }

  String _innerText(md.Element el) {
    final buf = StringBuffer();
    for (final child in el.children ?? []) {
      if (child is md.Text) buf.write(child.text);
      if (child is md.Element) buf.write(_innerText(child));
    }
    return buf.toString();
  }
}
