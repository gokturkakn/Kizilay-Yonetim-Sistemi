import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/strings_v2.dart';
import '../../theme/tokens.dart';

/// E-90 · Daha Fazla — yalnız `< 600` (docs/UX-V2.md §6.6).
///
/// İçerik **tek kaynaktan** türetilir: [moreDestinationsForRole], yani alt
/// çubuğa sığmayan hedeflerin kuyruğu. Böylece 6. modül (Kılavuz ve
/// Dokümanlar) eklendiğinde `genel_merkez` için burada kendiliğinden belirir
/// (SPEC-V2-M6 §5.1) ve `saha`'da — doğrudan sekme olduğu için — belirmez.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.role, required this.onOpen});

  final String role;
  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = moreDestinationsForRole(role);
    return Scaffold(
      appBar: AppBar(title: const Text(S2.dahaFazla)),
      body: ListView(
        children: [
          for (final d in destinations)
            _MoreRow(
              icon: d.icon,
              title: d.fullLabel,
              subtitle: d.moreSubtitle,
              onTap: () => onOpen(d),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(s16),
            child: Text(S2.surum,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: kTextSecondary)),
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: kPrimary),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right, color: kTextSecondary),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
