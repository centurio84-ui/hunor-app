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

  const Member({
    required this.id, required this.name, required this.rank,
    required this.workplace, required this.position, required this.phone,
    required this.skills, required this.status,
  });
}
