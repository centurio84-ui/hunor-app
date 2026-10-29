/// CODEX-018 szerinti hírek és szervezeti közlemények adatmodellje.

enum NewsAudience {
  all,
  members,
  leaders,
}

extension NewsAudienceX on NewsAudience {
  String get value {
    switch (this) {
      case NewsAudience.all:
        return 'all';
      case NewsAudience.members:
        return 'members';
      case NewsAudience.leaders:
        return 'leaders';
    }
  }

  static NewsAudience fromString(String? v) {
    if (v == 'members') return NewsAudience.members;
    if (v == 'leaders') return NewsAudience.leaders;
    return NewsAudience.all;
  }
}

class RescueNewsItem {
  final String id;
  final String organizationId;
  final String title;
  final String summary;
  final String content;
  final String? authorName;
  final DateTime publishedAt;
  final NewsAudience audience;
  final bool isPinned;
  final List<String> tags;
  final String? externalUrl;

  const RescueNewsItem({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.summary,
    required this.content,
    this.authorName,
    required this.publishedAt,
    this.audience = NewsAudience.members,
    this.isPinned = false,
    this.tags = const [],
    this.externalUrl,
  });

  factory RescueNewsItem.fromJson(Map<String, dynamic> json) {
    return RescueNewsItem(
      id: json['id']?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      authorName: json['author_name']?.toString(),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? '') ?? DateTime.now(),
      audience: NewsAudienceX.fromString(json['audience']?.toString()),
      isPinned: json['is_pinned'] == true,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      externalUrl: json['external_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'title': title,
    'summary': summary,
    'content': content,
    if (authorName != null) 'author_name': authorName,
    'published_at': publishedAt.toIso8601String(),
    'audience': audience.value,
    'is_pinned': isPinned,
    'tags': tags,
    if (externalUrl != null) 'external_url': externalUrl,
  };
}
