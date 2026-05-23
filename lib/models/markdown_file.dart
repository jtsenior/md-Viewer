class MarkdownFile {
  final String path;
  final String name;
  final String content;
  final DateTime lastOpened;
  final String? bookmarkData;

  const MarkdownFile({
    required this.path,
    required this.name,
    required this.content,
    required this.lastOpened,
    this.bookmarkData,
  });

  MarkdownFile copyWith({String? content}) {
    return MarkdownFile(
      path: path,
      name: name,
      content: content ?? this.content,
      lastOpened: lastOpened,
      bookmarkData: bookmarkData,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened.toIso8601String(),
        if (bookmarkData != null) 'bookmark': bookmarkData,
      };

  static MarkdownFile fromJson(Map<String, dynamic> json) => MarkdownFile(
        path: json['path'],
        name: json['name'],
        content: '',
        lastOpened: DateTime.parse(json['lastOpened']),
        bookmarkData: json['bookmark'] as String?,
      );
}
