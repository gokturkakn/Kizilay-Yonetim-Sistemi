import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'event_list_screen.dart';
import 'meeting_list_screen.dart';
import 'task_list_screen.dart';
import 'training_list_screen.dart';

/// E-40 · Saha Faaliyetleri Ana Ekranı — docs/UX-V2.md §6.2.
class FieldHomeScreenV2 extends StatefulWidget {
  const FieldHomeScreenV2({super.key});

  @override
  State<FieldHomeScreenV2> createState() => _FieldHomeScreenV2State();
}

class _RecentEntry {
  const _RecentEntry(this.icon, this.title, this.date, this.onTap);

  final IconData icon;
  final String title;
  final String date;
  final VoidCallback onTap;
}

class _FieldHomeScreenV2State extends State<FieldHomeScreenV2> {
  List<_RecentEntry> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final api = context.api2;
    final entries = <_RecentEntry>[];
    try {
      final tasks = await api.tasks(limit: 5);
      for (final t in tasks.data) {
        entries.add(_RecentEntry(
          Icons.assignment_outlined,
          t.taskTypeName ?? 'Görev',
          t.taskDate,
          () => _open(const TaskListScreen()),
        ));
      }
      final meetings = await api.meetings(limit: 5);
      for (final m in meetings.data) {
        entries.add(_RecentEntry(
          Icons.meeting_room_outlined,
          m.meetingTypeName ?? 'Toplantı',
          m.meetingDate,
          () => _open(const MeetingListScreen()),
        ));
      }
    } catch (_) {
      // son kayıtlar çekilemezse bölüm gösterilmez
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() => _recent = entries.take(5).toList());
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S2.modulSaha)),
      body: SingleChildScrollView(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.all(s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NavCardGrid(cards: [
                  NavCard(
                    title: 'Görevler',
                    subtitle: 'Saha görev kayıtları',
                    icon: Icons.assignment_outlined,
                    onTap: () => _open(const TaskListScreen()),
                  ),
                  NavCard(
                    title: 'Eğitimler',
                    subtitle: 'Gönüllü ve halka açık eğitimler',
                    icon: Icons.school_outlined,
                    onTap: () => _open(const TrainingListScreen()),
                  ),
                  NavCard(
                    title: 'Etkinlikler',
                    subtitle: 'Takvim etkinlikleri',
                    icon: Icons.celebration_outlined,
                    onTap: () => _open(const EventListScreen()),
                  ),
                  NavCard(
                    title: 'Toplantılar',
                    subtitle: 'Kurul, komisyon ve saha toplantıları',
                    icon: Icons.meeting_room_outlined,
                    onTap: () => _open(const MeetingListScreen()),
                  ),
                ]),
                // Boşsa bölüm hiç gösterilmez.
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: s24),
                  Text('Son Kayıtlar', style: theme.textTheme.titleSmall),
                  const SizedBox(height: s8),
                  Card(
                    child: Column(
                      children: [
                        for (final e in _recent)
                          ListTile(
                            leading: Icon(e.icon, color: kPrimary),
                            title: Text(e.title),
                            trailing: Text(Formats.dateFromApi(e.date),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: kTextSecondary)),
                            onTap: e.onTap,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
