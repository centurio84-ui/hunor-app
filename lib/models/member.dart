enum AvailabilityStatus {
  available, vacation, sick, training, unavailable;

  String get label => switch (this) {
    AvailabilityStatus.available => 'Elérhető / Bevethető',
    AvailabilityStatus.vacation => 'Szabadságon',
    AvailabilityStatus.sick => 'Betegállomány',
    AvailabilityStatus.training => 'Képzésen / Gyakorlaton',
    AvailabilityStatus.unavailable => 'Egyéb / Nem elérhető',
  };

  String get shortLabel => switch (this) {
    AvailabilityStatus.available => 'Elérhető',
    AvailabilityStatus.vacation => 'Szabadság',
    AvailabilityStatus.sick => 'Beteg',
    AvailabilityStatus.training => 'Képzés',
    AvailabilityStatus.unavailable => 'Egyéb',
  };

  static AvailabilityStatus fromDatabase(String? value) => switch (value) {
    'vacation' => AvailabilityStatus.vacation,
    'sick' => AvailabilityStatus.sick,
    'training' => AvailabilityStatus.training,
    'unavailable' => AvailabilityStatus.unavailable,
    _ => AvailabilityStatus.available,
  };

  String toDatabase() => switch (this) {
    AvailabilityStatus.available => 'available',
    AvailabilityStatus.vacation => 'vacation',
    AvailabilityStatus.sick => 'sick',
    AvailabilityStatus.training => 'training',
    AvailabilityStatus.unavailable => 'unavailable',
  };
}

class Member {
  final String id, name, rank, workplace, position, phone;
  final List<String> skills;
  final AvailabilityStatus status;
  final DateTime? statusStartDate;
  final DateTime? statusEndDate;
  final DateTime? lastActive;

  const Member({
    required this.id, required this.name, required this.rank,
    required this.workplace, required this.position, required this.phone,
    required this.skills, required this.status,
    this.statusStartDate,
    this.statusEndDate,
    this.lastActive,
  });

  String get statusPeriodFormatted {
    if (statusStartDate == null) return 'Folyamatosan';
    final startStr = '${statusStartDate!.year}.${statusStartDate!.month.toString().padLeft(2, '0')}.${statusStartDate!.day.toString().padLeft(2, '0')}.';
    if (statusEndDate == null) return '$startStr óta';
    final endStr = '${statusEndDate!.year}.${statusEndDate!.month.toString().padLeft(2, '0')}.${statusEndDate!.day.toString().padLeft(2, '0')}.';
    return '$startStr – $endStr';
  }

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
