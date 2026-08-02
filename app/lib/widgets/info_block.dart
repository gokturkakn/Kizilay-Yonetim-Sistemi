import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_v2.dart';
import '../core/strings_v2.dart';
import '../models/models_v2.dart';
import '../theme/tokens.dart';

/// Bilgilendirme metni başlığı — docs/UX-V2.md §6.1.1.
///
/// Metin yoksa (404 veya boş gövde) bileşen **hiç render edilmez**;
/// yer tutucu gösterilmez.
class InfoBlockHeader extends StatefulWidget {
  const InfoBlockHeader({super.key, required this.blockKey, required this.api});

  final String blockKey;
  final ApiV2 api;

  @override
  State<InfoBlockHeader> createState() => _InfoBlockHeaderState();
}

class _InfoBlockHeaderState extends State<InfoBlockHeader> {
  ContentBlock? _block;
  bool _expanded = false;
  bool _dismissed = false;
  bool _ready = false;

  String get _prefKey => 'info_block_dismissed_${widget.blockKey}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed = prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      _dismissed = false;
    }
    try {
      final block = await widget.api.contentBlock(widget.blockKey);
      if (!mounted) return;
      setState(() {
        _block = block.isEmpty ? null : block;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = true); // 404 → hiç render edilmez
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {
      // yerel tercih yazılamazsa yok sayılır
    }
  }

  /// AppBar'daki `Icons.info_outline` düğmesi bunu çağırır.
  Future<void> reopen() async {
    setState(() => _dismissed = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, false);
    } catch (_) {
      // yok sayılır
    }
  }

  bool get hasContent => _block != null;
  bool get isDismissed => _dismissed;

  @override
  Widget build(BuildContext context) {
    final block = _block;
    if (!_ready || block == null || _dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(s16, s16, s16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryContainer,
          borderRadius: BorderRadius.circular(r12),
          border: const Border(left: BorderSide(color: kPrimary, width: 3)),
        ),
        padding: const EdgeInsets.all(s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: kPrimary, size: 20),
                const SizedBox(width: s8),
                Expanded(
                  child: Text(block.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: kTextPrimary)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close, size: 18, color: kTextSecondary),
                  onPressed: _dismiss,
                ),
              ],
            ),
            const SizedBox(height: s4),
            Text(
              block.body,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: kTextPrimary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? S2.dahaAzGoster : S2.dahaFazlaGoster),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `kWarningContainer` zeminli bilgi kartı — kullanıcıya sistemin
/// sağlamadığı bir güvence verilmeyen yerlerde kullanılır (§6.5, §5.5).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.background = kWarningContainer,
    this.foreground = kWarning,
    this.margin = const EdgeInsets.fromLTRB(s16, s16, s16, 0),
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(r8),
        ),
        padding: const EdgeInsets.all(s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: s8),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: kTextPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
