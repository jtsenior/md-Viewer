import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md_viewer/models/markdown_file.dart';
import 'package:md_viewer/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const _channel = MethodChannel('com.jtsworkshop.mdViewer/file');

  late FileService service;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = FileService();
    tempDir = await Directory.systemTemp.createTemp('md_viewer_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'createBookmark') return 'mock-bookmark';
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await tempDir.delete(recursive: true);
  });

  Future<File> writeTemp(String name, String content) async {
    final f = File('${tempDir.path}/$name');
    await f.writeAsString(content);
    return f;
  }

  group('FileService.getRecentFiles', () {
    test('returns empty list when prefs are empty', () async {
      expect(await service.getRecentFiles(), isEmpty);
    });

    test('returns only files that exist on disk', () async {
      final existing = await writeTemp('exists.md', '# Hello');
      const missingPath = '/nonexistent/path/missing.md';

      final prefs = await SharedPreferences.getInstance();
      MarkdownFile entry(String path, String name) => MarkdownFile(
            path: path,
            name: name,
            content: '',
            lastOpened: DateTime.utc(2024),
          );
      await prefs.setStringList('recent_files', [
        jsonEncode(entry(existing.path, 'exists').toJson()),
        jsonEncode(entry(missingPath, 'missing').toJson()),
      ]);

      final files = await service.getRecentFiles();
      expect(files.length, 1);
      expect(files[0].path, existing.path);
    });

    test('skips malformed JSON entries without throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_files', ['{bad json']);
      expect(await service.getRecentFiles(), isEmpty);
    });
  });

  group('FileService.removeFromRecent', () {
    test('removes the specified path and leaves others', () async {
      final f1 = await writeTemp('a.md', '# A');
      final f2 = await writeTemp('b.md', '# B');

      final prefs = await SharedPreferences.getInstance();
      String encoded(String path, String name) => jsonEncode(
            MarkdownFile(
              path: path,
              name: name,
              content: '',
              lastOpened: DateTime.utc(2024),
            ).toJson(),
          );
      await prefs.setStringList('recent_files', [
        encoded(f1.path, 'a'),
        encoded(f2.path, 'b'),
      ]);

      await service.removeFromRecent(f1.path);

      final files = await service.getRecentFiles();
      expect(files.map((f) => f.path), isNot(contains(f1.path)));
      expect(files.map((f) => f.path), contains(f2.path));
    });
  });

  group('FileService.readFile', () {
    test('reads content from disk and adds to recent files', () async {
      final f = await writeTemp('readme.md', '# Readme\nHello.');
      final result = await service.readFile(f.path);

      expect(result.content, '# Readme\nHello.');
      expect(result.name, 'readme');
      expect(result.path, f.path);

      final recent = await service.getRecentFiles();
      expect(recent.any((r) => r.path == f.path), true);
    });

    test('stores bookmark returned by native channel', () async {
      final f = await writeTemp('note.md', '# Note');
      final result = await service.readFile(f.path);
      expect(result.bookmarkData, 'mock-bookmark');
    });
  });

  group('FileService.fileFromContent', () {
    test('stores provided content and path', () async {
      final f = await writeTemp('doc.md', '');
      final result = await service.fileFromContent(f.path, '# Doc content');

      expect(result.path, f.path);
      expect(result.name, 'doc');
      expect(result.content, '# Doc content');
    });

    test('stores provided bookmarkData', () async {
      final f = await writeTemp('doc.md', '');
      final result = await service.fileFromContent(
        f.path,
        '# Doc',
        bookmarkData: 'supplied-bookmark',
      );
      expect(result.bookmarkData, 'supplied-bookmark');
    });

    test('adds file to recent files', () async {
      final f = await writeTemp('doc.md', '');
      await service.fileFromContent(f.path, '# Doc');

      final recent = await service.getRecentFiles();
      expect(recent.any((r) => r.path == f.path), true);
    });
  });
}
