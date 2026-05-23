import 'dart:typed_data';
import '../../models/markdown_file.dart';
import '../export_service.dart';
import 'docx_format.dart';

class PagesFormat implements ExportFormat {
  @override
  String get label => 'Open in Pages';
  @override
  String get fileExtension => 'docx';
  @override
  List<String> get utTypes => [];
  @override
  bool get skipSavePanel => true;

  @override
  Future<Uint8List> generate(MarkdownFile file) => DocxFormat().generate(file);
}
