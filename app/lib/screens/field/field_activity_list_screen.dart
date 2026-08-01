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
import 'field_activity_form_screen.dart';

/// Saha Faaliyetleri Listesi — UX §3.12.
class FieldActivityListScreen extends StatefulWidget {
  const FieldActivityListScreen({super.key});

  @override
  State<FieldActivityListScreen> createState() =>
      _FieldActivityListScreenState();
}

class _FieldActivityListScreenState extends State<FieldActivityListScreen> {
  int? _taskAreaId;
  DateTime? _from;
  DateTime? _to;
  int _refreshTick = 0;

  Future<List<FieldActivity>> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    await refData.taskAreas();
    await refData.provinces();
    final result = await api.fieldActivities(
      taskAreaId: _taskAreaId,
      from: _from == null ? null : Formats.apiDate(_from!),
      to: _to == null ? null : Formats.apiDate(_to!),
      limit: 200,
    );
    final list = [...result.data]
      ..sort((a, b) => b.activityDate.compareTo(a.activityDate));
    // İlçe adları için gerekli illeri önbelleğe al.
    final provinceIds = <int>{};
    for (final a in list) {
      if (a.districtId != null &&
          a.districtName == null &&
          a.provinceId != null &&
          refData.districtNameSync(a.districtId!) == null) {
        provinceIds.add(a.provinceId!);
      }
    }
    for (final pid in provinceIds) {
      try {
        await refData.districtsOf(pid);
      } catch (_) {
        // ad çözülmezse yalnız il gösterilir
      }
    }
    return list;
  }

  Future<void> _openForm({FieldActivity? activity}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FieldActivityFormScreen(activity: activity),
    ));
    if (saved == true && mounted) setState(() => _refreshTick++);
  }

  Future<void> _delete(
      FieldActivity a, Future<void> Function() reload) async {
    final api = context.read<Api>();
    final ok = await showConfirmDialog(
      context,
      title: 'Faaliyet silinsin mi?',
      body: 'Bu işlem geri alınamaz.',
      confirmText: Str.sil,
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteFieldActivity(a.id);
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  Future<void> _openFilterSheet() async {
    final refData = context.read<RefData>();
    List<TaskArea> areas = [];
    try {
      areas = (await refData.taskAreas())
          .where((t) => t.isActive)
          .toList();
    } catch (_) {
      // görev alanı listesi yüklenemezse yalnız tarih filtreleri sunulur
    }
    if (!mounted) return;
    var taskAreaId = _taskAreaId;
    var from = _from;
    var to = _to;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickDate(bool isFrom) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: (isFrom ? from : to) ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 1, 12, 31),
              locale: const Locale('tr'),
              confirmText: Str.tamam,
              cancelText: Str.vazgec,
            );
            if (picked != null) {
              setSheetState(() {
                if (isFrom) {
                  from = picked;
                } else {
                  to = picked;
                }
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: s16,
              right: s16,
              top: s16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: taskAreaId,
                  decoration:
                      const InputDecoration(labelText: 'Görev Alanı'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text(Str.tumu)),
                    for (final t in areas)
                      DropdownMenuItem<int?>(
                          value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) =>
                      setSheetState(() => taskAreaId = v),
                ),
                const SizedBox(height: s16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => pickDate(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Başlangıç Tarihi'),
                          child: Text(from == null
                              ? Str.secilmedi
                              : Formats.date(from!)),
                        ),
                      ),
                    ),
                    const SizedBox(width: s12),
                    Expanded(
                      child: InkWell(
                        onTap: () => pickDate(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Bitiş Tarihi'),
                          child: Text(to == null
                              ? Str.secilmedi
                              : Formats.date(to!)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: s24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            taskAreaId = null;
                            from = null;
                            to = null;
                          });
                        },
                        child: const Text(Str.temizle),
                      ),
                    ),
                    const SizedBox(width: s12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(Str.uygula),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _taskAreaId = taskAreaId;
        _from = from;
        _to = to;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    final refData = context.read<RefData>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saha Faaliyetleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: AsyncView<List<FieldActivity>>(
        key: ValueKey(
            'activities-$_taskAreaId-$_from-$_to-$_refreshTick'),
        load: _load,
        builder: (context, activities, reload) {
          if (activities.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_outlined,
              message: 'Henüz saha faaliyeti kaydı yok.',
              subMessage: 'İlk kaydı eklemek için + butonuna dokunun.',
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(s16, s16, s16, 88),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: s8),
              itemBuilder: (context, i) {
                final a = activities[i];
                final areaName = a.taskAreaName ??
                    refData.taskAreaNameSync(a.taskAreaId) ??
                    '—';
                String? location;
                if (a.provinceId != null) {
                  final prov = a.provinceName ??
                      refData.provinceNameSync(a.provinceId!) ??
                      '';
                  final dist = a.districtId == null
                      ? null
                      : (a.districtName ??
                          refData.districtNameSync(a.districtId!));
                  location = dist == null || dist.isEmpty
                      ? prov
                      : '$prov / $dist';
                }
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(r12),
                    onTap: () => _openForm(activity: a),
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
                                        areaName,
                                        style: theme
                                            .textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: s8),
                                    Text(
                                      Formats.dateFromApi(
                                          a.activityDate),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: kTextSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: s4),
                                Text(
                                  '👥 ${a.volunteerCount} gönüllü · '
                                  '${a.beneficiaryCount} yararlanıcı',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: kTextSecondary),
                                ),
                                if (location != null &&
                                    location.isNotEmpty) ...[
                                  const SizedBox(height: s4),
                                  Text(
                                    location,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            color: kTextSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isAdmin)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: kTextSecondary),
                              onSelected: (v) {
                                if (v == 'delete') _delete(a, reload);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(Str.sil,
                                      style:
                                          TextStyle(color: kError)),
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
      ),
    );
  }
}
