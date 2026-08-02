import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'user_form_screen.dart';

/// E-66 · Yetkilendirme — docs/UX-V2.md §6.5.
///
/// Matris bu sürümde **düzenlenemez**; yetkiler sunucuda role gömülüdür
/// (API-V2 §1.6). Değiştirilebilirmiş gibi `Checkbox` gösterilmez.
class AuthorizationScreen extends StatefulWidget {
  const AuthorizationScreen({super.key});

  @override
  State<AuthorizationScreen> createState() => _AuthorizationScreenState();
}

class _AuthorizationScreenState extends State<AuthorizationScreen> {
  List<UserAccount> _users = const [];
  bool _loading = true;

  static const _modules = [
    'Teşkilatlanma',
    'Saha Faaliyetleri',
    'Lojistik',
    'Raporlama ve Dashboard',
    'Yönetim Paneli',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.api2.users();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Rol yetkileri (sunucuda sabit) — yalnız görüntülenir.
  List<bool> _permissions(String role, String module) {
    if (role == 'genel_merkez') return const [true, true, true, true];
    switch (module) {
      case 'Saha Faaliyetleri':
        return const [true, true, true, false];
      case 'Lojistik':
        return const [true, true, false, false];
      default:
        return const [false, false, false, false];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoped = _users
        .where((u) => u.regionId != null || u.provinceId != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Yetkilendirme')),
      body: ListView(
        children: [
          const NoticeCard(text: S2.yetkiSabit),
          for (final role in const ['genel_merkez', 'saha'])
            Padding(
              padding: const EdgeInsets.fromLTRB(s16, s16, s16, 0),
              child: Card(
                child: ExpansionTile(
                  title: Text(
                      role == 'genel_merkez' ? 'Genel Merkez' : 'Saha',
                      style: theme.textTheme.titleMedium),
                  subtitle: Text(
                      '${_users.where((u) => u.role == role).length} kullanıcı'),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Modül')),
                          DataColumn(label: Text('Görüntüle')),
                          DataColumn(label: Text('Ekle')),
                          DataColumn(label: Text('Düzenle')),
                          DataColumn(label: Text('Sil')),
                        ],
                        rows: [
                          for (final m in _modules)
                            DataRow(cells: [
                              DataCell(Text(m)),
                              for (final allowed in _permissions(role, m))
                                DataCell(Icon(
                                  allowed ? Icons.check : Icons.remove,
                                  size: 18,
                                  color:
                                      allowed ? kSuccess : kTextDisabled,
                                )),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(s16, s24, s16, s8),
            child: Text('Kapsam Tanımlı Kullanıcılar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(s16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (scoped.isEmpty)
            const Padding(
              padding: EdgeInsets.all(s16),
              child: Text('Kapsam tanımlı kullanıcı bulunmuyor.',
                  style: TextStyle(color: kTextSecondary)),
            )
          else
            for (final u in scoped)
              ListTile(
                title: Text(u.name),
                subtitle: Text([u.regionName, u.provinceName]
                    .whereType<String>()
                    .join(' / ')),
                trailing:
                    const Icon(Icons.chevron_right, color: kTextSecondary),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserFormScreen(existing: u),
                )),
              ),
          const Padding(
            padding: EdgeInsets.all(s16),
            child: Text(S2.kapsamRaporlama,
                style: TextStyle(fontSize: 12, color: kTextSecondary)),
          ),
        ],
      ),
    );
  }
}
