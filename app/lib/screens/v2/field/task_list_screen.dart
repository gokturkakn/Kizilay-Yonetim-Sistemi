import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'task_form_screen.dart';

/// E-41 · Görevler Listesi — docs/UX-V2.md §6.2.
class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _loading = true;
  Object? _error;
  List<TaskRecord> _items = const [];

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
      final page = await context.api2.tasks(limit: 200);
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

  Future<void> _openForm([TaskRecord? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TaskFormScreen(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(TaskRecord t) async {
    final api = context.api2;
    if (!await confirmDelete(context, S2.dlgGorevSil)) return;
    try {
      await api.deleteTask(t.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      body: AsyncListBody<TaskRecord>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.assignment_outlined,
        emptyMessage: S2.bosGorev,
        emptySubMessage: S2.bosListeAlt,
        header: InfoBlockHeader(blockKey: 'saha.gorevler', api: context.api2),
        itemBuilder: (context, t) => RecordCard(
          title: t.taskTypeName ?? 'Görev',
          trailingText: Formats.dateFromApi(t.taskDate),
          lines: [
            t.subTaskName ?? '',
            [t.provinceName, t.districtName]
                .whereType<String>()
                .where((e) => e.isNotEmpty)
                .join(' / '),
            '${Formats.number(t.volunteerCount)} gönüllü · '
                '${Formats.number(t.beneficiaryCount)} yararlanıcı · '
                '${Formats.hours(t.durationHours)} saat',
            if (t.attachmentCount > 0) '${t.attachmentCount} ek',
          ],
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
              tooltip: 'Yeni Görev',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Görev')),
    );
  }
}
