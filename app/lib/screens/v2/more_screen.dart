import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/layout.dart';
import '../../core/session.dart';
import '../../core/strings_v2.dart';
import '../../theme/tokens.dart';

/// E-90 · Daha Fazla — yalnız `< 600` (docs/UX-V2.md §6.6).
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.onOpen});

  final ValueChanged<AppDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().isAdmin;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S2.dahaFazla)),
      body: ListView(
        children: [
          if (isAdmin)
            _MoreRow(
              icon: Icons.settings_outlined,
              title: S2.modulYonetim,
              subtitle: 'Kullanıcılar, tanımlar ve ayarlar',
              onTap: () => onOpen(AppDestination.yonetim),
            ),
          _MoreRow(
            icon: Icons.person_outline,
            title: S2.modulProfil,
            subtitle: 'Hesap bilgileri ve çıkış',
            onTap: () => onOpen(AppDestination.profil),
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
