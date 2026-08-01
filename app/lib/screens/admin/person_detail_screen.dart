import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/formatters.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'person_form_screen.dart';

/// Kişi Detayı — UX §3.10.
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final int personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  int _refreshTick = 0;

  Future<Person> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    final person = await api.personById(widget.personId);
    await refData.primeForPersons([person]);
    return person;
  }

  Future<void> _edit(Person p) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PersonFormScreen(person: p),
    ));
    if (saved == true && mounted) setState(() => _refreshTick++);
  }

  Future<void> _toggleActive(
      Person p, Future<void> Function() reload) async {
    final api = context.read<Api>();
    final target = !p.isActive;
    final ok = await showConfirmDialog(
      context,
      title: 'Durumu değiştir',
      body: target
          ? '${p.fullName} aktif yapılacak. Onaylıyor musunuz?'
          : '${p.fullName} pasif yapılacak. Onaylıyor musunuz?',
    );
    if (!ok) return;
    try {
      await api.setPersonActive(p.id, target);
      if (!mounted) return;
      showAppSnackBar(context, 'Durum güncellendi.');
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  String _locationLine(BuildContext context, Person p) {
    final refData = context.read<RefData>();
    return refData.personLocationLabel(p);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    final theme = Theme.of(context);
    return AsyncView<Person>(
      key: ValueKey('person-${widget.personId}-$_refreshTick'),
      load: _load,
      builder: (context, p, reload) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kişi Detayı'),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(p),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(s16),
              children: [
                // Üst kart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(s16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.fullName,
                                  style: theme.textTheme.headlineSmall),
                              const SizedBox(height: s4),
                              Text(
                                _locationLine(context, p),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: kTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge.activity(p.isActive),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: s16),
                // Durum kartı
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(s16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Durum',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: s4),
                              Text(
                                p.isActive
                                    ? 'Bu kişi aktif olarak görünüyor.'
                                    : 'Bu kişi pasif olarak işaretlendi.',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: kTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 1.1,
                          child: Switch(
                            value: p.isActive,
                            activeThumbColor: Colors.white,
                            activeTrackColor: kSuccess,
                            onChanged: isAdmin
                                ? (_) => _toggleActive(p, reload)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: s16),
                // Bilgi listesi
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                            label: 'TC Kimlik No', value: p.tcNo),
                        _InfoRow(
                          label: 'Doğum Tarihi',
                          value: Formats.dateFromApi(p.birthDate),
                        ),
                        _InfoRow(
                          label: 'Telefon',
                          value: Formats.phone(p.phone),
                        ),
                        _InfoRow(
                            label: 'E-posta',
                            value: p.email ?? Str.bos),
                        _InfoRow(
                            label: 'Meslek',
                            value: p.profession ?? Str.bos),
                        _InfoRow(
                          label: 'Birim Türü',
                          value: Str.unitTypeLabel(p.unitType),
                        ),
                        _InfoRow(
                          label: 'Kayıt Tarihi',
                          value: Formats.dateFromApi(p.createdAt),
                          last: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                theme.textTheme.bodySmall?.copyWith(color: kTextSecondary),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
