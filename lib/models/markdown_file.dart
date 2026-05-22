class MarkdownFile {
  final String path;
  final String name;
  final String content;
  final DateTime lastOpened;

  const MarkdownFile({
    required this.path,
    required this.name,
    required this.content,
    required this.lastOpened,
  });

  MarkdownFile copyWith({String? content}) {
    return MarkdownFile(
      path: path,
      name: name,
      content: content ?? this.content,
      lastOpened: lastOpened,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened.toIso8601String(),
      };

  static MarkdownFile fromJson(Map<String, dynamic> json) => MarkdownFile(
        path: json['path'],
        name: json['name'],
        content: '',
        lastOpened: DateTime.parse(json['lastOpened']),
      );
}
