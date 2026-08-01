import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ref_data.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'body_members_screen.dart';
import 'commission_list_screen.dart';
import 'province_list_screen.dart';

/// Yönetim Paneli (home) — UX §3.2.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _openKurul(BuildContext context) async {
    final refData = context.read<RefData>();
    final navigator = Navigator.of(context);
    try {
      final kurul = await refData.kurulBody();
      if (kurul == null) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => BodyMembersScreen(
          bodyId: kurul.id,
          title: 'Koordinasyon Kurulu',
        ),
      ));
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'Bir şeyler ters gitti.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli')),
      body: ListView(
        padding: const EdgeInsets.all(s16),
        children: [
          NavCard(
            title: 'Koordinasyon Kurulu',
            subtitle: 'Kurul üyelerini görüntüle ve yönet',
            icon: Icons.account_balance_outlined,
            onTap: () => _openKurul(context),
          ),
          const SizedBox(height: s12),
          NavCard(
            title: 'Komisyonlar',
            subtitle: '6 komisyon ve üyelikleri',
            icon: Icons.diversity_3_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CommissionListScreen(),
            )),
          ),
          const SizedBox(height: s12),
          NavCard(
            title: 'Kadın Teşkilatları',
            subtitle: '81 il ve ilçe teşkilatları',
            icon: Icons.location_city_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProvinceListScreen(),
            )),
          ),
        ],
      ),
    );
  }
}
