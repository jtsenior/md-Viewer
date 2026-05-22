import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/markdown_file.dart';

class FileService {
  static const _recentFilesKey = 'recent_files';
  static const _maxRecentFiles = 10;

  Future<MarkdownFile?> openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt', 'mdown', 'mkd'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    return await readFile(filePath);
  }

  Future<MarkdownFile> readFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final name = p.basenameWithoutExtension(filePath);

    final mdFile = MarkdownFile(
      path: filePath,
      name: name,
      content: content,
      lastOpened: DateTime.now(),
    );

    await _addToRecent(mdFile);
    return mdFile;
  }

  Future<List<MarkdownFile>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_recentFilesKey) ?? [];

    final files = <MarkdownFile>[];
    for (final json in jsonList) {
      try {
        final mdFile = MarkdownFile.fromJson(jsonDecode(json));
        if (await File(mdFile.path).exists()) {
          files.add(mdFile);
        }
      } catch (_) {}
    }
    return files;
  }

  Future<void> _addToRecent(MarkdownFile file) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentFiles();

    final updated = [
      file,
      ...existing.where((f) => f.path != file.path),
    ].take(_maxRecentFiles).toList();

    await prefs.setStringList(
      _recentFilesKey,
      updated.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  Future<void> removeFromRecent(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentFiles();
    final updated = existing.where((f) => f.path != filePath).toList();
    await prefs.setStringList(
      _recentFilesKey,
      updated.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }
}
