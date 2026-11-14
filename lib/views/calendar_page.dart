import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event_participation.dart';
import '../models/rescue_event.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

/// Magyar Hivatásos Tűzoltó 24/48-as szolgálati csoportok
enum FirefighterShift {
  a('A', 'A csoport', Color(0xFFE53935), Color(0x30E53935)), // Piros
  b('B', 'B csoport', Color(0xFF43A047), Color(0x3043A047)), // Zöld
  c('C', 'C csoport', Color(0xFF1E88E5), Color(0x301E88E5)); // Kék

  final String code;
  final String name;
  final Color color;
  final Color bgTint;

  const FirefighterShift(this.code, this.name, this.color, this.bgTint);

  /// Szolgálati csoport kiszámítása a kanonikus rotáció szerint (2025.01.01 = C csoport)
  static FirefighterShift forDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final anchor = DateTime(2025, 1, 1);
    final diff = d.difference(anchor).inDays;
    final shiftIndex = ((2 + diff) % 3 + 3) % 3;
    return switch (shiftIndex) {
      0 => FirefighterShift.a,
      1 => FirefighterShift.b,
      _ => FirefighterShift.c,
    };
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  static const List<String> _monthNames = [
    'Január', 'Február', 'Március', 'Április', 'Május', 'Június',
    'Július', 'Augusztus', 'Szeptember', 'Október', 'November', 'December'
  ];

  static const List<String> _weekdays = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];

  String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final today = DateTime.now();
    final todayShift = FirefighterShift.forDate(today);

    // Események szűrése a kiválasztott napra
    final selectedDayEvents = store.events.where((e) => _isSameDay(e.date, _selectedDate)).toList();

    return RefreshIndicator(
      onRefresh: store.loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          // 1. Google Naptár Fejléc & Navigáció
          Card(
            margin: EdgeInsets.zero,
            color: HunorColors.navyCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    tooltip: 'Előző hónap',
                  ),
                  Expanded(
                    child: Text(
                      '${_currentMonth.year}. ${_monthNames[_currentMonth.month - 1]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    tooltip: 'Következő hónap',
                  ),
                  TextButton.icon(
                    onPressed: _goToToday,
                    style: TextButton.styleFrom(
                      foregroundColor: HunorColors.gold,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.today, size: 18),
                    label: const Text('Ma', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Tűzoltó Szolgálati Csoport Jelmagyarázat (A-B-C)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HunorColors.navyCard.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HunorColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShiftLegendChip('A', 'A csoport', const Color(0xFFE53935)),
                _buildShiftLegendChip('B', 'B csoport', const Color(0xFF43A047)),
                _buildShiftLegendChip('C', 'C csoport', const Color(0xFF1E88E5)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: todayShift.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: todayShift.color),
                  ),
                  child: Text(
                    'Ma: ${todayShift.code}',
                    style: TextStyle(
                      color: todayShift.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Google Naptár Havi Rács (Month Grid)
          Card(
            margin: EdgeInsets.zero,
            color: HunorColors.navyCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  // Hét napjai fejléc (H, K, Sze, Cs, P, Szo, V)
                  Row(
                    children: [
                      for (final day in _weekdays)
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (day == 'Szo' || day == 'V') ? HunorColors.gold : HunorColors.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: HunorColors.line, height: 1),
                  const SizedBox(height: 6),

                  // Napok négyzetei
                  _buildMonthCalendarGrid(store.events),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Kiválasztott Nap Részletei (Selected Day Card)
          _buildSelectedDayHeader(),
          const SizedBox(height: 8),

          // Kiválasztott napi események (ha vannak)
          if (selectedDayEvents.isNotEmpty) ...[
            for (final e in selectedDayEvents) _buildEventCard(context, store, e),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HunorColors.navyCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HunorColors.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_note, color: FirefighterShift.forDate(_selectedDate).color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ezen a napon nincs tervezett HUNOR esemény.\nSzolgálatban: ${FirefighterShift.forDate(_selectedDate).name}',
                      style: const TextStyle(color: HunorColors.muted, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 5. Szervezet összes eseménye és gyakorlata (Mindig látható az azonnali áttekintéshez)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: HunorColors.gold, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'SZERVEZETI ESEMÉNYEK ÉS GYAKORLATOK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: HunorColors.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  '${store.events.length} esemény',
                  style: const TextStyle(color: HunorColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          if (store.events.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HunorColors.navyCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Nincs rögzített esemény ebben a szervezetben.',
                  style: TextStyle(fontWeight: FontWeight.w700, color: HunorColors.muted),
                ),
              ),
            )
          else
            for (final e in store.events)
              if (!selectedDayEvents.contains(e))
                _buildEventCard(context, store, e),
        ],
      ),
    );
  }

  Widget _buildShiftLegendChip(String code, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Text(
              code,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildMonthCalendarGrid(List<RescueEvent> events) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    
    // Hétfő = 1, Vasárnap = 7
    final firstWeekday = firstDayOfMonth.weekday; // 1..7
    final prevMonthPadding = firstWeekday - 1; // Hány üres mező kell az elejére

    final totalCells = ((prevMonthPadding + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        if (index < prevMonthPadding || index >= prevMonthPadding + daysInMonth) {
          return const SizedBox.shrink();
        }

        final dayNumber = index - prevMonthPadding + 1;
        final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final shift = FirefighterShift.forDate(cellDate);
        final isToday = _isSameDay(cellDate, today);
        final isSelected = _isSameDay(cellDate, _selectedDate);
        final hasEvents = events.any((e) => _isSameDay(e.date, cellDate));

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? HunorColors.navyLight
                  : isToday
                      ? HunorColors.gold.withOpacity(0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? HunorColors.gold
                    : isToday
                        ? HunorColors.gold.withOpacity(0.5)
                        : Colors.transparent,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Napszám
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday || isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isToday
                        ? HunorColors.gold
                        : isSelected
                            ? Colors.white
                            : Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),

                // Tűzoltó Szolgálati Csoport Badge (A: Piros, B: Zöld, C: Kék)
                Container(
                  width: 22,
                  height: 16,
                  decoration: BoxDecoration(
                    color: shift.color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: shift.color.withOpacity(0.4),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      shift.code,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Eseményjelző pont
                if (hasEvents)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: HunorColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDayHeader() {
    final shift = FirefighterShift.forDate(_selectedDate);
    final weekdayName = switch (_selectedDate.weekday) {
      1 => 'Hétfő',
      2 => 'Kedd',
      3 => 'Szerda',
      4 => 'Csütörtök',
      5 => 'Péntek',
      6 => 'Szombat',
      _ => 'Vasárnap',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HunorColors.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: shift.color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: shift.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${shift.code} csoport',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedDate.year}. ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.day}., $weekdayName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '24/48 órás szolgálati nap: ${shift.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: shift.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, AppStore s, RescueEvent e) {
    final r = s.eventResponses[e.id];
    final reg = s.eventRegistrations[e.id];
    final part = s.eventParticipations[e.id];
    final past = e.date.isBefore(DateTime.now());
    final shift = FirefighterShift.forDate(e.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: HunorColors.navyCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HunorColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEventDetailsSheet(context, s, e, reg, part, past),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 64,
                decoration: BoxDecoration(
                  color: past ? HunorColors.surface2 : shift.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: shift.color.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${e.date.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: past ? HunorColors.muted : Colors.white,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: shift.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        shift.code,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_date(e.date), style: const TextStyle(color: HunorColors.muted, fontSize: 12)),
                    if (e.location.isNotEmpty)
                      Text(e.location, style: const TextStyle(color: HunorColors.muted, fontSize: 12)),
                    if (reg != null && reg.hasCapacityLimit) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Szabad helyek: ${reg.remainingSeats} / ${reg.maxCapacity}',
                        style: TextStyle(
                          fontSize: 11,
                          color: reg.isFull ? HunorColors.warning : HunorColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (r != null)
                Icon(
                  r == 'going' ? Icons.check_circle : Icons.cancel,
                  color: r == 'going' ? HunorColors.success : HunorColors.muted,
                )
              else
                const Icon(Icons.chevron_right, color: HunorColors.gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsSheet(
    BuildContext context,
    AppStore s,
    RescueEvent e,
    EventRegistrationInfo? reg,
    EventParticipation? part,
    bool past,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: HunorColors.navyCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: FirefighterShift.forDate(e.date).color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${FirefighterShift.forDate(e.date).code} csoportos nap',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(_date(e.date), style: const TextStyle(color: HunorColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Text(e.title, style: Theme.of(c).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              if (e.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: HunorColors.muted),
                    const SizedBox(width: 6),
                    Text(e.location, style: const TextStyle(color: HunorColors.muted)),
                  ],
                ),
              ],
              if (e.details.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(e.details, style: const TextStyle(height: 1.4, color: Colors.white70)),
              ],
              const SizedBox(height: 16),

              if (reg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HunorColors.navyLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HunorColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 18, color: HunorColors.gold),
                          const SizedBox(width: 8),
                          Text(
                            reg.hasCapacityLimit
                                ? (reg.maxCapacity == 0
                                    ? 'Kapacitás: 0 fő (Nincs férőhely)'
                                    : 'Létszámkeret: ${reg.remainingSeats ?? 0} szabad / ${reg.maxCapacity} fő')
                                : 'Korlátlan létszámkeret',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: reg.isFull ? HunorColors.warning : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (!reg.isPublished) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Státusz: ${reg.publicationState == "cancelled" ? "Törölve" : reg.publicationState == "archived" ? "Archiválva" : reg.publicationState}',
                          style: const TextStyle(fontSize: 12, color: HunorColors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                      if (reg.registrationDeadline != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Jelentkezési határidő: ${_date(reg.registrationDeadline!)} (${reg.isRegistrationOpen ? "Nyitva" : "Lezárult"})',
                          style: TextStyle(
                            fontSize: 12,
                            color: reg.isRegistrationOpen ? HunorColors.muted : HunorColors.warning,
                          ),
                        ),
                      ],
                      if (reg.cancellationDeadline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Lemondási határidő: ${_date(reg.cancellationDeadline!)} (${reg.isCancellationOpen ? "Nyitva" : "Lezárult"})',
                          style: TextStyle(
                            fontSize: 12,
                            color: reg.isCancellationOpen ? HunorColors.muted : HunorColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!past && (reg == null || reg.isPublished)) ...[
                () {
                  final canParticipate = s.capabilities == null || s.capabilities!.allows('events.participate_self');
                  final isRegistered = part?.isGoing == true;
                  final canRegister = canParticipate && (reg == null || (reg.isRegistrationOpen && (!reg.isFull || isRegistered)));
                  final canCancel = canParticipate && (reg == null || reg.isCancellationOpen);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: HunorColors.gold,
                          foregroundColor: HunorColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: canRegister
                            ? () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(c);
                                try {
                                  await s.respondToEvent(e.id, true);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Sikeres eseményjelentkezés!'),
                                      backgroundColor: HunorColors.success,
                                    ),
                                  );
                                } catch (err) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Hiba a jelentkezéskor: $err'),
                                      backgroundColor: HunorColors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: Icon(isRegistered ? Icons.check_circle : Icons.check_circle_outline),
                        label: Text(
                          isRegistered
                              ? 'Részt veszek ✓'
                              : (reg != null && reg.isFull && !isRegistered)
                                  ? 'Betelt létszámkeret'
                                  : (reg != null && !reg.isRegistrationOpen)
                                      ? 'Jelentkezés lezárult'
                                      : 'Részt veszek',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: HunorColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: canCancel
                            ? () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(c);
                                try {
                                  await s.respondToEvent(e.id, false);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Eseményrészvétel sikeresen lemondva!'),
                                      backgroundColor: HunorColors.muted,
                                    ),
                                  );
                                } catch (err) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Hiba a lemondáskor: $err'),
                                      backgroundColor: HunorColors.red,
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: Icon(part?.isNotGoing == true ? Icons.cancel : Icons.cancel_outlined),
                        label: Text(
                          part?.isNotGoing == true
                              ? 'Nem veszek részt ✓'
                              : (reg != null && !reg.isCancellationOpen)
                                  ? 'Lemondási határidő lejárt'
                                  : 'Nem veszek részt',
                        ),
                      ),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
