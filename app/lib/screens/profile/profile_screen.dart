import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Profil — UX §3.20.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
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
    final theme = Theme.of(context);
    final user = context.watch<Session>().user;
    if (user == null) return const SizedBox.shrink();
    final isAdmin = user.isAdmin;
    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name
            .trim()
            .split(RegExp(r'\s+'))
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(s24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: kPrimaryContainer,
                      child: Text(
                        initials,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: kPrimary),
                      ),
                    ),
                    const SizedBox(height: s12),
                    Text(user.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: s4),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kTextSecondary),
                    ),
                    const SizedBox(height: s12),
                    StatusBadge(
                      label: isAdmin ? 'Genel Merkez' : 'Saha',
                      foreground: isAdmin ? kPrimary : kInactive,
                      background:
                          isAdmin ? kPrimaryContainer : kInactiveContainer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: s16),
            Text(
              'Sürüm ${AppConfig.appVersion}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kTextSecondary),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: kError,
                side: const BorderSide(color: kError),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(Str.cikisYap),
            ),
          ],
        ),
      ),
    );
  }
}
