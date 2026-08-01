import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../core/validators.dart';
import '../main.dart';
import '../theme/tokens.dart';

/// Giriş ekranı — UX §3.1.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    maybeShowSessionExpired(context, context.read<Session>());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<Session>().login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      // Başarı: _Root oturum durumuna göre Ana İskelete geçer.
    } on ApiException catch (e) {
      setState(() {
        _serverError = e.isUnauthorized
            ? 'E-posta veya şifre hatalı.'
            : (e.isNetwork ? Str.hataAg : e.displayMessage);
      });
    } catch (_) {
      setState(() => _serverError = Str.hataGenel);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.brightness_2, size: 56, color: kPrimary),
                    const SizedBox(height: s16),
                    Text(
                      'Kızılay Kadın',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: s4),
                    Text(
                      'Teşkilat Yönetim Sistemi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kTextSecondary),
                    ),
                    const SizedBox(height: s32),
                    if (_serverError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(s12),
                        decoration: BoxDecoration(
                          color: kErrorContainer,
                          borderRadius: BorderRadius.circular(r8),
                        ),
                        child: Text(
                          _serverError!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kError),
                        ),
                      ),
                      const SizedBox(height: s16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration:
                          const InputDecoration(labelText: 'E-posta'),
                      validator: Validators.loginEmail,
                    ),
                    const SizedBox(height: s16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.loginPassword,
                      onFieldSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    const SizedBox(height: s24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: kOnPrimary,
                              ),
                            )
                          : const Text('Giriş Yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
