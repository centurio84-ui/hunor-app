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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 72, color: HunorColors.red),
                  const SizedBox(height: 16),
                  Text(
                    'MADtech Rescue Platform',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mentőszervezetek Központi Mobilalkalmazása',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: HunorColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: HunorColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      store.isStaging ? 'STAGING · kizárólag fiktív tesztfiókok' : 'Fejlesztői mód: Mock API (Offline)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunorColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail cím',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Jelszó',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: store.isLoading
                        ? null
                        : () => store.signIn(email.text.trim(), password.text),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: store.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Bejelentkezés', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  if(!store.isStaging) OutlinedButton.icon(
                    onPressed: store.isLoading
                        ? null
                        : () => store.signIn('mock@example.invalid', 'password'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Gyors belépés (Mock fiók)'),
                  ),
                  if (store.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        store.errorMessage!,
                        style: const TextStyle(color: HunorColors.red),
                        textAlign: TextAlign.center,
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
