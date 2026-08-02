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
import 'meeting_form_screen_v2.dart';

/// E-48 · Toplantılar Listesi — docs/UX-V2.md §6.2.
class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  bool _loading = true;
  Object? _error;
  List<MeetingV2> _items = const [];

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
      final page = await context.api2.meetings(limit: 200);
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

  Future<void> _openForm([MeetingV2? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MeetingFormScreenV2(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(MeetingV2 m) async {
    final api = context.api2;
    if (!await confirmDelete(context, S2.dlgToplantiSil)) return;
    try {
      await api.deleteMeeting(m.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toplantılar')),
      body: AsyncListBody<MeetingV2>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.meeting_room_outlined,
        emptyMessage: S2.bosToplanti,
        emptySubMessage: S2.bosListeAlt,
        header: InfoBlockHeader(
            blockKey: 'saha.toplantilar', api: context.api2),
        itemBuilder: (context, m) {
          final online = m.isOnline;
          return RecordCard(
            title: m.meetingTypeName ?? 'Toplantı',
            trailingText: Formats.dateFromApi(m.meetingDate),
            lines: [
              online
                  ? '${m.methodName ?? 'Çevrim İçi'} · ${m.platform ?? ''}'
                  : '${m.methodName ?? 'Yüz Yüze'} · ${m.location ?? ''}',
              m.orgUnitName ?? '',
              if (m.participantCount != null)
                '${Formats.number(m.participantCount)} katılımcı',
              if ((m.agenda ?? '').isNotEmpty) 'Gündem: ${m.agenda}',
            ],
            onTap: () => _openForm(m),
            actions: context.isAdmin
                ? const [PopupMenuItem(value: 'delete', child: Text('Sil'))]
                : null,
            onAction: (v) {
              if (v == 'delete') _delete(m);
            },
          );
        },
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Toplantı',
              onPressed: _openForm,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Toplantı'),
            ),
    );
  }
}

/// Toplantı kartındaki yöntem çipi ikonu (§6.2 E-48).
IconData meetingMethodIcon(bool online) =>
    online ? Icons.videocam_outlined : Icons.place_outlined;

/// Toplantı yönteminin renkli çipi.
Widget meetingMethodChip(BuildContext context, MeetingV2 m) {
  final online = m.isOnline;
  return Chip(
    avatar: Icon(meetingMethodIcon(online), size: 16, color: kTextSecondary),
    label: Text(online ? (m.platform ?? '') : (m.location ?? '')),
    backgroundColor: kInactiveContainer,
  );
}
