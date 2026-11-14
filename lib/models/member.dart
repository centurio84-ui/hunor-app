enum AvailabilityStatus {
  available, vacation, sick, training, unavailable;

  String get label => switch (this) {
    AvailabilityStatus.available => 'Elérhető',
    AvailabilityStatus.vacation => 'Szabadságon',
    AvailabilityStatus.sick => 'Beteg',
    AvailabilityStatus.training => 'Képzésen',
    AvailabilityStatus.unavailable => 'Egyéb',
  };

  static AvailabilityStatus fromDatabase(String? value) => switch (value) {
    'vacation' => AvailabilityStatus.vacation,
    'sick' => AvailabilityStatus.sick,
    'training' => AvailabilityStatus.training,
    'unavailable' => AvailabilityStatus.unavailable,
    _ => AvailabilityStatus.available,
  };
}

class Member {
  final String id, name, rank, workplace, position, phone;
  final List<String> skills;
  final AvailabilityStatus status;
  final DateTime? lastActive;

  const Member({
    required this.id, required this.name, required this.rank,
    required this.workplace, required this.position, required this.phone,
    required this.skills, required this.status,
    this.lastActive,
  });

  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inMinutes < 15;
  }

  String get lastActiveFormatted {
    if (lastActive == null) return 'Még nem lépett be';
    final diff = DateTime.now().difference(lastActive!);
    if (diff.inMinutes < 15) return 'Aktív most az appban';
    if (diff.inHours < 1) return '${diff.inMinutes} perce volt aktív';
    if (diff.inHours < 24) return 'Ma aktív volt (${lastActive!.hour.toString().padLeft(2, '0')}:${lastActive!.minute.toString().padLeft(2, '0')})';
    if (diff.inDays == 1) return 'Tegnap volt aktív';
    return '${diff.inDays} napja volt aktív';
  }
}
