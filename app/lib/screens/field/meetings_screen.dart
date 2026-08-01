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
import 'meeting_form_screen.dart';

/// Yönetsel Faaliyetler — UX §3.14: Kurul / Komisyon toplantıları sekmeleri.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<(List<Meeting>, Body?)> _load(bool kurulTab) async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    final kurul = await refData.kurulBody();
    List<Meeting> meetings;
    if (kurulTab) {
      meetings = kurul == null
          ? <Meeting>[]
          : await api.meetings(bodyId: kurul.id);
    } else {
      final all = await api.meetings();
      meetings = all
          .where((m) => kurul == null || m.bodyId != kurul.id)
          .toList();
    }
    meetings.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
    return (meetings, kurul);
  }

  Future<void> _openForm({Meeting? meeting, required bool kurulTab}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          MeetingFormScreen(meeting: meeting, isKurul: kurulTab),
    ));
    if (saved == true && mounted) setState(() => _refreshTick++);
  }

  Future<void> _delete(Meeting m, Future<void> Function() reload) async {
    final api = context.read<Api>();
    final ok = await showConfirmDialog(
      context,
      title: 'Toplantı kaydı silinsin mi?',
      body: 'Bu işlem geri alınamaz.',
      confirmText: Str.sil,
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteMeeting(m.id);
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  Widget _buildList(bool kurulTab) {
    final isAdmin = context.read<Session>().isAdmin;
    final refData = context.read<RefData>();
    final theme = Theme.of(context);
    return AsyncView<(List<Meeting>, Body?)>(
      key: ValueKey('meetings-$kurulTab-$_refreshTick'),
      load: () => _load(kurulTab),
      builder: (context, data, reload) {
        final (meetings, _) = data;
        if (meetings.isEmpty) {
          return EmptyState(
            icon: Icons.meeting_room_outlined,
            message: kurulTab
                ? 'Henüz kurul toplantısı kaydı yok.'
                : 'Henüz komisyon toplantısı kaydı yok.',
            subMessage: 'İlk kaydı eklemek için + butonuna dokunun.',
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(s16, s16, s16, 88),
            itemCount: meetings.length,
            separatorBuilder: (_, _) => const SizedBox(height: s8),
            itemBuilder: (context, i) {
              final m = meetings[i];
              final title = kurulTab
                  ? 'Koordinasyon Kurulu'
                  : (m.bodyName ??
                      refData.bodyNameSync(m.bodyId) ??
                      '—');
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(r12),
                  onTap: () =>
                      _openForm(meeting: m, kurulTab: kurulTab),
                  child: Padding(
                    padding: const EdgeInsets.all(s16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style:
                                          theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: s8),
                                  Text(
                                    Formats.dateFromApi(m.meetingDate),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: kTextSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: s4),
                              Text(
                                'Karar: ${m.decision}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sonuç: ${m.outcome}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: kTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (isAdmin)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: kTextSecondary),
                            onSelected: (v) {
                              if (v == 'delete') _delete(m, reload);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(Str.sil,
                                    style: TextStyle(color: kError)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetsel Faaliyetler'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kurul Toplantıları'),
            Tab(text: 'Komisyon Toplantıları'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _openForm(kurulTab: _tabController.index == 0),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(true),
          _buildList(false),
        ],
      ),
    );
  }
}
