import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/formatters.dart';
import '../../core/strings.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Değişiklik Günlüğü — UX §3.19. Sonsuz kaydırma + filtre bottom sheet.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  static const _limit = 50;

  // Kayıt Türü etiketi → API entity değeri.
  static const _entityOptions = <String?, String>{
    null: Str.tumu,
    'persons': 'Kişiler',
    'memberships': 'Üyelikler',
    'field_activities': 'Saha Faaliyetleri',
    'meetings': 'Toplantılar',
    'assignments': 'Atamalar',
  };

  // Eylem çevirileri — UX §3.19.
  static const _actionLabels = <String, String>{
    'create': 'Ekleme',
    'update': 'Güncelleme',
    'delete': 'Silme',
    'active_toggle': 'Durum değişikliği',
  };

  final _scrollController = ScrollController();

  String? _entity;
  DateTime? _from;
  DateTime? _to;

  final List<AuditLog> _logs = [];
  final Set<int> _expanded = {};
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _logs.clear();
      _expanded.clear();
      _page = 1;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    final api = context.read<Api>();
    try {
      final result = await api.auditLogs(
        entity: _entity,
        from: _from == null ? null : Formats.apiDate(_from!),
        to: _to == null ? null : Formats.apiDate(_to!),
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _logs.addAll(result.data);
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _logs.length >= _total) return;
    setState(() {
      _loadingMore = true;
      _page += 1;
    });
    await _fetch();
  }

  String _entityLabel(String entity) {
    // API'nin döndürdüğü entity adlarıyla esnek eşleme.
    final known = _entityOptions[entity];
    if (known != null) return known;
    switch (entity) {
      case 'activities':
      case 'field-activities':
        return 'Saha Faaliyetleri';
      default:
        return entity;
    }
  }

  Future<void> _openFilterSheet() async {
    var entity = _entity;
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
                DropdownButtonFormField<String?>(
                  initialValue: entity,
                  decoration:
                      const InputDecoration(labelText: 'Kayıt Türü'),
                  items: [
                    for (final e in _entityOptions.entries)
                      DropdownMenuItem<String?>(
                          value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setSheetState(() => entity = v),
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
                            entity = null;
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
        _entity = entity;
        _from = from;
        _to = to;
      });
      _reload();
    }
  }

  /// `changes` alanını `alan: eski → yeni` satırlarına çevirir.
  List<String> _changeLines(dynamic changes) {
    if (changes is! Map) {
      return changes == null ? const [] : ['$changes'];
    }
    final lines = <String>[];
    changes.forEach((key, value) {
      if (value is Map && (value.containsKey('old') || value.containsKey('new'))) {
        lines.add('$key: ${value['old'] ?? Str.bos} → '
            '${value['new'] ?? Str.bos}');
      } else {
        lines.add('$key: $value');
      }
    });
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Değişiklik Günlüğü'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(onRetry: _reload);
    }
    if (_logs.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        message: 'Kayıt bulunamadı.',
      );
    }
    final hasMore = _logs.length < _total;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(s16),
        itemCount: _logs.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: s8),
        itemBuilder: (context, i) {
          if (i >= _logs.length) {
            return const Padding(
              padding: EdgeInsets.all(s16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final log = _logs[i];
          final expanded = _expanded.contains(log.id);
          final action = _actionLabels[log.action] ?? log.action;
          final lines = _changeLines(log.changes);
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(r12),
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expanded.remove(log.id);
                  } else {
                    _expanded.add(log.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.changedBy} · $action — '
                      '${_entityLabel(log.entity)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: s4),
                    Text(
                      Formats.dateTimeFromApi(log.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kTextSecondary),
                    ),
                    if (expanded && lines.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: s8),
                        child: Divider(height: 1),
                      ),
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
