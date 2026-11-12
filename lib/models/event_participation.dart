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
  final String publicationState;
  final DateTime? opensAt;
  final DateTime? registrationDeadline;
  final DateTime? cancellationDeadline;
  final int? maxCapacity;
  final int? availablePlaces;
  final int currentGoingCount;
  final bool? serverRegistrationOpen;
  final bool? serverCancellationOpen;
  final int rulesVersion;
  final bool isEligible;
  final String? eligibilityReason;

  const EventRegistrationInfo({
    required this.eventId,
    required this.organizationId,
    this.publicationState = 'published',
    this.opensAt,
    this.registrationDeadline,
    this.cancellationDeadline,
    this.maxCapacity,
    this.availablePlaces,
    this.currentGoingCount = 0,
    this.serverRegistrationOpen,
    this.serverCancellationOpen,
    this.rulesVersion = 1,
    this.isEligible = true,
    this.eligibilityReason,
  });

  /// Szerződés szerinti kapacitás: ha null, akkor korlátlan.
  /// Ha egész szám (akár 0!), akkor kapacitáskorlátos.
  bool get hasCapacityLimit => maxCapacity != null;

  /// Szabad helyek száma. Ha a szerver rendelkezésre bocsátja az availablePlaces mezőt, azt használjuk.
  int? get remainingSeats {
    if (availablePlaces != null) return availablePlaces;
    if (maxCapacity != null) return (maxCapacity! - currentGoingCount).clamp(0, maxCapacity!);
    return null;
  }

  /// Betelt-e a keret
  bool get isFull => hasCapacityLimit && (remainingSeats ?? 0) <= 0;

  /// Esemény érvényes/nyitott státusza
  bool get isPublished => publicationState == 'published';

  /// Regisztráció nyitottsága: a szerveres serverRegistrationOpen flag az elsődleges igazságforrás
  bool get isRegistrationOpen {
    if (!isPublished) return false;
    if (serverRegistrationOpen != null) return serverRegistrationOpen!;
    final now = DateTime.now();
    if (opensAt != null && now.isBefore(opensAt!)) return false;
    if (registrationDeadline != null && now.isAfter(registrationDeadline!)) return false;
    return true;
  }

  /// Lemondás nyitottsága: a szerveres serverCancellationOpen flag az elsődleges igazságforrás
  bool get isCancellationOpen {
    if (!isPublished) return false;
    if (serverCancellationOpen != null) return serverCancellationOpen!;
    final now = DateTime.now();
    final deadline = cancellationDeadline ?? registrationDeadline;
    if (deadline != null && now.isAfter(deadline)) return false;
    return true;
  }

  factory EventRegistrationInfo.fromJson(Map<String, dynamic> json) {
    final opensAtRaw = json['opens_at'] ?? json['registration_opens_at'];
    final regClosesRaw = json['registration_deadline'] ?? json['registration_closes_at'];
    final cancelClosesRaw = json['cancellation_deadline'] ?? json['cancellation_closes_at'];
    final cap = json['capacity'] ?? json['max_capacity'];
    final avail = json['available_places'];
    
    // Számított vagy szerveres létszám
    int calculatedGoing = 0;
    if (json['current_going_count'] != null) {
      calculatedGoing = (json['current_going_count'] as num).toInt();
    } else if (cap != null && avail != null) {
      final capInt = (cap as num).toInt();
      final availInt = (avail as num).toInt();
      calculatedGoing = (capInt - availInt).clamp(0, capInt);
    }

    return EventRegistrationInfo(
      eventId: (json['event_id'] ?? json['id'])?.toString() ?? '',
      organizationId: json['organization_id']?.toString() ?? '',
      publicationState: json['publication_state']?.toString() ?? 'published',
      opensAt: opensAtRaw != null ? DateTime.tryParse(opensAtRaw.toString()) : null,
      registrationDeadline: regClosesRaw != null
          ? DateTime.tryParse(regClosesRaw.toString())
          : null,
      cancellationDeadline: cancelClosesRaw != null
          ? DateTime.tryParse(cancelClosesRaw.toString())
          : null,
      maxCapacity: cap != null ? (cap as num).toInt() : null,
      availablePlaces: avail != null ? (avail as num).toInt() : null,
      currentGoingCount: calculatedGoing,
      serverRegistrationOpen: json['registration_open'] as bool?,
      serverCancellationOpen: json['cancellation_open'] as bool?,
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
