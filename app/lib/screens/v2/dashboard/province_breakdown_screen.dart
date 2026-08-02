import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/status.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/status_widgets.dart';
import '../org/org_unit_detail_screen.dart';
import '../shared.dart';
import 'dashboard_filters.dart';

enum ProvinceSort { plaka, ad, teskilatYok }

/// E-12 · İl Kırılımı — docs/UX-V2.md §6.4.
class ProvinceBreakdownScreen extends StatefulWidget {
  const ProvinceBreakdownScreen({
    super.key,
    required this.filters,
    this.initialStatus,
  });

  final DashboardFilters filters;
  final OrgStatus? initialStatus;

  @override
  State<ProvinceBreakdownScreen> createState() =>
      _ProvinceBreakdownScreenState();
}

class _ProvinceBreakdownScreenState extends State<ProvinceBreakdownScreen> {
  bool _loading = true;
  Object? _error;
  List<ProvinceBreakdown> _rows = const [];
  late StatusFilter _status =
      StatusFilter(value: widget.initialStatus);
  ProvinceSort _sort = ProvinceSort.plaka;

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
    final api = context.api2;
    final (from, to) = widget.filters.rangePreset.resolve();
    try {
      final data = await api.dashboardProvinces(
        regionId: widget.filters.regionIdForSummary,
        from: widget.filters.from ?? from,
        to: widget.filters.to ?? to,
      );
      if (!mounted) return;
      setState(() {
        _rows = data ?? const [];
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

  List<ProvinceBreakdown> get _visible {
    final list = _rows.where((p) {
      switch (_status.value) {
        case OrgStatus.aktif:
          return p.aktif > 0;
        case OrgStatus.pasif:
          return p.pasif > 0;
        case OrgStatus.teskilatYok:
          return p.teskilatYok > 0;
        case null:
          return true;
      }
    }).toList();
    switch (_sort) {
      case ProvinceSort.plaka:
        list.sort((a, b) => a.code.compareTo(b.code));
      case ProvinceSort.ad:
        list.sort((a, b) => a.provinceName.compareTo(b.provinceName));
      case ProvinceSort.teskilatYok:
        list.sort((a, b) => b.teskilatYok.compareTo(a.teskilatYok));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('İl Kırılımı'),
        actions: [
          PopupMenuButton<ProvinceSort>(
            tooltip: S2.sirala,
            icon: const Icon(Icons.swap_vert),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: ProvinceSort.plaka, child: Text('Plaka')),
              PopupMenuItem(value: ProvinceSort.ad, child: Text('İl Adı')),
              PopupMenuItem(
                  value: ProvinceSort.teskilatYok, child: Text('Teşkilat Yok')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: s8),
          StatusFilterChips(
            filter: _status,
            onChanged: (s) => setState(() => _status = _status.select(s)),
          ),
          const SizedBox(height: s8),
          Expanded(
            child: AsyncListBody<ProvinceBreakdown>(
              loading: _loading,
              error: _error,
              items: rows,
              onRetry: _load,
              emptyMessage: S2.dashVeriYok,
              emptyIcon: Icons.location_city_outlined,
              itemBuilder: (context, p) => Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(r12),
                  onTap: () => _openProvinceUnit(p),
                  child: Padding(
                    padding: const EdgeInsets.all(s16),
                    child: Row(
                      children: [
                        // Plaka rozeti (v1 §3.6 deseni).
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kInactiveContainer,
                            borderRadius: BorderRadius.circular(r8),
                          ),
                          child: Text(
                            p.code == 0
                                ? '—'
                                : p.code.toString().padLeft(2, '0'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kTextSecondary),
                          ),
                        ),
                        const SizedBox(width: s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.provinceName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: s4),
                              Wrap(
                                spacing: s12,
                                children: [
                                  for (final e in [
                                    (OrgStatus.aktif, p.aktif),
                                    (OrgStatus.pasif, p.pasif),
                                    (OrgStatus.teskilatYok, p.teskilatYok),
                                  ])
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(e.$1.icon,
                                            size: 14, color: e.$1.foreground),
                                        const SizedBox(width: s4),
                                        Text(
                                          '${Formats.number(e.$2)} ${e.$1.label}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: kTextSecondary),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        OrgStatusBadge(
                          status: p.aktif > 0
                              ? OrgStatus.aktif
                              : (p.teskilatYok > 0
                                  ? OrgStatus.teskilatYok
                                  : OrgStatus.pasif),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProvinceUnit(ProvinceBreakdown p) async {
    try {
      final page = await context.api2.orgUnits(
          type: OrgUnitType.ilBaskanligi, provinceId: p.provinceId, limit: 1);
      if (!mounted || page.data.isEmpty) return;
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrgUnitDetailScreen(unitId: page.data.first.id),
      ));
    } catch (_) {
      // birim bulunamazsa satır dokunuşu yok sayılır
    }
  }
}
