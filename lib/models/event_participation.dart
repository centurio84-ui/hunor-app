/// CODEX-017 szerinti eseményjelentkezési és regisztrációs adatmodellek.

enum EventParticipationStatus {
  going,
  notGoing,
}

extension EventParticipationStatusX on EventParticipationStatus {
  String get value => this == EventParticipationStatus.going ? 'going' : 'not_going';
  String get label => this == EventParticipationStatus.going ? 'Részt veszek' : 'Nem veszek részt';

  static EventParticipationStatus? fromString(String? v) {
    if (v == 'going') return EventParticipationStatus.going;
    if (v == 'not_going') return EventParticipationStatus.notGoing;
    return null;
  }
}

/// Esemény regisztrációs szabályok és kapacitás információk (GET /registration).
class EventRegistrationInfo {
  final String eventId;
  final String organizationId;
  final DateTime? opensAt;
  final DateTime? registrationDeadline;
  final DateTime? cancellationDeadline;
  final int? maxCapacity;
  final int currentGoingCount;
  final int rulesVersion;
  final bool isEligible;
  final String? eligibilityReason;

  const EventRegistrationInfo({
    required this.eventId,
    required this.organizationId,
    this.opensAt,
    this.registrationDeadline,
    this.cancellationDeadline,
    this.maxCapacity,
    this.currentGoingCount = 0,
    this.rulesVersion = 1,
    this.isEligible = true,
    this.eligibilityReason,
  });

  bool get hasCapacityLimit => maxCapacity != null && maxCapacity! > 0;
  int? get remainingSeats => hasCapacityLimit ? (maxCapacity! - currentGoingCount).clamp(0, maxCapacity!) : null;
  bool get isFull => hasCapacityLimit && (remainingSeats ?? 0) <= 0;

  bool get isRegistrationOpen {
    final now = DateTime.now();
    if (opensAt != null && now.isBefore(opensAt!)) return false;
    if (registrationDeadline != null && now.isAfter(registrationDeadline!)) return false;
    return true;
  }

  bool get isCancellationOpen {
    final now = DateTime.now();
    final deadline = cancellationDeadline ?? registrationDeadline;
    if (deadline != null && now.isAfter(deadline)) return false;
    return true;
  }

  factory EventRegistrationInfo.fromJson(Map<String, dynamic> json) {
    return EventRegistrationInfo(
      eventId: json['event_id']?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      opensAt: json['opens_at'] != null ? DateTime.tryParse(json['opens_at'].toString()) : null,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.tryParse(json['registration_deadline'].toString())
          : null,
      cancellationDeadline: json['cancellation_deadline'] != null
          ? DateTime.tryParse(json['cancellation_deadline'].toString())
          : null,
      maxCapacity: (json['max_capacity'] as num?)?.toInt(),
      currentGoingCount: (json['current_going_count'] as num?)?.toInt() ?? 0,
      rulesVersion: (json['rules_version'] as num?)?.toInt() ?? 1,
      isEligible: json['is_eligible'] != false,
      eligibilityReason: json['eligibility_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'organization_id': organizationId,
    if (opensAt != null) 'opens_at': opensAt!.toIso8601String(),
    if (registrationDeadline != null) 'registration_deadline': registrationDeadline!.toIso8601String(),
    if (cancellationDeadline != null) 'cancellation_deadline': cancellationDeadline!.toIso8601String(),
    if (maxCapacity != null) 'max_capacity': maxCapacity,
    'current_going_count': currentGoingCount,
    'rules_version': rulesVersion,
    'is_eligible': isEligible,
    if (eligibilityReason != null) 'eligibility_reason': eligibilityReason,
  };
}

/// Saját részvétel DTO (GET/PUT /participation/me).
class EventParticipation {
  final String organizationId;
  final String eventId;
  final String membershipId;
  final EventParticipationStatus? response;
  final DateTime? respondedAt;
  final int version;

  const EventParticipation({
    required this.organizationId,
    required this.eventId,
    required this.membershipId,
    this.response,
    this.respondedAt,
    this.version = 0,
  });

  bool get isGoing => response == EventParticipationStatus.going;
  bool get isNotGoing => response == EventParticipationStatus.notGoing;
  bool get hasResponded => response != null;

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      organizationId: json['organization_id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      membershipId: json['membership_id']?.toString() ?? '',
      response: EventParticipationStatusX.fromString(json['response']?.toString()),
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'organization_id': organizationId,
    'event_id': eventId,
    'membership_id': membershipId,
    if (response != null) 'response': response!.value,
    if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
    'version': version,
  };
}
