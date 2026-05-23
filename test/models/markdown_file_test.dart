import 'package:flutter_test/flutter_test.dart';
import 'package:md_viewer/models/markdown_file.dart';

void main() {
  final base = DateTime.utc(2024, 6, 1, 12);

  group('MarkdownFile.toJson', () {
    test('includes path, name, and lastOpened', () {
      final f = MarkdownFile(
        path: '/docs/readme.md',
        name: 'readme',
        content: 'hello',
        lastOpened: base,
      );
      final j = f.toJson();
      expect(j['path'], '/docs/readme.md');
      expect(j['name'], 'readme');
      expect(j['lastOpened'], base.toIso8601String());
    });

    test('does not include content', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: 'secret',
        lastOpened: base,
      );
      expect(f.toJson().containsKey('content'), false);
    });

    test('omits bookmark key when bookmarkData is null', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: '',
        lastOpened: base,
      );
      expect(f.toJson().containsKey('bookmark'), false);
    });

    test('includes bookmark key when bookmarkData is set', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: '',
        lastOpened: base,
        bookmarkData: 'abc123',
      );
      expect(f.toJson()['bookmark'], 'abc123');
    });
  });

  group('MarkdownFile.fromJson', () {
    test('restores path, name, and lastOpened', () {
      final json = {
        'path': '/docs/readme.md',
        'name': 'readme',
        'lastOpened': base.toIso8601String(),
      };
      final f = MarkdownFile.fromJson(json);
      expect(f.path, '/docs/readme.md');
      expect(f.name, 'readme');
      expect(f.lastOpened, base);
    });

    test('always sets content to empty string', () {
      final json = {
        'path': '/a.md',
        'name': 'a',
        'lastOpened': base.toIso8601String(),
      };
      expect(MarkdownFile.fromJson(json).content, '');
    });

    test('restores bookmarkData when present', () {
      final json = {
        'path': '/a.md',
        'name': 'a',
        'lastOpened': base.toIso8601String(),
        'bookmark': 'abc123',
      };
      expect(MarkdownFile.fromJson(json).bookmarkData, 'abc123');
    });

    test('sets bookmarkData to null when absent', () {
      final json = {
        'path': '/a.md',
        'name': 'a',
        'lastOpened': base.toIso8601String(),
      };
      expect(MarkdownFile.fromJson(json).bookmarkData, isNull);
    });
  });

  group('MarkdownFile.copyWith', () {
    test('overrides content and preserves other fields', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: 'old',
        lastOpened: base,
      );
      final copy = f.copyWith(content: 'new');
      expect(copy.content, 'new');
      expect(copy.path, f.path);
      expect(copy.name, f.name);
      expect(copy.lastOpened, f.lastOpened);
    });

    test('without argument preserves original content', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: 'original',
        lastOpened: base,
      );
      expect(f.copyWith().content, 'original');
    });

    test('preserves bookmarkData through copyWith', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: 'old',
        lastOpened: base,
        bookmarkData: 'bk',
      );
      expect(f.copyWith(content: 'new').bookmarkData, 'bk');
    });
  });

  group('toJson / fromJson round-trip', () {
    test('path, name, and lastOpened survive round-trip', () {
      final f = MarkdownFile(
        path: '/some/path/file.md',
        name: 'file',
        content: 'ignored',
        lastOpened: base,
      );
      final f2 = MarkdownFile.fromJson(f.toJson());
      expect(f2.path, f.path);
      expect(f2.name, f.name);
      expect(f2.lastOpened, f.lastOpened);
    });

    test('bookmarkData survives round-trip', () {
      final f = MarkdownFile(
        path: '/a.md',
        name: 'a',
        content: '',
        lastOpened: base,
        bookmarkData: 'abc123',
      );
      expect(MarkdownFile.fromJson(f.toJson()).bookmarkData, 'abc123');
    });
  });
}
