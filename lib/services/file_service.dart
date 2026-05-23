import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/markdown_file.dart';

class FileService {
  static const _recentFilesKey = 'recent_files';
  static const _maxRecentFiles = 10;
  static const _channel = MethodChannel('com.jtsworkshop.mdViewer/file');

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

  // Read a file, using a security-scoped bookmark when available (required for sandbox).
  Future<MarkdownFile> readFile(String filePath, {String? bookmarkData}) async {
    if (bookmarkData != null) {
      try {
        final info = await _channel.invokeMethod<Map>('readWithBookmark', bookmarkData);
        if (info != null) {
          final resolvedPath = info['path'] as String? ?? filePath;
          final content = info['content'] as String? ?? '';
          final freshBookmark = info['bookmark'] as String? ?? bookmarkData;
          return _makeAndRecord(resolvedPath, content, bookmarkData: freshBookmark);
        }
      } catch (_) {}
    }

    // Direct read — works within the same session (file picker / non-sandboxed).
    final content = await File(filePath).readAsString();
    final bookmark = await _createBookmark(filePath);
    return _makeAndRecord(filePath, content, bookmarkData: bookmark);
  }

  // Build a MarkdownFile from content already read on the native side (Open With / CLI).
  Future<MarkdownFile> fileFromContent(
    String filePath,
    String content, {
    String? bookmarkData,
  }) async {
    return _makeAndRecord(filePath, content, bookmarkData: bookmarkData);
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

  Future<void> removeFromRecent(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getRecentFiles();
    final updated = existing.where((f) => f.path != filePath).toList();
    await prefs.setStringList(
      _recentFilesKey,
      updated.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  Future<MarkdownFile> _makeAndRecord(
    String filePath,
    String content, {
    String? bookmarkData,
  }) async {
    final mdFile = MarkdownFile(
      path: filePath,
      name: p.basenameWithoutExtension(filePath),
      content: content,
      lastOpened: DateTime.now(),
      bookmarkData: bookmarkData,
    );
    await _addToRecent(mdFile);
    return mdFile;
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

  Future<String?> _createBookmark(String filePath) async {
    try {
      return await _channel.invokeMethod<String>('createBookmark', filePath);
    } catch (_) {
      return null;
    }
  }
}
