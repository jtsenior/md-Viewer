import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:markdown/markdown.dart' as md;
import '../../models/markdown_file.dart';
import '../../utils/markdown_splitter.dart';
import '../export_service.dart';
import '../mermaid_renderer.dart';

class DocxFormat implements ExportFormat {
  @override
  String get label => 'Word (.docx)';
  @override
  String get fileExtension => 'docx';
  @override
  List<String> get utTypes => [
        'org.openxmlformats.wordprocessingml.document',
        'com.microsoft.word.doc',
      ];
  @override
  bool get skipSavePanel => false;

  @override
  Future<Uint8List> generate(MarkdownFile file) async {
    final segments = MarkdownSplitter.split(file.content);
    final body = StringBuffer();
    final imageEntries = <({String rId, String fileName, Uint8List bytes})>[];
    int imgIdx = 0;

    for (final segment in segments) {
      if (segment.isMermaid) {
        final bytes = await MermaidRenderer.renderToPng(segment.content);
        if (bytes != null) {
          final rId = 'rIdImg$imgIdx';
          final fileName = 'mermaid_$imgIdx.png';
          imageEntries.add((rId: rId, fileName: fileName, bytes: bytes));
          final dims = MermaidRenderer.pngDimensions(bytes);
          body.write(_drawingPara(rId, dims.$1, dims.$2, imgIdx));
          imgIdx++;
        } else {
          body.write(_para(_codeRun(segment.content), style: 'CodeBlock'));
        }
      } else {
        final nodes = md.Document(
          extensionSet: md.ExtensionSet.gitHubFlavored,
        ).parse(segment.content);
        for (final node in nodes) {
          if (node is md.Element) _writeElement(node, body);
        }
      }
    }

    final imageRels = imageEntries.map((e) =>
        '<Relationship Id="${e.rId}"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'
        ' Target="media/${e.fileName}"/>').join('\n  ');

    final archive = Archive()
      ..addFile(_utf8File('[Content_Types].xml', _contentTypes(hasImages: imageEntries.isNotEmpty)))
      ..addFile(_utf8File('_rels/.rels', _rels()))
      ..addFile(_utf8File('word/document.xml', _document(body.toString())))
      ..addFile(_utf8File('word/_rels/document.xml.rels', _documentRels(imageRels)))
      ..addFile(_utf8File('word/styles.xml', _styles()))
      ..addFile(_utf8File('word/settings.xml', _settings()));

    for (final e in imageEntries) {
      archive.addFile(ArchiveFile('word/media/${e.fileName}', e.bytes.length, e.bytes));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // 1 twip = 635 EMU; content width = 9360 twips = 5,943,600 EMU
  String _drawingPara(String rId, int imgW, int imgH, int id) {
    const contentEmu = 5943600;
    const cx = contentEmu;
    final cy = imgW > 0 ? (contentEmu * imgH ~/ imgW) : 2000000;
    return '<w:p><w:r><w:drawing>'
        '<wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:docPr id="${id + 1}" name="Mermaid$id"/>'
        '<wp:cNvGraphicFramePr/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr>'
        '<pic:cNvPr id="${id + 1}" name="Mermaid$id"/>'
        '<pic:cNvPicPr/>'
        '</pic:nvPicPr>'
        '<pic:blipFill>'
        '<a:blip r:embed="$rId"/>'
        '<a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill>'
        '<pic:spPr>'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '</pic:spPr>'
        '</pic:pic>'
        '</a:graphicData>'
        '</a:graphic>'
        '</wp:inline>'
        '</w:drawing></w:r></w:p>';
  }

  void _writeElement(md.Element el, StringBuffer out) {
    switch (el.tag) {
      case 'h1':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading1'));
      case 'h2':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading2'));
      case 'h3':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading3'));
      case 'h4':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading4'));
      case 'h5':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading5'));
      case 'h6':
        out.write(_para(_inlineRuns(el.children ?? []), style: 'Heading6'));
      case 'p':
        out.write(_para(_inlineRuns(el.children ?? [])));
      case 'pre':
        out.write(_para(_codeRun(_innerText(el).trim()), style: 'CodeBlock'));
      case 'blockquote':
        for (final child in el.children ?? []) {
          if (child is md.Element) _writeElement(child, out);
        }
      case 'ul':
        _writeList(el, out, ordered: false);
      case 'ol':
        _writeList(el, out, ordered: true);
      case 'hr':
        out.write(_horizontalRule());
      case 'table':
        _writeTable(el, out);
      default:
        for (final child in el.children ?? []) {
          if (child is md.Element) _writeElement(child, out);
        }
    }
  }

  void _writeList(md.Element el, StringBuffer out, {required bool ordered}) {
    int index = 1;
    for (final child in el.children ?? []) {
      if (child is md.Element && child.tag == 'li') {
        final prefix = ordered ? '${index++}.' : '•';
        // Bullet/number run + tab run + content runs — all proper <w:r> elements
        final prefixRun = _run(prefix);
        const tabRun = '<w:r><w:tab/></w:r>';
        final contentRuns = _inlineRuns(child.children ?? []);
        out.write(_para('$prefixRun$tabRun$contentRuns', style: 'ListParagraph'));
      }
    }
  }

  void _writeTable(md.Element el, StringBuffer out) {
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
    if (rows.isEmpty) return;

    final colCount = rows
        .map((r) => (r.children ?? []).whereType<md.Element>().where((e) => e.tag == 'td' || e.tag == 'th').length)
        .fold(0, (a, b) => a > b ? a : b);
    // Page is 12240 twips wide, 1440-twip margins each side → 9360 twips content width
    const contentDxa = 9360;
    final colWidthDxa = colCount > 0 ? (contentDxa ~/ colCount) : contentDxa;

    final tblGrid = StringBuffer('<w:tblGrid>');
    for (int i = 0; i < colCount; i++) {
      tblGrid.write('<w:gridCol w:w="$colWidthDxa"/>');
    }
    tblGrid.write('</w:tblGrid>');

    out.write('<w:tbl>'
        '<w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="$contentDxa" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/></w:tblPr>'
        '$tblGrid');
    for (final row in rows) {
      out.write('<w:tr>');
      for (final cell in (row.children ?? []).whereType<md.Element>()) {
        if (cell.tag != 'td' && cell.tag != 'th') continue;
        final bold = cell.tag == 'th';
        out.write('<w:tc>'
            '<w:tcPr><w:tcW w:w="$colWidthDxa" w:type="dxa"/></w:tcPr>'
            '<w:p><w:r>');
        if (bold) out.write('<w:rPr><w:b/></w:rPr>');
        out.write('<w:t xml:space="preserve">${_escape(_innerText(cell))}</w:t>');
        out.write('</w:r></w:p></w:tc>');
      }
      out.write('</w:tr>');
    }
    out.write('</w:tbl>');
  }

  String _para(String runs, {String style = 'Normal'}) {
    return '<w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr>$runs</w:p>';
  }

  String _inlineRuns(List<md.Node> nodes) {
    final buf = StringBuffer();
    for (final node in nodes) {
      buf.write(_inlineRun(node, bold: false, italic: false, code: false));
    }
    return buf.toString();
  }

  String _inlineRun(
    md.Node node, {
    required bool bold,
    required bool italic,
    required bool code,
  }) {
    if (node is md.Text) {
      return _run(node.text, bold: bold, italic: italic, code: code);
    }
    if (node is md.Element) {
      final b = bold || node.tag == 'strong';
      final i = italic || node.tag == 'em';
      final c = code || node.tag == 'code';
      final buf = StringBuffer();
      for (final child in node.children ?? []) {
        buf.write(_inlineRun(child, bold: b, italic: i, code: c));
      }
      if (buf.isEmpty) {
        return _run(node.textContent, bold: b, italic: i, code: c);
      }
      return buf.toString();
    }
    return '';
  }

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  String _run(String text, {bool bold = false, bool italic = false, bool code = false}) {
    final t = _decodeEntities(text);
    if (t.isEmpty) return '';
    final props = StringBuffer('<w:rPr>');
    if (bold) props.write('<w:b/>');
    if (italic) props.write('<w:i/>');
    if (code) props.write('<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>');
    props.write('</w:rPr>');
    return '<w:r>$props<w:t xml:space="preserve">${_escape(t)}</w:t></w:r>';
  }

  String _codeRun(String text) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>'
      '<w:sz w:val="18"/></w:rPr>'
      '<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';

  String _horizontalRule() =>
      '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" '
      'w:color="999999"/></w:pBdr></w:pPr></w:p>';

  String _innerText(md.Element el) {
    final buf = StringBuffer();
    for (final child in el.children ?? []) {
      if (child is md.Text) buf.write(_decodeEntities(child.text));
      if (child is md.Element) buf.write(_innerText(child));
    }
    return buf.toString();
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  ArchiveFile _utf8File(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  // ── DOCX XML stubs ────────────────────────────────────────────────────────

  String _contentTypes({bool hasImages = false}) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '${hasImages ? '<Default Extension="png" ContentType="image/png"/>' : ''}'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '</Types>';

  String _rels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  String _documentRels(String extraRels) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>'
      '$extraRels'
      '</Relationships>';

  String _document(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"'
      ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<w:body>$body'
      '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'
      '</w:sectPr></w:body></w:document>';

  String _styles() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
    <w:rPr><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="48"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="28"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading5">
    <w:name w:val="heading 5"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading6">
    <w:name w:val="heading 6"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr><w:b/><w:i/><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="CodeBlock">
    <w:name w:val="Code Block"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:shd w:val="clear" w:color="auto" w:fill="F0F0F0"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/><w:sz w:val="18"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="360"/></w:pPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr><w:tblBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    </w:tblBorders></w:tblPr>
  </w:style>
</w:styles>''';

  String _settings() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
</w:settings>''';
}
