import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_v2.dart';
import '../../core/password_rules.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../core/strings_v2.dart';
import '../../forms/dynamic_form.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/info_block.dart';
import '../v2/shared.dart';

/// Şifre Değiştir — docs/UX-V2.md §6.6 (E-80) ve API-V2 §1.8.
///
/// İki bağlamda açılır:
/// * Profil'den (`forced: false`) — normal bir form, `Vazgeç` ile çıkılır.
/// * Zorunlu şifre değişikliğinde (`forced: true`) — uygulamanın **kökü**dür;
///   geri dönüş yoktur, tek çıkış yolu şifreyi değiştirmek ya da çıkış yapmak.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();

  Map<String, String> _errors = const {};
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _current.text.isNotEmpty ||
      _next.text.isNotEmpty ||
      _repeat.text.isNotEmpty;

  void _clearError(String field) {
    if (!_errors.containsKey(field)) return;
    setState(() => _errors = {..._errors}..remove(field));
  }

  Future<bool> _confirmExit() async {
    if (!_isDirty) return true;
    return showConfirmDialog(
      context,
      title: S2.kirliBaslik,
      body: S2.kirliGovde,
      confirmText: S2.cik,
    );
  }

  Future<void> _save() async {
    final errors = PasswordRules.validate(
      current: _current.text,
      next: _next.text,
      repeat: _repeat.text,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _errors = const {};
      _saving = true;
    });
    try {
      await context.api2.changeOwnPassword(_current.text, _next.text);
      if (!mounted) return;
      // §1.8 — bayrak düşer, aynı token çalışmaya devam eder.
      context.read<Session>().passwordChanged();
      showAppSnackBar(context, S2.basariSifre);
      setState(() => _saving = false);
      if (!widget.forced && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        _current.clear();
        _next.clear();
        _repeat.clear();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // 401 → mevcut şifre hatalı · 400 WEAK_PASSWORD → yeni şifre kuralı.
        if (e.isUnauthorized) {
          _errors = {PasswordRules.fieldCurrent: S2.vMevcutSifreHatali};
        } else if (e.code == 'WEAK_PASSWORD') {
          _errors = {
            PasswordRules.fieldNew:
                e.message.isNotEmpty ? e.message : S2.vSifreYeniKisa,
          };
        } else {
          _errors = const {};
        }
      });
      if (_errors.isEmpty && mounted) {
        showAppSnackBar(context, v2ErrorMessage(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _logout() async {
    final session = context.read<Session>();
    final refData = context.read<RefData>();
    final ok = await showConfirmDialog(
      context,
      title: 'Çıkış yap',
      body: 'Oturumunuz kapatılacak. Devam edilsin mi?',
      confirmText: Str.cikisYap,
    );
    if (!ok) return;
    refData.clear();
    await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.forced) ...[
                const NoticeCard(
                    text: S2.sifreZorunluGovde, margin: EdgeInsets.zero),
                const SizedBox(height: s16),
              ],
              _PasswordInput(
                label: S2.sifreMevcut,
                controller: _current,
                error: _errors[PasswordRules.fieldCurrent],
                enabled: !_saving,
                onChanged: () => _clearError(PasswordRules.fieldCurrent),
              ),
              const SizedBox(height: s16),
              _PasswordInput(
                label: S2.sifreYeni,
                controller: _next,
                error: _errors[PasswordRules.fieldNew],
                helper: S2.sifreKurali,
                enabled: !_saving,
                onChanged: () => _clearError(PasswordRules.fieldNew),
              ),
              const SizedBox(height: s16),
              _PasswordInput(
                label: S2.sifreYeniTekrar,
                controller: _repeat,
                error: _errors[PasswordRules.fieldRepeat],
                enabled: !_saving,
                onChanged: () => _clearError(PasswordRules.fieldRepeat),
              ),
              if (widget.forced) ...[
                const SizedBox(height: s24),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kError,
                    side: const BorderSide(color: kError),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(Str.cikisYap),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return PopScope(
      // Zorunlu modda geri çıkış yok; normal modda kirli form onayı sorulur.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || widget.forced) return;
        if (await _confirmExit() && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.forced ? S2.sifreZorunluBaslik : S2.sifreDegistir),
          automaticallyImplyLeading: !widget.forced,
        ),
        body: Column(
          children: [
            Expanded(child: body),
            FormActionBar(
              onSave: _save,
              onCancel: widget.forced
                  ? null
                  : () async {
                      if (await _confirmExit() && context.mounted) {
                        if (!context.mounted) return;
                        Navigator.of(context).pop(false);
                      }
                    },
              saving: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gizli metin alanı + göz ikonu (§6.6 E-80).
class _PasswordInput extends StatefulWidget {
  const _PasswordInput({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.error,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;
  final String? helper;
  final bool enabled;

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: kTextSecondary)),
        const SizedBox(height: s4),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscure,
          autofillHints: const [],
          decoration: InputDecoration(
            isDense: true,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
              icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: kTextSecondary),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: s4),
          Text(widget.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: kError)),
        ] else if (widget.helper != null) ...[
          const SizedBox(height: s4),
          Text(widget.helper!,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: kTextSecondary)),
        ],
      ],
    );
  }
}
