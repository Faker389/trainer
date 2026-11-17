import 'package:flutter/material.dart';

import '../data/demo.dart';
import '../ui/widgets.dart';
import 'auth_service.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? _validateEmail(String? v) =>
    v == null || !_emailPattern.hasMatch(v.trim()) ? 'Podaj prawidłowy adres e-mail' : null;

/// Runs an auth action with a busy flag and shows errors as a snackbar.
mixin _AuthAction<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<bool> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      return true;
    } on AuthCancelled {
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.message(e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction action;
  const _PasswordField(this.controller, this.label, {this.validator, this.action = TextInputAction.done});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        textInputAction: widget.action,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
        validator: widget.validator ?? (v) => v == null || v.isEmpty ? 'Podaj hasło' : null,
      );
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4285F4))),
        label: const Padding(padding: EdgeInsets.all(12), child: Text('Kontynuuj z Google')),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with _AuthAction {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    await run(() => AuthService.signIn(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.fitness_center, size: 46, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('AI Trainer',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text('Dziennik treningowy z analizą techniki',
                        textAlign: TextAlign.center, style: TextStyle(color: context.shade(0.54), fontSize: 14)),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(_password, 'Hasło'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(initialEmail: _email.text),
                        )),
                        child: const Text('Nie pamiętasz hasła?'),
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : _login,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: busy
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Zaloguj się', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('lub', style: TextStyle(color: context.shade(0.38), fontSize: 12)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 20),
                    _GoogleButton(onPressed: busy ? null : () => run(AuthService.signInWithGoogle)),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Nie masz konta?'),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Zarejestruj się'),
                      ),
                    ]),
                    TextButton(
                      onPressed: () => demoStoreOverride.value = demoStore(),
                      child: Text('Wypróbuj demo bez konta',
                          style: TextStyle(color: context.shade(0.5))),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with _AuthAction {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final ok = await run(() => AuthService.register(_name.text, _email.text, _password.text));
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Konto utworzone. Wysłaliśmy link potwierdzający na Twój e-mail.'),
      ));
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Załóż konto')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Imię', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  _password,
                  'Hasło (min. 8 znaków)',
                  action: TextInputAction.next,
                  validator: (v) => v == null || v.length < 8 ? 'Hasło musi mieć co najmniej 8 znaków' : null,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  _confirm,
                  'Powtórz hasło',
                  validator: (v) => v != _password.text ? 'Hasła nie są takie same' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _register,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Utwórz konto', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                _GoogleButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await run(AuthService.signInWithGoogle) && context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                ),
              ]),
            ),
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with _AuthAction {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sent = false;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (await run(() => AuthService.sendPasswordReset(_email.text))) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset hasła')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Podaj adres e-mail konta. Wyślemy link, przez który ustawisz nowe hasło.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline)),
                validator: _validateEmail,
              ),
              const SizedBox(height: 24),
              if (_sent)
                Card(
                  color: const Color(0xFF065F46),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Jeśli konto ${_email.text.trim()} istnieje, link do zmiany hasła jest już w skrzynce. '
                        'Sprawdź też folder spam.'),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_sent ? 'Wyślij ponownie' : 'Wyślij link'),
                ),
              ),
              if (_sent)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Wróć do logowania')),
            ]),
          ),
        ),
      );
}
