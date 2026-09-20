import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.shield, size: 72), const SizedBox(height: 16),
            Text('HUNOR', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8), const Text('HUNOR Mentőszervezet belső alkalmazása', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: password, obscureText: true,
              onSubmitted: (_) => store.signIn(email.text.trim(), password.text),
              decoration: const InputDecoration(labelText: 'Jelszó', border: OutlineInputBorder())),
            const SizedBox(height: 18),
            FilledButton(onPressed: store.isLoading ? null : () => store.signIn(email.text.trim(), password.text),
              child: store.isLoading ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Bejelentkezés')),
            if (store.errorMessage != null) Padding(padding: const EdgeInsets.only(top:12), child: Text(store.errorMessage!)),
          ]),
        ),
      ))),
    );
  }
}
