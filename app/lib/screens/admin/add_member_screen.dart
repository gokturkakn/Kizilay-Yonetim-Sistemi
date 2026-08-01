import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/person_list_tile.dart';

/// Üye Ekle (kayıtlı kişiden seçim) — UX §3.5.
class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key, required this.bodyId});

  final int bodyId;

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Set<int> _existingMemberIds = {};
  bool _added = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<List<Person>> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    // Mevcut üyeler soluk gösterilir.
    final members = await api.bodyMembers(widget.bodyId);
    _existingMemberIds = members.map((m) => m.person.id).toSet();
    final result = await api.persons(q: _query.isEmpty ? null : _query);
    await refData.primeForPersons(result.data);
    return result.data;
  }

  Future<void> _selectPerson(
      Person p, Future<void> Function() reload) async {
    final api = context.read<Api>();
    final roleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üyelik bilgisi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.fullName),
            const SizedBox(height: s16),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                labelText: 'Görev / Unvan (isteğe bağlı)',
                hintText: 'Örn. Başkan, Sekreter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Str.vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      roleController.dispose();
      return;
    }
    final roleTitle = roleController.text.trim();
    roleController.dispose();
    try {
      await api.addMember(
          widget.bodyId, p.id, roleTitle.isEmpty ? null : roleTitle);
      _added = true;
      if (!mounted) return;
      showAppSnackBar(context, 'Üye eklendi.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // saha rolü bu ekrana ulaşamaz; ikinci kademe kontrol yine de yapılır.
    if (!context.read<Session>().isAdmin) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final refData = context.read<RefData>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_added);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Üye Ekle')),
        body: Column(
          children: [
            SearchField(
              hint: 'Ad veya soyad ile ara...',
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            Expanded(
              child: AsyncView<List<Person>>(
                key: ValueKey('add-member-$_query'),
                load: _load,
                builder: (context, persons, reload) {
                  if (persons.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'Aramanızla eşleşen kişi bulunamadı.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(s16, 0, s16, s16),
                    itemCount: persons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: s8),
                    itemBuilder: (context, i) {
                      final p = persons[i];
                      final isMember = _existingMemberIds.contains(p.id);
                      return PersonListTile(
                        person: p,
                        locationLabel: refData.personLocationLabel(p),
                        disabled: isMember,
                        onTap: () => _selectPerson(p, reload),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
