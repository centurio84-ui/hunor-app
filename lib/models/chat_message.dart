class ChatMessage {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String author = 'Csapattag';
    if (json['profiles'] != null && json['profiles'] is Map) {
      author = json['profiles']['name']?.toString() ?? 'Csapattag';
    } else if (json['author_name'] != null) {
      author = json['author_name'].toString();
    }

    DateTime dt = DateTime.now();
    if (json['created_at'] != null) {
      try {
        dt = DateTime.parse(json['created_at'].toString()).toLocal();
      } catch (_) {}
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: author,
      content: json['content']?.toString() ?? '',
      createdAt: dt,
    );
  }
}
