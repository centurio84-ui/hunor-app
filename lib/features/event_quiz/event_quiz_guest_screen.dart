import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/hunor_theme.dart';
import 'device_hash_helper.dart';
import 'event_quiz_models.dart';
import 'event_quiz_repository.dart';

enum _GuestStage {
  loading,
  notFound,
  inactive,
  intro,
  playing,
  result,
  error,
}

class EventQuizGuestScreen extends StatefulWidget {
  const EventQuizGuestScreen({
    super.key,
    required this.eventSlug,
    this.repository,
  });

  final String eventSlug;
  final EventQuizRepository? repository;

  @override
  State<EventQuizGuestScreen> createState() => _EventQuizGuestScreenState();
}

class _EventQuizGuestScreenState extends State<EventQuizGuestScreen> {
  late final EventQuizRepository _repo =
      widget.repository ?? EventQuizRepository(Supabase.instance.client);

  _GuestStage _stage = _GuestStage.loading;
  String? _errorMessage;
  String _deviceHash = '';

  QuizEvent? _event;
  QuizEventSubmission? _submission;

  List<QuizQuestionItem> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedChoice;
  bool _answered = false;
  bool _busy = false;
  bool _savedResultBanner = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _stage = _GuestStage.loading;
      _errorMessage = null;
    });

    final slug = widget.eventSlug.trim().toLowerCase();
    if (slug.isEmpty) {
      setState(() => _stage = _GuestStage.notFound);
      return;
    }

    try {
      final hash = await getDeterministicDeviceHash();
      _deviceHash = hash;

      final state = await _repo.fetchPublicEventState(
        slug: slug,
        deviceHash: hash,
      );

      if (!mounted) return;
      final ev = state.event;
      final sub = state.submission;

      if (ev == null) {
        setState(() => _stage = _GuestStage.notFound);
        return;
      }

      _event = ev;
      _submission = sub;

      // If this device has already completed this event quiz, show saved result & reward_code immediately!
      if (sub != null && sub.isCompleted) {
        setState(() {
          _score = sub.score ?? 0;
          _savedResultBanner = true;
          _stage = _GuestStage.result;
        });
        return;
      }

      if (!ev.isActive) {
        setState(() => _stage = _GuestStage.inactive);
        return;
      }

      setState(() => _stage = _GuestStage.intro);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _stage = _GuestStage.error;
      });
    }
  }

  Future<void> _onStartQuiz() async {
    final ev = _event;
    if (ev == null || _busy) return;
    setState(() => _busy = true);

    try {
      // Insert row with started_at to track drop-off rates (started_at vs completed_at)
      final sub = await _repo.startQuiz(
        eventId: ev.id,
        deviceHash: _deviceHash,
      );

      // Double-check if completed in another tab
      if (sub.isCompleted) {
        if (!mounted) return;
        setState(() {
          _submission = sub;
          _score = sub.score ?? 0;
          _savedResultBanner = true;
          _stage = _GuestStage.result;
          _busy = false;
        });
        return;
      }

      final loadedQuestions =
          await _repo.loadRandomizedQuestions(ev.questionCount);

      if (!mounted) return;
      setState(() {
        _submission = sub;
        _questions = loadedQuestions;
        _currentIndex = 0;
        _score = 0;
        _selectedChoice = null;
        _answered = false;
        _busy = false;
        _stage = _GuestStage.playing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nem sikerült elindítani a kvízt: $e')),
      );
    }
  }

  void _selectAnswer(int choiceIdx) {
    if (_answered || _busy) return;
    final q = _questions[_currentIndex];
    final isCorrect = choiceIdx == q.correctIndex;
    setState(() {
      _selectedChoice = choiceIdx;
      _answered = true;
      if (isCorrect) _score++;
    });
  }

  Future<void> _nextOrFinish() async {
    if (_busy) return;
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _selectedChoice = null;
        _answered = false;
      });
      return;
    }

    // Complete quiz in Supabase (generates unique 6-char alphanumeric reward_code if score >= min_score)
    final ev = _event;
    if (ev == null) return;
    setState(() => _busy = true);
    try {
      final completedSub = await _repo.completeQuiz(
        eventId: ev.id,
        deviceHash: _deviceHash,
        score: _score,
      );
      if (!mounted) return;
      setState(() {
        _submission = completedSub;
        _score = completedSub.score ?? _score;
        _savedResultBanner = false;
        _busy = false;
        _stage = _GuestStage.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba az eredmény mentésekor: $e')),
      );
    }
  }

  Future<void> _promptRedeemStaffPin() async {
    final sub = _submission;
    if (sub == null || sub.isRedeemed || sub.rewardCode == null) return;

    final pinController = TextEditingController();
    String? dialogError;
    bool submitting = false;

    final redeemed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(child: Text('Nyeremény beváltása (Staff Only)')),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kérjük, add át a készüléket a HUNOR stand személyzetének a nyeremény jóváhagyásához!',
                  style: TextStyle(fontSize: 13, color: HunorColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    labelText: 'Személyzeti PIN kód (Staff PIN)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: dialogError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Mégse'),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      final pin = pinController.text.trim();
                      if (pin.isEmpty) {
                        setDialogState(
                          () => dialogError = 'Add meg a személyzeti PIN kódot!',
                        );
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });
                      try {
                        final res = await _repo.redeemPrize(
                          submissionId: sub.id,
                          deviceHash: _deviceHash,
                          staffPin: pin,
                        );
                        if (!ctx.mounted) return;
                        if (res.ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            submitting = false;
                            dialogError = res.error == 'INVALID_STAFF_PIN'
                                ? 'Hibás személyzeti PIN kód!'
                                : 'A beváltás nem sikerült (${res.error}).';
                          });
                        }
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          submitting = false;
                          dialogError = 'Hálózati hiba történt. Próbáld újra!';
                        });
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Nyeremény kiadása'),
            ),
          ],
        ),
      ),
    );

    if (redeemed == true && mounted) {
      setState(() {
        _submission = QuizEventSubmission(
          id: sub.id,
          eventId: sub.eventId,
          startedAt: sub.startedAt,
          completedAt: sub.completedAt,
          score: sub.score,
          rewardCode: sub.rewardCode,
          isRedeemed: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Nyeremény sikeresen beváltva!'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: switch (_stage) {
                      _GuestStage.loading => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      _GuestStage.notFound => _buildStatusCard(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Esemény nem található',
                          subtitle:
                              'A megadott QR-kódhoz (${widget.eventSlug}) nem tartozik kvíz-esemény.',
                        ),
                      _GuestStage.inactive => _buildStatusCard(
                          icon: Icons.pause_circle_outline_rounded,
                          title: _event?.title ?? 'Kvíz lezárva',
                          subtitle:
                              'Ez a rendezvény-kvíz jelenleg nem aktív. Köszönjük az érdeklődést!',
                        ),
                      _GuestStage.error => _buildStatusCard(
                          icon: Icons.wifi_off_rounded,
                          title: 'Kapcsolódási hiba',
                          subtitle:
                              _errorMessage ?? 'Nem sikerült betölteni a kvízt.',
                          action: FilledButton.icon(
                            onPressed: _bootstrap,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Újrapróbálás'),
                          ),
                        ),
                      _GuestStage.intro => _buildIntroCard(),
                      _GuestStage.playing => _buildPlayingCard(),
                      _GuestStage.result => _buildResultCard(),
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ismeretterjesztő játék • Valódi vészhelyzetben hívd a 112-t!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF17253B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HunorColors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'H',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HUNOR • ESEMÉNY QR KVÍZ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                Text(
                  _event?.title ?? 'Vészhelyzeti Tudáspróba',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF17253B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    final ev = _event!;
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF17253B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '🎯 REGISZTRÁCIÓ NÉLKÜLI GYORS KIHÍVÁS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              ev.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tedd próbára a veszélyhelyzeti tudásodat! Ha eléred a nyereményhatárt, a végén egyedi nyereménykódot kapsz, amit a HUNOR standnál azonnal beválthatsz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    Icons.help_outline_rounded,
                    '${ev.questionCount} db',
                    'Kérdések száma',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoTile(
                    Icons.emoji_events_outlined,
                    'Min. ${ev.minScore} pont',
                    'Nyereményhatár',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoTile(
                    Icons.phone_iphone_rounded,
                    '1 kitöltés',
                    'Eszközönként',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: HunorColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : _onStartQuiz,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text(
                  'KVÍZ INDÍTÁSA (START QUIZ)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayingCard() {
    final q = _questions[_currentIndex];
    final total = _questions.length;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF17253B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kérdés ${_currentIndex + 1} / $total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1A2C),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Pontszám: $_score',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentIndex + (_answered ? 1 : 0)) / total,
                minHeight: 7,
                backgroundColor: Colors.white12,
                color: const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              q.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              q.question,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < q.choices.length; i++) ...[
              _buildChoiceButton(q, i),
              const SizedBox(height: 10),
            ],
            if (_answered) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_selectedChoice == q.correctIndex
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C))
                      .withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedChoice == q.correctIndex
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedChoice == q.correctIndex
                          ? '✓ Helyes válasz!'
                          : '✕ Helyes válasz: ${q.choices[q.correctIndex]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        q.explanation,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _nextOrFinish,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _currentIndex + 1 == total
                        ? 'EREDMÉNY ÉS NYEREMÉNYKÓD →'
                        : 'KÖVETKEZŐ KÉRDÉS →',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(QuizQuestionItem q, int i) {
    Color bg = const Color(0xFF0F1A2C);
    Color border = Colors.white24;
    if (_answered) {
      if (i == q.correctIndex) {
        bg = const Color(0xFF14532D);
        border = const Color(0xFF4ADE80);
      } else if (i == _selectedChoice) {
        bg = const Color(0xFF7F1D1D);
        border = const Color(0xFFF87171);
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _answered ? null : () => _selectAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + i),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                q.choices[i],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final ev = _event!;
    final sub = _submission;
    final score = sub?.score ?? _score;
    final total = ev.questionCount;
    final won = score >= ev.minScore && (sub?.rewardCode?.isNotEmpty ?? false);
    final isRedeemed = sub?.isRedeemed == true;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF17253B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savedResultBanner)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'ℹ️ Ezen a készüléken már teljesítetted ezt a rendezvény-kvízt. Alább látod a mentett eredményedet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFFBAE6FD)),
                ),
              ),
            Icon(
              won ? Icons.emoji_events_rounded : Icons.school_rounded,
              size: 62,
              color: won ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
            ),
            const SizedBox(height: 12),
            Text(
              won ? 'Gratulálunk, nyertél!' : 'Köszönjük a részvételt!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Elért eredmény: $score / $total pont (nyereményhatár: ${ev.minScore} pont)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 22),
            if (won) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isRedeemed
                      ? const Color(0xFF14532D).withValues(alpha: 0.45)
                      : const Color(0xFF0F1A2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRedeemed
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFFBBF24),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isRedeemed
                          ? '✓ NYEREMÉNY BEVÁLTVA (REDEEMED)'
                          : 'EGYEDI NYEREMÉNYKÓDOD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: isRedeemed
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      sub!.rewardCode!,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        fontFamily: 'monospace',
                        color: Colors.white,
                        decoration:
                            isRedeemed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRedeemed
                          ? 'Ezt a nyereményt a személyzet már kiadta.'
                          : 'Mutasd fel ezt a képernyőt a HUNOR standnál a nyeremény átvételéhez!',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isRedeemed
                        ? Colors.white12
                        : const Color(0xFFF59E0B),
                    foregroundColor:
                        isRedeemed ? Colors.white54 : const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isRedeemed ? null : _promptRedeemStaffPin,
                  icon: Icon(
                    isRedeemed
                        ? Icons.verified_rounded
                        : Icons.lock_person_rounded,
                  ),
                  label: Text(
                    isRedeemed
                        ? 'Nyeremény már beváltva'
                        : 'Redeem Prize (Staff Only)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1A2C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'A nyereménykódhoz legalább ${ev.minScore} helyes válasz szükséges. Köszönjük, hogy játszottál velünk – látogass el a HUNOR standhoz is!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
