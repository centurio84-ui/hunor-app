import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

Future<void> showAvailabilityDialog(BuildContext context) async {
  final store = context.read<AppStore>();
  final current = store.currentUser;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: HunorColors.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AvailabilitySheetContent(store: store, initialMember: current),
  );
}

class _AvailabilitySheetContent extends StatefulWidget {
  final AppStore store;
  final Member? initialMember;

  const _AvailabilitySheetContent({
    required this.store,
    required this.initialMember,
  });

  @override
  State<_AvailabilitySheetContent> createState() => _AvailabilitySheetContentState();
}

class _AvailabilitySheetContentState extends State<_AvailabilitySheetContent> {
  late AvailabilityStatus _status;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _isIndefinite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialMember?.status ?? AvailabilityStatus.available;
    _startDate = widget.initialMember?.statusStartDate ?? DateTime.now();
    _endDate = widget.initialMember?.statusEndDate;
    _isIndefinite = _endDate == null;
    if (_endDate == null) {
      _endDate = _startDate.add(const Duration(days: 7));
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}.';

  Color _statusColor(AvailabilityStatus s) => switch (s) {
        AvailabilityStatus.available => HunorColors.success,
        AvailabilityStatus.sick => HunorColors.red,
        AvailabilityStatus.vacation => HunorColors.blue,
        AvailabilityStatus.training => HunorColors.exercise,
        AvailabilityStatus.unavailable => HunorColors.muted,
      };

  IconData _statusIcon(AvailabilityStatus s) => switch (s) {
        AvailabilityStatus.available => Icons.check_circle_rounded,
        AvailabilityStatus.sick => Icons.medical_services_rounded,
        AvailabilityStatus.vacation => Icons.beach_access_rounded,
        AvailabilityStatus.training => Icons.school_rounded,
        AvailabilityStatus.unavailable => Icons.do_not_disturb_on_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HunorColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: HunorColors.gold, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Szolgálati Állapot',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          'Központi bevethetőségi nyilvántartás',
                          style: TextStyle(fontSize: 12, color: HunorColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                'VÁLASSZ ÁLLAPOTOT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 8),

              ...AvailabilityStatus.values.map((s) {
                final selected = _status == s;
                final color = _statusColor(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.18) : HunorColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_statusIcon(s), color: color, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                color: selected ? Colors.white : HunorColors.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle, color: color, size: 20)
                          else
                            const Icon(Icons.radio_button_unchecked, color: HunorColors.muted, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),
              const Text(
                'IDŐTARTAM ÉS ÉRVÉNYESSÉG',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 8),

              // Kezdőnap
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      if (_endDate != null && _endDate!.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: HunorColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HunorColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: HunorColors.gold),
                      const SizedBox(width: 12),
                      const Text('Kezdőnap:', style: TextStyle(color: HunorColors.muted, fontSize: 13)),
                      const Spacer(),
                      Text(
                        _formatDate(_startDate),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, color: HunorColors.muted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Határozatlan idejű kapcsoló
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Határozatlan ideig', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Nincs előre meghatározott zárónap', style: TextStyle(color: HunorColors.muted, fontSize: 12)),
                value: _isIndefinite,
                activeColor: HunorColors.gold,
                onChanged: (val) => setState(() => _isIndefinite = val),
              ),

              if (!_isIndefinite) ...[
                const SizedBox(height: 4),
                // Zárónap
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: (_endDate != null && _endDate!.isAfter(_startDate)) ? _endDate! : _startDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: HunorColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HunorColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded, size: 18, color: HunorColors.red),
                        const SizedBox(width: 12),
                        const Text('Zárónap:', style: TextStyle(color: HunorColors.muted, fontSize: 13)),
                        const Spacer(),
                        Text(
                          _endDate != null ? _formatDate(_endDate!) : '-',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_drop_down, color: HunorColors.muted),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: _saving ? null : _saveAndSync,
                style: FilledButton.styleFrom(
                  backgroundColor: HunorColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.cloud_sync_rounded, color: Colors.black),
                label: Text(
                  _saving ? 'Szinkronizálás...' : 'Mentés és szinkronizálás',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HunorColors.muted,
                  side: const BorderSide(color: HunorColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mégse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndSync() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await widget.store.setAvailability(
        _status,
        startDate: _startDate,
        endDate: _isIndefinite ? null : _endDate,
      );
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Szolgálati állapot elmentve: ${_status.shortLabel} (${widget.store.currentUser?.statusPeriodFormatted ?? ""})',
                  ),
                ),
              ],
            ),
            backgroundColor: HunorColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Hiba a mentés során: $e'),
            backgroundColor: HunorColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
