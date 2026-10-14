/// Műveleti és gyakorlati eseménymodell a Rescue Platformhoz.

class RescueEvent {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final String location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int version;

  const RescueEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    this.endsAt,
    this.version = 1,
  });

  factory RescueEvent.fromJson(Map<String, dynamic> json) {
    return RescueEvent(
      id: json['id']?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endsAt: json['ends_at'] != null ? DateTime.tryParse(json['ends_at'].toString()) : null,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'title': title,
    'description': description,
    'location': location,
    'starts_at': startsAt.toIso8601String(),
    if (endsAt != null) 'ends_at': endsAt!.toIso8601String(),
    'version': version,
  };
}
