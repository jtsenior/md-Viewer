import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md_viewer/models/markdown_file.dart';
import 'package:md_viewer/services/file_service.dart';

void main() {
  late FileService service;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = FileService();
    tempDir = await Directory.systemTemp.createTemp('md_viewer_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<File> _writeTemp(String name, String content) async {
    final f = File('${tempDir.path}/$name');
    await f.writeAsString(content);
    return f;
  }

  group('FileService.getRecentFiles', () {
    test('returns empty list when prefs are empty', () async {
      final files = await service.getRecentFiles();
      expect(files, isEmpty);
    });

    test('returns only files that exist on disk', () async {
      final existing = await _writeTemp('exists.md', '# Hello');
      const missing = '/nonexistent/path/missing.md';

      final prefs = await SharedPreferences.getInstance();
      final existingEntry = MarkdownFile(
        path: existing.path,
        name: 'exists',
        content: '',
        lastOpened: DateTime.utc(2024),
      );
      final missingEntry = MarkdownFile(
        path: missing,
        name: 'missing',
        content: '',
        lastOpened: DateTime.utc(2024),
      );
      await prefs.setStringList('recent_files', [
        jsonEncode(existingEntry.toJson()),
        jsonEncode(missingEntry.toJson()),
      ]);

      final files = await service.getRecentFiles();
      expect(files.length, 1);
      expect(files[0].path, existing.path);
    });

    test('skips malformed JSON entries without throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_files', ['{bad json']);
      final files = await service.getRecentFiles();
      expect(files, isEmpty);
    });
  });

  group('FileService.removeFromRecent', () {
    test('removes the specified path from prefs', () async {
      final f1 = await _writeTemp('a.md', '# A');
      final f2 = await _writeTemp('b.md', '# B');

      final prefs = await SharedPreferences.getInstance();
      final entry = (String path, String name) => jsonEncode(
            MarkdownFile(
              path: path,
              name: name,
              content: '',
              lastOpened: DateTime.utc(2024),
            ).toJson(),
          );
      await prefs.setStringList('recent_files', [
        entry(f1.path, 'a'),
        entry(f2.path, 'b'),
      ]);

      await service.removeFromRecent(f1.path);

      final files = await service.getRecentFiles();
      expect(files.map((f) => f.path), isNot(contains(f1.path)));
      expect(files.map((f) => f.path), contains(f2.path));
    });
  });

  group('FileService.readFile', () {
    test('reads content from disk and adds to recent files', () async {
      final f = await _writeTemp('readme.md', '# Readme\nHello.');
      final result = await service.readFile(f.path);

      expect(result.content, '# Readme\nHello.');
      expect(result.name, 'readme');
      expect(result.path, f.path);

      final recent = await service.getRecentFiles();
      expect(recent.any((r) => r.path == f.path), true);
    });
  });
}
