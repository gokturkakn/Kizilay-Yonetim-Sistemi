import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'training_form_screen.dart';

/// E-43 · Eğitimler Listesi — docs/UX-V2.md §6.2.
class TrainingListScreen extends StatefulWidget {
  const TrainingListScreen({super.key});

  @override
  State<TrainingListScreen> createState() => _TrainingListScreenState();
}

class _TrainingListScreenState extends State<TrainingListScreen> {
  bool _loading = true;
  Object? _error;
  List<TrainingRecord> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.api2.trainings(limit: 200);
      if (!mounted) return;
      setState(() {
        _items = page.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openForm([TrainingRecord? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TrainingFormScreen(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(TrainingRecord t) async {
    final api = context.api2;
    if (!await confirmDelete(context, 'Eğitim kaydı silinsin mi?')) return;
    try {
      await api.deleteTraining(t.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eğitimler')),
      body: AsyncListBody<TrainingRecord>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.school_outlined,
        emptyMessage: S2.bosEgitim,
        emptySubMessage: S2.bosListeAlt,
        header: InfoBlockHeader(blockKey: 'saha.egitimler', api: context.api2),
        itemBuilder: (context, t) => RecordCard(
          title: t.topicName ?? 'Eğitim',
          trailingText: Formats.dateFromApi(t.trainingDate),
          lines: [
            [t.provinceName, t.orgUnitName]
                .whereType<String>()
                .where((e) => e.isNotEmpty)
                .join(' · '),
            '${t.trainer ?? ''} · ${Formats.number(t.participantCount)} '
                'katılımcı · ${Formats.hours(t.durationHours)} saat',
          ],
          footer: Padding(
            padding: const EdgeInsets.only(top: s8),
            child: Wrap(
              spacing: s8,
              children: [
                if (t.categoryName != null)
                  Chip(
                    label: Text(t.categoryName!),
                    backgroundColor: kInfoContainer,
                    labelStyle: const TextStyle(color: kInfo, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                if (t.methodName != null)
                  Chip(
                    label: Text(t.methodName!),
                    backgroundColor: kInactiveContainer,
                    labelStyle:
                        const TextStyle(color: kInactive, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          onTap: () => _openForm(t),
          actions: context.isAdmin
              ? const [PopupMenuItem(value: 'delete', child: Text('Sil'))]
              : null,
          onAction: (v) {
            if (v == 'delete') _delete(t);
          },
        ),
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Eğitim',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Eğitim')),
    );
  }
}
