import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ref_data.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'body_members_screen.dart';

/// Komisyon Listesi — UX §3.3.
class CommissionListScreen extends StatelessWidget {
  const CommissionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refData = context.read<RefData>();
    return Scaffold(
      appBar: AppBar(title: const Text('Komisyonlar')),
      body: AsyncView<List<Body>>(
        load: () async {
          final bodies = await refData.bodies();
          return bodies.where((b) => b.type == 'komisyon').toList();
        },
        builder: (context, commissions, reload) {
          if (commissions.isEmpty) {
            return const EmptyState(
              icon: Icons.diversity_3_outlined,
              message: 'Henüz komisyon tanımlanmamış.',
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(s16),
              itemCount: commissions.length,
              separatorBuilder: (_, _) => const SizedBox(height: s8),
              itemBuilder: (context, i) {
                final c = commissions[i];
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r12),
                    ),
                    title: Text(
                      c.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: kTextSecondary),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          BodyMembersScreen(bodyId: c.id, title: c.name),
                    )),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
