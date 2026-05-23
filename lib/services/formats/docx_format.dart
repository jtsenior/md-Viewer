import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:markdown/markdown.dart' as md;
import '../../models/markdown_file.dart';
import '../export_service.dart';

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
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
    ).parse(file.content);

    final body = StringBuffer();
    for (final node in nodes) {
      if (node is md.Element) _writeElement(node, body);
    }

    final archive = Archive()
      ..addFile(_utf8File('[Content_Types].xml', _contentTypes()))
      ..addFile(_utf8File('_rels/.rels', _rels()))
      ..addFile(_utf8File('word/document.xml', _document(body.toString())))
      ..addFile(_utf8File('word/_rels/document.xml.rels', _documentRels()))
      ..addFile(_utf8File('word/styles.xml', _styles()))
      ..addFile(_utf8File('word/settings.xml', _settings()));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  void _writeElement(md.Element el, StringBuffer out, {int listDepth = 0}) {
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
        final runs = _inlineRuns(child.children ?? []);
        out.write(_para('$prefix\t$runs', style: 'ListParagraph'));
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

    out.write('<w:tbl>'
        '<w:tblPr><w:tblStyle w:val="TableGrid"/>'
        '<w:tblW w:w="0" w:type="auto"/></w:tblPr>');
    for (final row in rows) {
      out.write('<w:tr>');
      for (final cell in (row.children ?? []).whereType<md.Element>()) {
        if (cell.tag != 'td' && cell.tag != 'th') continue;
        final bold = cell.tag == 'th';
        out.write('<w:tc><w:p><w:r>');
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

  String _run(String text, {bool bold = false, bool italic = false, bool code = false}) {
    if (text.isEmpty) return '';
    final props = StringBuffer('<w:rPr>');
    if (bold) props.write('<w:b/>');
    if (italic) props.write('<w:i/>');
    if (code) props.write('<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>');
    props.write('</w:rPr>');
    return '<w:r>$props<w:t xml:space="preserve">${_escape(text)}</w:t></w:r>';
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
      if (child is md.Text) buf.write(child.text);
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
    final bytes = content.codeUnits;
    return ArchiveFile(name, bytes.length, bytes);
  }

  // ── DOCX XML stubs ────────────────────────────────────────────────────────

  String _contentTypes() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

  String _rels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  String _documentRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
</Relationships>''';

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
