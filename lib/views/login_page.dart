import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      backgroundColor: HunorColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Weblap hivatalos logója (hun01usar.hu)
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 240, maxHeight: 110),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Image.asset(
                        'assets/images/hunor_logo_dark.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_outlined,
                          size: 70,
                          color: HunorColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'HUNOR USAR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (store.isStaging)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: HunorColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: HunorColors.warning),
                      ),
                      child: const Text(
                        'STAGING · kizárólag fiktív tesztfiókok',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunorColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),

                  // Bejelentkező Űrlapkártya
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: HunorColors.navyCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HunorColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Bejelentkezés csapattagként',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add meg a hun01usar.hu portálon használt belépési adataidat.',
                          style: TextStyle(
                            fontSize: 12,
                            color: HunorColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // E-mail mező
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'E-mail cím',
                            labelStyle: const TextStyle(color: HunorColors.muted),
                            hintText: 'pelda@hun01usar.hu',
                            hintStyle: TextStyle(color: HunorColors.muted.withOpacity(0.6)),
                            prefixIcon: const Icon(Icons.email_outlined, color: HunorColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Jelszó mező
                        TextField(
                          controller: password,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Jelszó',
                            labelStyle: TextStyle(color: HunorColors.muted),
                            prefixIcon: Icon(Icons.lock_outline, color: HunorColors.muted),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Belépés Gomb
                        FilledButton.icon(
                          onPressed: store.isLoading
                              ? null
                              : () => store.signIn(email.text.trim(), password.text),
                          icon: store.isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: HunorColors.navy),
                                )
                              : const Icon(Icons.login_rounded, size: 20),
                          label: Text(
                            store.isLoading ? 'Hitelesítés...' : 'Bejelentkezés',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: HunorColors.gold,
                            foregroundColor: HunorColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),

                        // Hibaüzenet
                        if (store.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(top: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: HunorColors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: HunorColors.red.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: HunorColors.red, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    store.errorMessage!,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: HunorColors.line)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'VAGY',
                                style: TextStyle(color: HunorColors.muted.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Expanded(child: Divider(color: HunorColors.line)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Vendég / Előnézeti mód gomb (azonnali kipróbálás)
                        OutlinedButton.icon(
                          onPressed: store.isLoading
                              ? null
                              : () => store.enterAsGuest(),
                          icon: const Icon(Icons.explore_outlined, color: HunorColors.gold, size: 20),
                          label: const Text(
                            'Kipróbálás vendégként',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: HunorColors.gold.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Gyakorlatok, naptár és hírek megtekintése belépés nélkül.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HunorColors.muted, fontSize: 11),
                        ),

                        if (!store.isStaging && !store.isSupabase) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: store.isLoading
                                ? null
                                : () => store.signIn('mock@example.invalid', 'password'),
                            icon: const Icon(Icons.play_arrow_rounded, color: HunorColors.muted),
                            label: const Text(
                              'Gyors belépés (Mock fiók)',
                              style: TextStyle(color: HunorColors.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Regisztrációs útmutató
                  const Text(
                    'Még nincs fiókod? A mentőcsapat hivatalos tagjai a hun01usar.hu portálon tudnak regisztrációt kérni.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HunorColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
