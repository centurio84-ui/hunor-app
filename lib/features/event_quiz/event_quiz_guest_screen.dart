import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/hunor_theme.dart';
import 'device_hash_helper.dart';
import 'event_quiz_models.dart';
import 'event_quiz_repository.dart';

enum _GuestStage {
  loading,
  inactiveOrInvalid,
  intro,
  playing,
  result,
  error,
}

class EventQuizGuestScreen extends StatefulWidget {
  const EventQuizGuestScreen({
    super.key,
    this.eventSlug,
    this.repository,
  });

  final String? eventSlug;
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

  bool _isStandardPublicMode = false;
  QuizEvent? _event;
  QuizEventSubmission? _submission;

  List<QuizQuestionItem> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedChoice;
  bool _answered = false;
  bool _busy = false;
  bool _alreadyCompletedLock = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final rawSlug = widget.eventSlug?.trim().toLowerCase() ?? '';
    if (rawSlug.isEmpty) {
      await _enterStandardPublicIntro();
      return;
    }

    setState(() {
      _isStandardPublicMode = false;
      _stage = _GuestStage.loading;
      _errorMessage = null;
    });

    try {
      final hash = await getDeterministicDeviceHash();
      _deviceHash = hash;

      final state = await _repo.fetchPublicEventState(
        slug: rawSlug,
        deviceHash: hash,
      );

      if (!mounted) return;
      final ev = state.event;
      final sub = state.submission;

      // Invalid slug or inactive event -> show Hungarian inactive screen + standard quiz button
      if (ev == null || !ev.isActive) {
        _event = ev;
        _submission = sub;
        // If already completed before deactivation, still allow viewing saved result/coupon
        if (ev != null && sub != null && sub.isCompleted) {
          setState(() {
            _score = sub.score ?? 0;
            _alreadyCompletedLock = true;
            _stage = _GuestStage.result;
          });
          return;
        }
        setState(() => _stage = _GuestStage.inactiveOrInvalid);
        return;
      }

      _event = ev;
      _submission = sub;

      // One-attempt device lock: if already completed on this device, show saved result & coupon!
      if (sub != null && sub.isCompleted) {
        setState(() {
          _score = sub.score ?? 0;
          _alreadyCompletedLock = true;
          _stage = _GuestStage.result;
        });
        return;
      }

      setState(() {
        _alreadyCompletedLock = false;
        _stage = _GuestStage.intro;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _stage = _GuestStage.error;
      });
    }
  }

  Future<void> _enterStandardPublicIntro() async {
    setState(() {
      _isStandardPublicMode = true;
      _event = null;
      _submission = null;
      _alreadyCompletedLock = false;
      _stage = _GuestStage.intro;
    });
  }

  Future<void> _onStartQuiz() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (_isStandardPublicMode) {
        // Standard public quiz: 10 random questions across ALL 5 categories (98 total questions)
        final loaded = await _repo.loadRandomizedQuestions(
          categories: null,
          count: 10,
        );
        if (!mounted) return;
        setState(() {
          _questions = loaded;
          _currentIndex = 0;
          _score = 0;
          _selectedChoice = null;
          _answered = false;
          _busy = false;
          _stage = _GuestStage.playing;
        });
        return;
      }

      final ev = _event;
      if (ev == null) {
        setState(() => _busy = false);
        return;
      }

      // Upsert started_at = now() for drop-off telemetry
      final sub = await _repo.startQuiz(
        eventId: ev.id,
        deviceHash: _deviceHash,
      );

      if (sub.isCompleted) {
        if (!mounted) return;
        setState(() {
          _submission = sub;
          _score = sub.score ?? 0;
          _alreadyCompletedLock = true;
          _busy = false;
          _stage = _GuestStage.result;
        });
        return;
      }

      // Event quiz: filter questions where category = ANY(event.selected_categories)
      final loaded = await _repo.loadRandomizedQuestions(
        categories: ev.selectedCategories,
        count: ev.questionCount,
      );

      if (!mounted) return;
      setState(() {
        _submission = sub;
        _questions = loaded;
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

    if (_isStandardPublicMode) {
      setState(() => _stage = _GuestStage.result);
      return;
    }

    final ev = _event;
    if (ev == null) return;
    setState(() => _busy = true);
    try {
      final completedSub = await _repo.completeQuiz(
        event: ev,
        deviceHash: _deviceHash,
        score: _score,
      );
      if (!mounted) return;
      setState(() {
        _submission = completedSub;
        _score = completedSub.score ?? _score;
        _alreadyCompletedLock = false;
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
    final ev = _event;
    final sub = _submission;
    if (ev == null ||
        sub == null ||
        sub.isRedeemed ||
        sub.rewardCode == null) {
      return;
    }

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
              Expanded(
                child: Text(
                  'Nyeremény beváltása',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nyeremény: ${ev.rewardName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kuponkód: ${sub.rewardCode}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFBBF24),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add át a készüléket a helyszíni személyzetnek! A 4 jegyű személyzeti PIN kód megadásával a nyeremény beváltásra kerül.',
                  style: TextStyle(fontSize: 13, color: HunorColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  autofocus: true,
                  maxLength: 12,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Személyzeti PIN kód (4 jegyű)',
                    counterText: '',
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
                          event: ev,
                          submission: sub,
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
              label: const Text('Beváltás jóváhagyása'),
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
          deviceHash: sub.deviceHash,
          startedAt: sub.startedAt,
          completedAt: sub.completedAt,
          score: sub.score,
          rewardCode: sub.rewardCode,
          isRedeemed: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎁 Nyeremény (${ev.rewardName}) sikeresen BEVÁLTVA!',
          ),
          backgroundColor: const Color(0xFF15803D),
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
                      _GuestStage.inactiveOrInvalid => _buildInactiveCard(),
                      _GuestStage.error => _buildErrorCard(),
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
    final headerTitle = _isStandardPublicMode
        ? 'Vészhelyzeti kvíz'
        : (_event?.title ?? 'Vészhelyzeti kvíz');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF17253B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A2C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Color(0xFFFBBF24),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isStandardPublicMode
                      ? 'VÉSZHELYZETI KVÍZ • 5 TÉMAKÖR'
                      : 'VÉSZHELYZETI KVÍZ',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                Text(
                  headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
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

  Widget _buildMascotAvatar({double height = 110}) {
    return Image.asset(
      'assets/images/mad_chief.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.engineering_rounded,
        size: 64,
        color: Color(0xFFF59E0B),
      ),
    );
  }

  Widget _buildInactiveCard() {
    return Center(
      child: SingleChildScrollView(
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
              _buildMascotAvatar(height: 115),
              const SizedBox(height: 14),
              const Text(
                'Ez a rendezvénykvíz jelenleg nem aktív',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _event != null
                    ? 'A(z) „${_event!.title}” kvíz jelenleg le van zárva, de addig is próbára teheted a tudásodat a teljes, 98 kérdéses nyilvános kvízünkben!'
                    : 'A beolvasott QR-kódhoz tartozó rendezvénykvíz nem található vagy lezárult. Próbáld ki helyette az általános lakossági kvízt!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: HunorColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await _enterStandardPublicIntro();
                    await _onStartQuiz();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    'Általános lakossági kvíz indítása',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
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
            const Icon(
              Icons.wifi_off_rounded,
              size: 54,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kapcsolódási hiba',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Nem sikerült betölteni a kvízt.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _bootstrap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Újrapróbálás'),
                ),
                OutlinedButton(
                  onPressed: _enterStandardPublicIntro,
                  child: const Text('Általános lakossági kvíz'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    if (_isStandardPublicMode) {
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
              Center(child: _buildMascotAvatar(height: 120)),
              const SizedBox(height: 12),
              const Text(
                'Tudnád, mit tegyél vészhelyzetben?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '10 véletlenszerű kérdés mind az 5 veszélyhelyzeti témakörből (98 kérdéses tudásbázis) azonnali szakmai magyarázattal, regisztráció nélkül!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final key in kDefaultCategoryOrder)
                    _categoryPill(quizCategoryLabel(key)),
                ],
              ),
              const SizedBox(height: 24),
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
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text(
                    'KVÍZ INDÍTÁSA →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            Row(
              children: [
                _buildMascotAvatar(height: 105),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A2C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VÉSZHELYZETI KVÍZ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ev.hasConfiguredReward
                              ? 'Válaszolj helyesen legalább ${ev.minScore} kérdésre a ${ev.questionCount}-ből! Nyeremény: ${ev.rewardName}'
                              : 'Tedd próbára a tudásodat ${ev.questionCount} gyakorlati kérdéssel, és legyél felkészültebb!',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.38,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              ev.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final cat in ev.selectedCategories)
                  _categoryPill(quizCategoryLabel(cat)),
              ],
            ),
            const SizedBox(height: 20),
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
                  child: ev.hasConfiguredReward
                      ? _infoTile(
                          Icons.card_giftcard_rounded,
                          'Min. ${ev.minScore} pont',
                          ev.rewardName,
                        )
                      : _infoTile(
                          Icons.fact_check_outlined,
                          'Azonnali',
                          'Kiértékelés',
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
            const SizedBox(height: 24),
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
                  'KVÍZ INDÍTÁSA →',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFBAE6FD),
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
          Icon(icon, color: const Color(0xFFFBBF24), size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
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
    if (_questions.isEmpty) {
      return Center(
        child: FilledButton(
          onPressed: _bootstrap,
          child: const Text('Újratöltés'),
        ),
      );
    }

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
                    'Pontszám: $_score / $total',
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
            Align(
              alignment: Alignment.centerLeft,
              child: _categoryPill(q.categoryLabel),
            ),
            const SizedBox(height: 10),
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
            for (var i = 0; i < q.options.length; i++) ...[
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
                          : '✕ Helyes válasz: ${q.options[q.correctIndex]}',
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
                        ? 'EREDMÉNY MEGTEKINTÉSE →'
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
                q.options[i],
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
    // Standard Public Quiz result (repeatable practice mode)
    if (_isStandardPublicMode) {
      final total = _questions.isEmpty ? 10 : _questions.length;
      final pct = total > 0 ? ((_score / total) * 100).round() : 0;
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
              Center(child: _buildMascotAvatar(height: 120)),
              const SizedBox(height: 12),
              const Text(
                'Szép munka!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elért eredmény: $_score / $total helyes válasz ($pct%)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: HunorColors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _onStartQuiz,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(
                    'Új gyakorlókör indítása',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Event Quiz result (with one-attempt lock + optional configurable reward & Staff PIN redemption)
    final ev = _event!;
    final sub = _submission;
    final score = sub?.score ?? _score;
    final total = _questions.isNotEmpty ? _questions.length : ev.questionCount;
    final won = ev.hasConfiguredReward &&
        score >= ev.minScore &&
        (sub?.rewardCode?.isNotEmpty ?? false);
    final isRedeemed = sub?.isRedeemed == true;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF17253B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: won
                ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_alreadyCompletedLock)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF7DD3FC),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ezt a rendezvénykvízt ezen az eszközön már kitöltötted!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE0F2FE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Center(child: _buildMascotAvatar(height: 130)),
            const SizedBox(height: 10),
            Text(
              won
                  ? '🎉 Gratulálunk! Nyereményed: ${ev.rewardName}'
                  : 'Köszönjük a részvételt!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ev.hasConfiguredReward
                  ? 'Elért pontszám: $score / $total pont (minimum: ${ev.minScore} pont)'
                  : 'Elért pontszám: $score / $total helyes válasz (${total > 0 ? ((score / total) * 100).round() : 0}%)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            if (won) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRedeemed
                        ? [
                            const Color(0xFF14532D).withValues(alpha: 0.55),
                            const Color(0xFF0F1A2C),
                          ]
                        : [
                            const Color(0xFF451A03).withValues(alpha: 0.75),
                            const Color(0xFF0F1A2C),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
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
                          ? 'NYEREMÉNYKUPON (${ev.rewardName.toUpperCase()})'
                          : '🎁 EGYEDI NYEREMÉNYKÓDOD • ${ev.rewardName.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: isRedeemed
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      sub!.rewardCode!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        fontFamily: 'monospace',
                        color: Colors.white,
                        decoration:
                            isRedeemed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRedeemed
                          ? 'Ezt a nyereményt már beváltották.'
                          : 'Mutasd fel ezt a képernyőt a helyszíni standnál! A gombot kizárólag a személyzet kezelheti.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 12.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (isRedeemed)
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                      width: 1.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'BEVÁLTVA',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _promptRedeemStaffPin,
                    icon: const Icon(Icons.lock_person_rounded),
                    label: const Text(
                      'Nyeremény beváltása (Személyzet kezeli)',
                      style: TextStyle(
                        fontSize: 14.5,
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
                child: Column(
                  children: [
                    Text(
                      ev.hasConfiguredReward
                          ? 'A nyereményhez (${ev.rewardName}) legalább ${ev.minScore} helyes válasz szükséges. Köszönjük, hogy velünk játszottál!'
                          : 'Gratulálunk a kvíz teljesítéséhez! A megszerzett tudás valódi vészhelyzetben életet menthet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _enterStandardPublicIntro();
                        await _onStartQuiz();
                      },
                      icon: const Icon(Icons.school_outlined, size: 18),
                      label: const Text('Gyakorlás az általános kvízzel'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
