import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/markdown_file.dart';
import 'formats/pdf_format.dart';
import 'formats/docx_format.dart';
import 'formats/pages_format.dart';

abstract class ExportFormat {
  String get label;
  String get fileExtension;
  List<String> get utTypes;
  bool get skipSavePanel;
  Future<Uint8List> generate(MarkdownFile file);
}

class ExportService {
  static const _channel = MethodChannel('com.jtsworkshop.mdViewer/file');

  // "Open in Pages" only makes sense where Pages is installed.
  final List<ExportFormat> _formats = [
    PdfFormat(),
    DocxFormat(),
    if (Platform.isMacOS) PagesFormat(),
  ];

  List<ExportFormat> get formats => List.unmodifiable(_formats);

  void register(ExportFormat format) => _formats.add(format);

  Future<void> export(ExportFormat format, MarkdownFile file) async {
    final bytes = await format.generate(file);

    if (format.skipSavePanel) {
      // Pages: write to temp and open
      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/${file.name}.${format.fileExtension}';
      await File(tempPath).writeAsBytes(bytes);
      await launchUrl(Uri.file(tempPath));
      return;
    }

    final outputPath = await showSavePanel(
      suggestedName: '${file.name}.${format.fileExtension}',
      utTypes: format.utTypes,
    );
    if (outputPath == null) return; // user cancelled

    await File(outputPath).writeAsBytes(bytes);
  }

  Future<String?> showSavePanel({
    required String suggestedName,
    required List<String> utTypes,
  }) async {
    // Native NSSavePanel only exists on macOS; other platforms use file_picker's dialog.
    if (!Platform.isMacOS) {
      return FilePicker.platform.saveFile(fileName: suggestedName);
    }
    return _channel.invokeMethod<String>('showSavePanel', {
      'suggestedName': suggestedName,
      'utTypes': utTypes,
    });
  }
}
