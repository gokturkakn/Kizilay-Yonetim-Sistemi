import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';

/// Dashboard filtre durumu — docs/UX-V2.md §5.5.
///
/// Filtre kartların içinde değil, hepsinin üstünde tek yerdedir; bir filtre
/// değişince **tüm** bölümler yeniden çizilir.
class DashboardFilters {
  const DashboardFilters({
    this.regionIds = const [],
    this.provinceIds = const [],
    this.districtId,
    this.from,
    this.to,
    this.activityType,
    this.rangePreset = DateRangePreset.buYil,
  });

  final List<int> regionIds;
  final List<int> provinceIds;
  final int? districtId;
  final String? from;
  final String? to;

  /// `gorev | egitim | etkinlik | toplanti` — `/dashboard/summary` bunu alır.
  final String? activityType;
  final DateRangePreset rangePreset;

  /// Uç tek değer aldığından **yalnız ilk seçili** bölge/il gönderilir (N-5).
  int? get regionIdForSummary => regionIds.isEmpty ? null : regionIds.first;
  int? get provinceIdForSummary =>
      provinceIds.isEmpty ? null : provinceIds.first;

  bool get hasMultiSelection => regionIds.length > 1 || provinceIds.length > 1;

  bool get isEmpty =>
      regionIds.isEmpty &&
      provinceIds.isEmpty &&
      districtId == null &&
      activityType == null &&
      rangePreset == DateRangePreset.buYil;

  int get activeCount =>
      (regionIds.isEmpty ? 0 : 1) +
      (provinceIds.isEmpty ? 0 : 1) +
      (districtId == null ? 0 : 1) +
      (activityType == null ? 0 : 1) +
      (rangePreset == DateRangePreset.buYil ? 0 : 1);

  DashboardFilters copyWith({
    List<int>? regionIds,
    List<int>? provinceIds,
    Object? districtId = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? activityType = _sentinel,
    DateRangePreset? rangePreset,
  }) =>
      DashboardFilters(
        regionIds: regionIds ?? this.regionIds,
        provinceIds: provinceIds ?? this.provinceIds,
        districtId:
            districtId == _sentinel ? this.districtId : districtId as int?,
        from: from == _sentinel ? this.from : from as String?,
        to: to == _sentinel ? this.to : to as String?,
        activityType: activityType == _sentinel
            ? this.activityType
            : activityType as String?,
        rangePreset: rangePreset ?? this.rangePreset,
      );

  static const _sentinel = Object();
}

/// Hazır tarih aralığı kısayolları — §4.5.
enum DateRangePreset { buAy, son3Ay, buYil, ozel }

extension DateRangePresetX on DateRangePreset {
  String get label {
    switch (this) {
      case DateRangePreset.buAy:
        return S2.dashBuAy;
      case DateRangePreset.son3Ay:
        return S2.dashSon3Ay;
      case DateRangePreset.buYil:
        return S2.dashBuYil;
      case DateRangePreset.ozel:
        return S2.dashOzel;
    }
  }

  /// (from, to) — `ozel` için kullanıcı seçimi geçerlidir.
  (String?, String?) resolve([DateTime? now]) {
    final n = now ?? DateTime.now();
    switch (this) {
      case DateRangePreset.buAy:
        return (
          Formats.apiDate(DateTime(n.year, n.month, 1)),
          Formats.apiDate(n)
        );
      case DateRangePreset.son3Ay:
        return (
          Formats.apiDate(DateTime(n.year, n.month - 2, 1)),
          Formats.apiDate(n)
        );
      case DateRangePreset.buYil:
        return (Formats.apiDate(DateTime(n.year, 1, 1)), Formats.apiDate(n));
      case DateRangePreset.ozel:
        return (null, null);
    }
  }
}

/// Filtre çubuğu — `>= 840` yapışkan tek satır, `< 600` çip satırı + sheet.
class DashboardFilterBar extends StatelessWidget {
  const DashboardFilterBar({
    super.key,
    required this.filters,
    required this.regions,
    required this.provinces,
    required this.taskTypes,
    required this.onChanged,
  });

  final DashboardFilters filters;
  final List<Region> regions;
  final List<Province> provinces;
  final List<LookupItem> taskTypes;
  final ValueChanged<DashboardFilters> onChanged;

  static const activityTypes = <String, String>{
    'gorev': 'Görev',
    'egitim': 'Eğitim',
    'etkinlik': 'Etkinlik',
    'toplanti': 'Toplantı',
  };

  String? _regionName(int id) {
    for (final r in regions) {
      if (r.id == id) return r.name;
    }
    return null;
  }

  String? _provinceName(int id) {
    for (final p in provinces) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  List<String> get _chipLabels => [
        for (final id in filters.regionIds) _regionName(id) ?? 'Bölge',
        for (final id in filters.provinceIds) _provinceName(id) ?? 'İl',
        if (filters.rangePreset != DateRangePreset.buYil)
          filters.rangePreset.label,
        if (filters.activityType != null)
          activityTypes[filters.activityType!] ?? filters.activityType!,
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _chipLabels;
    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: s16, vertical: s8),
      child: Row(
        children: [
          Expanded(
            child: labels.isEmpty
                ? Text(S2.dashTumKayitlar,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final l in labels) ...[
                          Chip(
                            label: Text(l),
                            onDeleted: () => _removeChip(l),
                            deleteIcon: const Icon(Icons.close, size: 16),
                          ),
                          const SizedBox(width: s8),
                        ],
                      ],
                    ),
                  ),
          ),
          Badge(
            isLabelVisible: filters.activeCount > 0,
            label: Text('${filters.activeCount}'),
            backgroundColor: kPrimary,
            child: IconButton(
              tooltip: S2.filtreler,
              icon: const Icon(Icons.tune),
              onPressed: () => _openSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  void _removeChip(String label) {
    for (final r in regions) {
      if (r.name == label) {
        onChanged(filters.copyWith(
            regionIds: filters.regionIds.where((e) => e != r.id).toList()));
        return;
      }
    }
    for (final p in provinces) {
      if (p.name == label) {
        onChanged(filters.copyWith(
            provinceIds: filters.provinceIds.where((e) => e != p.id).toList()));
        return;
      }
    }
    if (label == filters.rangePreset.label) {
      onChanged(filters.copyWith(rangePreset: DateRangePreset.buYil));
      return;
    }
    onChanged(filters.copyWith(activityType: null));
  }

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<DashboardFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        filters: filters,
        regions: regions,
        provinces: provinces,
        taskTypes: taskTypes,
      ),
    );
    if (result != null) onChanged(result);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.filters,
    required this.regions,
    required this.provinces,
    required this.taskTypes,
  });

  final DashboardFilters filters;
  final List<Region> regions;
  final List<Province> provinces;
  final List<LookupItem> taskTypes;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DashboardFilters _draft = widget.filters;

  List<Province> get _provinceChoices {
    if (_draft.regionIds.isEmpty) return widget.provinces;
    return widget.provinces
        .where((p) => p.regionId != null && _draft.regionIds.contains(p.regionId))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S2.filtreler, style: theme.textTheme.titleLarge),
            const SizedBox(height: s16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bölge', style: theme.textTheme.titleSmall),
                    Wrap(
                      spacing: s8,
                      children: [
                        for (final r in widget.regions)
                          FilterChip(
                            label: Text(r.name),
                            selected: _draft.regionIds.contains(r.id),
                            onSelected: (sel) => setState(() {
                              final ids = List<int>.from(_draft.regionIds);
                              sel ? ids.add(r.id) : ids.remove(r.id);
                              _draft = _draft.copyWith(
                                  regionIds: ids, provinceIds: const []);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: s16),
                    Text('İl', style: theme.textTheme.titleSmall),
                    Wrap(
                      spacing: s8,
                      children: [
                        for (final p in _provinceChoices.take(81))
                          FilterChip(
                            label: Text(p.name),
                            selected: _draft.provinceIds.contains(p.id),
                            onSelected: (sel) => setState(() {
                              final ids = List<int>.from(_draft.provinceIds);
                              sel ? ids.add(p.id) : ids.remove(p.id);
                              _draft = _draft.copyWith(
                                  provinceIds: ids, districtId: null);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: s16),
                    Text('Tarih Aralığı', style: theme.textTheme.titleSmall),
                    Wrap(
                      spacing: s8,
                      children: [
                        for (final preset in DateRangePreset.values)
                          if (preset != DateRangePreset.ozel)
                            ChoiceChip(
                              label: Text(preset.label),
                              selected: _draft.rangePreset == preset,
                              onSelected: (_) => setState(
                                  () => _draft =
                                      _draft.copyWith(rangePreset: preset)),
                            ),
                      ],
                    ),
                    const SizedBox(height: s16),
                    Text('Faaliyet Türü', style: theme.textTheme.titleSmall),
                    Wrap(
                      spacing: s8,
                      children: [
                        for (final e in DashboardFilterBar.activityTypes.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _draft.activityType == e.key,
                            onSelected: (sel) => setState(() => _draft =
                                _draft.copyWith(
                                    activityType: sel ? e.key : null)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: s16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(const DashboardFilters()),
                    child: const Text(Str.temizle),
                  ),
                ),
                const SizedBox(width: s12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text(Str.uygula),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
