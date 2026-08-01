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
import 'assignment_form_screen.dart';

/// Görev Atamaları — UX §3.16. Tüm roller okuyabilir.
class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() =>
      _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  String? _status; // null = Tümü (varsayılan)
  int _refreshTick = 0;

  Future<List<Assignment>> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    final list = await api.assignments(status: _status);
    list.sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
    await refData.primeForAssignments(list);
    return list;
  }

  Future<void> _openForm({Assignment? assignment}) async {
    final isAdmin = context.read<Session>().isAdmin;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AssignmentFormScreen(
        assignment: assignment,
        readOnly: !isAdmin,
      ),
    ));
    if (saved == true && mounted) setState(() => _refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    final refData = context.read<RefData>();
    final theme = Theme.of(context);

    Widget chip(String label, String? value) {
      final selected = _status == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? kPrimary : kTextPrimary,
        ),
        onSelected: (_) => setState(() => _status = value),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Görev Atamaları')),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: s12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: s16),
            child: Row(
              children: [
                chip(Str.tumu, null),
                const SizedBox(width: s8),
                chip(Str.atandi, 'atandi'),
                const SizedBox(width: s8),
                chip(Str.devam, 'devam'),
                const SizedBox(width: s8),
                chip(Str.tamamlandi, 'tamamlandi'),
              ],
            ),
          ),
          const SizedBox(height: s4),
          Expanded(
            child: AsyncView<List<Assignment>>(
              key: ValueKey('assignments-$_status-$_refreshTick'),
              load: _load,
              builder: (context, assignments, reload) {
                if (assignments.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    message: 'Henüz görev ataması yok.',
                    subMessage: isAdmin
                        ? 'Yeni atama için + butonuna dokunun.'
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(s16, s4, s16, 88),
                    itemCount: assignments.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: s8),
                    itemBuilder: (context, i) {
                      final a = assignments[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(r12),
                          onTap: () => _openForm(assignment: a),
                          child: Padding(
                            padding: const EdgeInsets.all(s16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: theme
                                            .textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: s8),
                                    StatusBadge.assignment(a.status),
                                  ],
                                ),
                                const SizedBox(height: s4),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 16,
                                        color: kTextSecondary),
                                    const SizedBox(width: s4),
                                    Expanded(
                                      child: Text(
                                        refData
                                            .assignmentPersonName(a),
                                        style: theme
                                            .textTheme.bodyMedium
                                            ?.copyWith(
                                                color:
                                                    kTextSecondary),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: s4),
                                Text(
                                  a.description == null ||
                                          a.description!.isEmpty
                                      ? Formats.dateFromApi(
                                          a.assignedDate)
                                      : '${Formats.dateFromApi(a.assignedDate)} · ${a.description}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                          color: kTextSecondary),
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
            ),
          ),
        ],
      ),
    );
  }
}
