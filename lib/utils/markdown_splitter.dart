class MarkdownSegment {
  final String content;
  final bool isMermaid;
  const MarkdownSegment(this.content, this.isMermaid);
}

class MarkdownSplitter {
  static final _fence = RegExp(
    r'^(`{3,}|~{3,})[ \t]*mermaid[ \t]*$\n(.*?)^\1[ \t]*$',
    multiLine: true,
    dotAll: true,
  );

  static List<MarkdownSegment> split(String content) {
    final segments = <MarkdownSegment>[];
    int cursor = 0;

    for (final m in _fence.allMatches(content)) {
      if (m.start > cursor) {
        final chunk = content.substring(cursor, m.start).trim();
        if (chunk.isNotEmpty) segments.add(MarkdownSegment(chunk, false));
      }
      segments.add(MarkdownSegment((m.group(2) ?? '').trimRight(), true));
      cursor = m.end;
    }

    if (cursor < content.length) {
      final chunk = content.substring(cursor).trim();
      if (chunk.isNotEmpty) segments.add(MarkdownSegment(chunk, false));
    }

    return segments.isEmpty ? [MarkdownSegment(content, false)] : segments;
  }
}
