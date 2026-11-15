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

class RescueNewsMedia {
  final String path;
  final String name;
  final String caption;
  final String kind;
  final String url;

  const RescueNewsMedia({
    required this.path,
    required this.name,
    this.caption = '',
    this.kind = 'image',
    this.url = '',
  });

  factory RescueNewsMedia.fromJson(Map<String, dynamic> json, {String url = ''}) {
    return RescueNewsMedia(
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      kind: json['kind']?.toString() ?? (json['mime']?.toString().startsWith('video') == true ? 'video' : 'image'),
      url: url.isNotEmpty ? url : (json['url']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'caption': caption,
    'kind': kind,
    'url': url,
  };
}

class RescueNewsLink {
  final String label;
  final String url;

  const RescueNewsLink({
    required this.label,
    required this.url,
  });

  factory RescueNewsLink.fromJson(Map<String, dynamic> json) {
    return RescueNewsLink(
      label: json['label']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'url': url,
  };
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
  final List<RescueNewsMedia> media;
  final List<String> imageUrls;
  final List<RescueNewsLink> links;
  final String? category;
  final String? mapQuery;

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
    this.media = const [],
    this.imageUrls = const [],
    this.links = const [],
    this.category,
    this.mapQuery,
  });

  factory RescueNewsItem.fromJson(Map<String, dynamic> json) {
    String contentVal = '';
    final rawBody = json['content'] ?? json['body'];
    if (rawBody is List) {
      contentVal = rawBody
          .map((b) => b is Map ? (b['text'] ?? b['content'] ?? '') : b.toString())
          .where((s) => s.toString().trim().isNotEmpty)
          .join('\n\n');
    } else if (rawBody != null) {
      contentVal = rawBody.toString().trim();
    }

    final rawSummary = (json['summary'] ?? json['lead'] ?? '').toString().trim();
    final String summaryVal = rawSummary.isNotEmpty
        ? rawSummary
        : (contentVal.length > 180 ? '${contentVal.substring(0, 180)}...' : contentVal);

    if (contentVal.isEmpty && summaryVal.isNotEmpty) {
      contentVal = summaryVal;
    }

    final mediaList = <RescueNewsMedia>[];
    final images = <String>[];
    if (json['media'] is List) {
      for (final m in (json['media'] as List)) {
        if (m is Map) {
          final mediaItem = RescueNewsMedia.fromJson(Map<String, dynamic>.from(m));
          mediaList.add(mediaItem);
          if (mediaItem.url.isNotEmpty && mediaItem.kind != 'video') {
            images.add(mediaItem.url);
          }
        }
      }
    }
    if (json['imageUrls'] is List) {
      for (final img in (json['imageUrls'] as List)) {
        final s = img.toString().trim();
        if (s.isNotEmpty && !images.contains(s)) {
          images.add(s);
        }
      }
    }

    final linkList = <RescueNewsLink>[];
    if (json['links'] is List) {
      for (final l in (json['links'] as List)) {
        if (l is Map) {
          linkList.add(RescueNewsLink.fromJson(Map<String, dynamic>.from(l)));
        }
      }
    }

    return RescueNewsItem(
      id: (json['id'] ?? json['content_id'])?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: summaryVal,
      content: contentVal,
      authorName: (json['author_name'] ?? json['author_display_name'])?.toString(),
      publishedAt: DateTime.tryParse((json['published_at'] ?? json['created_at'])?.toString() ?? '') ?? DateTime.now(),
      audience: NewsAudienceX.fromString(json['audience']?.toString()),
      isPinned: json['is_pinned'] == true || json['pinned'] == true,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      externalUrl: json['external_url']?.toString(),
      media: mediaList,
      imageUrls: images,
      links: linkList,
      category: json['category']?.toString(),
      mapQuery: json['map_query']?.toString(),
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
    'media': media.map((m) => m.toJson()).toList(),
    'imageUrls': imageUrls,
    'links': links.map((l) => l.toJson()).toList(),
    if (category != null) 'category': category,
    if (mapQuery != null) 'map_query': mapQuery,
  };
}
