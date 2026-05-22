import 'package:flutter_test/flutter_test.dart';
import 'package:md_viewer/utils/markdown_splitter.dart';

void main() {
  group('MarkdownSplitter.split', () {
    test('plain text returns one non-mermaid segment', () {
      final segs = MarkdownSplitter.split('# Hello\n\nSome text.');
      expect(segs.length, 1);
      expect(segs[0].isMermaid, false);
      expect(segs[0].content, contains('Hello'));
    });

    test('empty string returns one non-mermaid segment', () {
      final segs = MarkdownSplitter.split('');
      expect(segs.length, 1);
      expect(segs[0].isMermaid, false);
    });

    test('single mermaid block produces three segments', () {
      const md = '# Title\n\n```mermaid\ngraph LR\n  A --> B\n```\n\nAfter.';
      final segs = MarkdownSplitter.split(md);
      expect(segs.length, 3);
      expect(segs[0].isMermaid, false);
      expect(segs[0].content, contains('Title'));
      expect(segs[1].isMermaid, true);
      expect(segs[1].content, contains('graph LR'));
      expect(segs[2].isMermaid, false);
      expect(segs[2].content, contains('After'));
    });

    test('mermaid content is trimmed of trailing whitespace', () {
      const md = '```mermaid\ngraph LR\n  A --> B\n\n```\n';
      final segs = MarkdownSplitter.split(md);
      final mermaid = segs.firstWhere((s) => s.isMermaid);
      expect(mermaid.content, equals('graph LR\n  A --> B'));
    });

    test('multiple mermaid blocks are each captured', () {
      const md = '```mermaid\ngraph LR\n  A-->B\n```\n\nMiddle.\n\n'
          '```mermaid\nsequenceDiagram\n  Alice->>Bob: Hi\n```\n';
      final segs = MarkdownSplitter.split(md);
      final mermaidSegs = segs.where((s) => s.isMermaid).toList();
      expect(mermaidSegs.length, 2);
      expect(mermaidSegs[0].content, contains('graph LR'));
      expect(mermaidSegs[1].content, contains('sequenceDiagram'));
    });

    test('tilde fence is recognised as mermaid', () {
      const md = '~~~mermaid\ngraph LR\n  A-->B\n~~~\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.any((s) => s.isMermaid), true);
    });

    test('mermaid at document start produces two segments', () {
      const md = '```mermaid\ngraph LR\n  A-->B\n```\n\nAfter.';
      final segs = MarkdownSplitter.split(md);
      expect(segs.length, 2);
      expect(segs[0].isMermaid, true);
      expect(segs[1].isMermaid, false);
    });

    test('mermaid at document end produces two segments', () {
      const md = '# Title\n\n```mermaid\ngraph LR\n  A-->B\n```\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.length, 2);
      expect(segs[0].isMermaid, false);
      expect(segs[1].isMermaid, true);
    });

    test('only mermaid content produces one mermaid segment', () {
      const md = '```mermaid\ngraph LR\n  A-->B\n```\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.length, 1);
      expect(segs[0].isMermaid, true);
    });

    test('regular code block is not treated as mermaid', () {
      const md = '```python\nprint("hello")\n```\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.length, 1);
      expect(segs[0].isMermaid, false);
      expect(segs[0].content, contains('python'));
    });

    test('longer fence markers (4 backticks) are matched', () {
      const md = '````mermaid\ngraph LR\n  A-->B\n````\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.any((s) => s.isMermaid), true);
    });

    test('whitespace after mermaid tag on opening line is allowed', () {
      const md = '```mermaid   \ngraph LR\n  A-->B\n```\n';
      final segs = MarkdownSplitter.split(md);
      expect(segs.any((s) => s.isMermaid), true);
    });
  });
}
