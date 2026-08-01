import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/formatters.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/person_list_tile.dart';
import 'district_persons_screen.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

/// İl Detayı — UX §3.7: "İl Teşkilatı" ve "İlçeler" sekmeleri.
class ProvinceDetailScreen extends StatefulWidget {
  const ProvinceDetailScreen({super.key, required this.province});

  final Province province;

  @override
  State<ProvinceDetailScreen> createState() => _ProvinceDetailScreenState();
}

class _ProvinceDetailScreenState extends State<ProvinceDetailScreen> {
  bool? _isActive = true;
  String _query = '';
  Timer? _debounce;
  int _refreshTick = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<List<Person>> _loadPersons() async {
    final api = context.read<Api>();
    // İl Teşkilatı sekmesi: `il_teskilati` VE `temsilcilik` kişileri.
    final results = await Future.wait([
      api.persons(
        provinceId: widget.province.id,
        unitType: 'il_teskilati',
        isActive: _isActive,
        q: _query.isEmpty ? null : _query,
        limit: 500,
      ),
      api.persons(
        provinceId: widget.province.id,
        unitType: 'temsilcilik',
        isActive: _isActive,
        q: _query.isEmpty ? null : _query,
        limit: 500,
      ),
    ]);
    final persons = [...results[0].data, ...results[1].data]
      ..sort((a, b) => Formats.trLower(a.fullName)
          .compareTo(Formats.trLower(b.fullName)));
    return persons;
  }

  Future<void> _addPerson() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PersonFormScreen(
        initialProvinceId: widget.province.id,
      ),
    ));
    if (saved == true && mounted) setState(() => _refreshTick++);
  }

  Future<void> _openPerson(Person p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonDetailScreen(personId: p.id),
    ));
    if (mounted) setState(() => _refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    final refData = context.read<RefData>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.province.name} Teşkilatı'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'İl Teşkilatı'),
              Tab(text: 'İlçeler'),
            ],
          ),
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: _addPerson,
                icon: const Icon(Icons.person_add),
                label: const Text('Kişi Ekle'),
              )
            : null,
        body: TabBarView(
          children: [
            // Sekme 1 — İl Teşkilatı
            Column(
              children: [
                SearchField(hint: 'Kişi ara...', onChanged: _onSearchChanged),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActiveFilterChips(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                const SizedBox(height: s4),
                Expanded(
                  child: AsyncView<List<Person>>(
                    key: ValueKey(
                        'prov-${widget.province.id}-$_isActive-$_query-$_refreshTick'),
                    load: _loadPersons,
                    builder: (context, persons, reload) {
                      if (persons.isEmpty) {
                        if (_query.isNotEmpty) {
                          return const EmptyState(
                            icon: Icons.search_off_outlined,
                            message:
                                'Aramanızla eşleşen kişi bulunamadı.',
                          );
                        }
                        return EmptyState(
                          icon: Icons.person_off_outlined,
                          message:
                              'Bu il teşkilatında kayıtlı kişi bulunmuyor.',
                          actionLabel: isAdmin ? 'Kişi Ekle' : null,
                          onAction: isAdmin ? _addPerson : null,
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: reload,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(s16, s4, s16, 88),
                          itemCount: persons.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: s8),
                          itemBuilder: (context, i) {
                            final p = persons[i];
                            return PersonListTile(
                              person: p,
                              locationLabel:
                                  refData.personLocationLabel(p),
                              showRepresentationBadge: true,
                              onTap: () => _openPerson(p),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Sekme 2 — İlçeler
            AsyncView<List<District>>(
              load: () => refData.districtsOf(widget.province.id),
              builder: (context, districts, reload) {
                final sorted = [...districts]
                  ..sort((a, b) => Formats.trLower(a.name)
                      .compareTo(Formats.trLower(b.name)));
                if (sorted.isEmpty) {
                  return const EmptyState(
                    icon: Icons.location_off_outlined,
                    message: 'İlçe kaydı bulunamadı.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(s16, s16, s16, 88),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: s8),
                    itemBuilder: (context, i) {
                      final d = sorted[i];
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r12),
                          ),
                          title: Text(
                            d.name,
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: kTextSecondary),
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                            builder: (_) => DistrictPersonsScreen(
                              province: widget.province,
                              district: d,
                            ),
                          )),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
