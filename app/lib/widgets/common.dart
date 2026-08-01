import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../theme/tokens.dart';

/// Tekil snackbar (yenisi eskisini kapatır), 3 sn — UX §4.5.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 3),
  ));
}

/// Onay dialoğu; onaylandıysa true döner.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmText = Str.onayla,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(Str.vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: kError)
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Durum rozeti (stadium) — Aktif/Pasif/Atandı/Devam Ediyor/Tamamlandı.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  const StatusBadge.active({super.key})
      : label = Str.aktif,
        foreground = kSuccess,
        background = kSuccessContainer;

  const StatusBadge.inactive({super.key})
      : label = Str.pasif,
        foreground = kInactive,
        background = kInactiveContainer;

  factory StatusBadge.activity(bool isActive, {Key? key}) => isActive
      ? StatusBadge.active(key: key)
      : StatusBadge.inactive(key: key);

  /// Atama durumu rozeti — UX §3.16.
  factory StatusBadge.assignment(String status, {Key? key}) {
    switch (status) {
      case 'devam':
        return StatusBadge(
          key: key,
          label: Str.devam,
          foreground: kWarning,
          background: kWarningContainer,
        );
      case 'tamamlandi':
        return StatusBadge(
          key: key,
          label: Str.tamamlandi,
          foreground: kSuccess,
          background: kSuccessContainer,
        );
      case 'atandi':
      default:
        return StatusBadge(
          key: key,
          label: Str.atandi,
          foreground: kInfo,
          background: kInfoContainer,
        );
    }
  }

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: s8, vertical: s4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(rFull),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Filtre çipleri: Tümü / Aktif / Pasif — UX §4.2.
/// [value]: null = Tümü, true = Aktif, false = Pasif.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool? v) {
      final selected = value == v;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? kPrimary : kTextPrimary,
        ),
        onSelected: (_) => onChanged(v),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: s16),
      child: Wrap(
        spacing: s8,
        children: [
          chip(Str.tumu, null),
          chip(Str.aktif, true),
          chip(Str.pasif, false),
        ],
      ),
    );
  }
}

/// Boş durum kalıbı — UX §4.5.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.subMessage,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? subMessage;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: kTextDisabled),
            const SizedBox(height: s16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: s8),
              Text(
                subMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kTextSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: s16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hata durumu kalıbı — UX §4.5.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: kTextDisabled),
            const SizedBox(height: s16),
            Text(Str.hataGenel, style: theme.textTheme.titleMedium),
            const SizedBox(height: s8),
            Text(
              message ??
                  'Veriler yüklenemedi. İnternet bağlantınızı kontrol edin.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: kTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: s16),
            OutlinedButton(
                onPressed: onRetry, child: const Text(Str.tekrarDene)),
          ],
        ),
      ),
    );
  }
}

/// Yüklenme / hata / veri durumlarını yöneten genel sarmalayıcı.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(
      BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(onRetry: _run);
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// Büyük gezinme kartı (Yönetim Paneli / Saha Çalışmaları girişleri).
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(r12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Row(
            children: [
              Icon(icon, color: kPrimary, size: 32),
              const SizedBox(width: s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: s4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arama alanı (liste üstü kalıcı arama kutusu).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(s16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: kTextSecondary),
          isDense: true,
        ),
      ),
    );
  }
}
