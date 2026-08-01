import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/ref_data.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/person_list_tile.dart';

/// Kişi seçici — Atama Formu için (UX §3.17, §3.5 arama deseni).
class PersonPickerScreen extends StatefulWidget {
  const PersonPickerScreen({super.key});

  @override
  State<PersonPickerScreen> createState() => _PersonPickerScreenState();
}

class _PersonPickerScreenState extends State<PersonPickerScreen> {
  Timer? _debounce;
  String _query = '';

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

  Future<List<Person>> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    final result =
        await api.persons(q: _query.isEmpty ? null : _query);
    await refData.primeForPersons(result.data);
    return result.data;
  }

  @override
  Widget build(BuildContext context) {
    final refData = context.read<RefData>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kişi')),
      body: Column(
        children: [
          SearchField(
            hint: 'Ad veya soyad ile ara...',
            onChanged: _onSearchChanged,
          ),
          Expanded(
            child: AsyncView<List<Person>>(
              key: ValueKey('picker-$_query'),
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
                    return PersonListTile(
                      person: p,
                      locationLabel: refData.personLocationLabel(p),
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
