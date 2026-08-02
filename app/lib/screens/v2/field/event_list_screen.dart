import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'event_form_screen.dart';

/// E-45 · Etkinlikler Listesi — docs/UX-V2.md §6.2.
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  bool _loading = true;
  Object? _error;
  List<EventRecord> _items = const [];

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
      final page = await context.api2.events(limit: 200);
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

  Future<void> _openForm([EventRecord? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EventFormScreen(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(EventRecord e) async {
    final api = context.api2;
    if (!await confirmDelete(context, 'Etkinlik kaydı silinsin mi?')) return;
    try {
      await api.deleteEvent(e.id);
      _load();
    } catch (err) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlikler')),
      body: AsyncListBody<EventRecord>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.celebration_outlined,
        emptyMessage: S2.bosEtkinlik,
        emptySubMessage: S2.bosListeAlt,
        header:
            InfoBlockHeader(blockKey: 'saha.etkinlikler', api: context.api2),
        itemBuilder: (context, e) => RecordCard(
          title: e.calendarEventName ?? 'Etkinlik',
          trailingText: Formats.dateFromApi(e.eventDate),
          lines: [
            e.eventTypeName ?? '',
            [e.provinceName, e.orgUnitName]
                .whereType<String>()
                .where((v) => v.isNotEmpty)
                .join(' · '),
            '${Formats.number(e.participantCount)} katılımcı · '
                '${Formats.number(e.volunteerCount)} gönüllü · '
                '${Formats.number(e.beneficiaryCount)} yararlanıcı',
          ],
          onTap: () => _openForm(e),
          actions: context.isAdmin
              ? const [PopupMenuItem(value: 'delete', child: Text('Sil'))]
              : null,
          onAction: (v) {
            if (v == 'delete') _delete(e);
          },
        ),
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Etkinlik',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Etkinlik')),
    );
  }
}
