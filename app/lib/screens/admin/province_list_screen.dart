import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/ref_data.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'province_detail_screen.dart';

/// İl Listesi — UX §3.6. 81 il, plaka sırasıyla; yerel TR duyarsız arama.
class ProvinceListScreen extends StatefulWidget {
  const ProvinceListScreen({super.key});

  @override
  State<ProvinceListScreen> createState() => _ProvinceListScreenState();
}

class _ProvinceListScreenState extends State<ProvinceListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final refData = context.read<RefData>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kadın Teşkilatları')),
      body: Column(
        children: [
          SearchField(hint: 'İl ara...', onChanged: (v) {
            setState(() => _query = v.trim());
          }),
          Expanded(
            child: AsyncView<List<Province>>(
              load: refData.provinces,
              builder: (context, provinces, reload) {
                final sorted = [...provinces]
                  ..sort((a, b) => a.code.compareTo(b.code));
                final filtered = _query.isEmpty
                    ? sorted
                    : sorted
                        .where((p) => Formats.trContains(p.name, _query))
                        .toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_outlined,
                    message: '"$_query" ile eşleşen il bulunamadı.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(s16, 0, s16, s16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: s8),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r12),
                          ),
                          leading: Container(
                            width: 40,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kInactiveContainer,
                              borderRadius: BorderRadius.circular(r8),
                            ),
                            child: Text(
                              p.code.toString().padLeft(2, '0'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: kTextSecondary),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) =>
                                ProvinceDetailScreen(province: p),
                          )),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
