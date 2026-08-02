import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-47 · Etkinlik Adı Seçici — docs/UX-V2.md §6.2, §4.3(e).
///
/// Etkinlik adı **yazılmaz, takvimden seçilir** (R6). Klavye açılmaz.
class CalendarEventPickerScreen extends StatefulWidget {
  const CalendarEventPickerScreen({
    super.key,
    required this.year,
    this.categoryCode,
  });

  final int year;
  final String? categoryCode;

  @override
  State<CalendarEventPickerScreen> createState() =>
      _CalendarEventPickerScreenState();
}

class _CalendarEventPickerScreenState extends State<CalendarEventPickerScreen> {
  bool _loading = true;
  List<CalendarEvent> _events = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // `year` **daima** gönderilir (§4.3e).
      final events = await context.api2.calendarEvents(
        category: widget.categoryCode,
        year: widget.year,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = const [];
        _loading = false;
      });
    }
  }

  List<CalendarEvent> get _filtered => _query.trim().isEmpty
      ? _events
      : _events.where((e) => Formats.trContains(e.name, _query)).toList();

  /// Aya göre gruplar; tarihi belirlenmemişler sonda ayrı başlıkta toplanır.
  Map<int?, List<CalendarEvent>> get _grouped {
    final map = <int?, List<CalendarEvent>>{};
    for (final e in _filtered) {
      map.putIfAbsent(e.groupMonth, () => []).add(e);
    }
    return map;
  }

  String _dateLabel(CalendarEvent e) {
    if (e.isFixed && e.month != null && e.day != null) {
      if (e.endMonth != null && e.endDay != null) {
        // `10 – 16 Mayıs` biçimi.
        if (e.endMonth == e.month) {
          return '${e.day} – ${Formats.dayMonth(e.endMonth, e.endDay)}';
        }
        return '${Formats.dayMonth(e.month, e.day)} – '
            '${Formats.dayMonth(e.endMonth, e.endDay)}';
      }
      return Formats.dayMonth(e.month, e.day);
    }
    final resolved = DateTime.tryParse(e.resolvedDate ?? '');
    if (resolved == null) return 'Tarih girilmemiş';
    final end = DateTime.tryParse(e.resolvedEndDate ?? '');
    if (end != null) {
      return '${Formats.dayMonth(resolved.month, resolved.day)} – '
          '${Formats.dayMonth(end.month, end.day)}';
    }
    return Formats.dayMonth(resolved.month, resolved.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _grouped;
    final months = grouped.keys.whereType<int>().toList()..sort();
    final undated = grouped[null] ?? const <CalendarEvent>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik Seç')),
      body: Column(
        children: [
          SearchField(
            hint: 'Etkinlik ara...',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.celebration_outlined,
                        message: _query.trim().isEmpty
                            ? S2.bosTakvim
                            : S2.bosTakvimArama,
                        subMessage:
                            _query.trim().isEmpty ? S2.bosTakvimAlt : null,
                      )
                    : ListView(
                        children: [
                          for (final m in months) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  s16, s16, s16, s8),
                              child: Text(Formats.monthNames[m - 1],
                                  style: theme.textTheme.titleSmall),
                            ),
                            for (final e in grouped[m]!) _row(e),
                          ],
                          if (undated.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  s16, s16, s16, s8),
                              child: Text('Tarihi belirlenmemiş',
                                  style: theme.textTheme.titleSmall),
                            ),
                            for (final e in undated) _row(e),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row(CalendarEvent e) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(e.name, style: theme.textTheme.titleMedium),
      subtitle: Text(_dateLabel(e),
          style: theme.textTheme.bodySmall?.copyWith(color: kTextSecondary)),
      trailing: Chip(
        label: Text(CalendarEvent.categoryLabel(e.category)),
        backgroundColor: kInactiveContainer,
        labelStyle: const TextStyle(fontSize: 11, color: kInactive),
        visualDensity: VisualDensity.compact,
      ),
      // Satır dokunuşu seçer ve geri döner (onay dialoğu yok).
      onTap: () => Navigator.of(context).pop(e),
    );
  }
}
