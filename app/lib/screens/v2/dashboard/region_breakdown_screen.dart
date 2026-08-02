import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/status.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../shared.dart';
import 'dashboard_filters.dart';
import 'province_breakdown_screen.dart';

/// E-11 · Bölge Kırılımı — docs/UX-V2.md §6.4.
class RegionBreakdownScreen extends StatefulWidget {
  const RegionBreakdownScreen({super.key, required this.filters});

  final DashboardFilters filters;

  @override
  State<RegionBreakdownScreen> createState() => _RegionBreakdownScreenState();
}

class _RegionBreakdownScreenState extends State<RegionBreakdownScreen> {
  bool _loading = true;
  Object? _error;
  List<StatusBreakdown> _rows = const [];

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
      final summary = await context.api2.orgUnitSummary();
      if (!mounted) return;
      setState(() {
        _rows = summary.byRegion;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bölge Kırılımı')),
      body: AsyncListBody<StatusBreakdown>(
        loading: _loading,
        error: _error,
        items: _rows,
        onRetry: _load,
        emptyMessage: S2.dashVeriYok,
        emptyIcon: Icons.map_outlined,
        itemBuilder: (context, row) => Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(r12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProvinceBreakdownScreen(
                filters: widget.filters.copyWith(
                    regionIds: row.id == null ? const [] : [row.id!]),
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.all(s16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: s8),
                        _StatusCounts(
                            aktif: row.aktif,
                            pasif: row.pasif,
                            teskilatYok: row.teskilatYok),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kTextSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `{a} Aktif · {p} Pasif · {t} Teşkilat Yok` — renkli ikon + sayı üçlüsü.
class _StatusCounts extends StatelessWidget {
  const _StatusCounts({
    required this.aktif,
    required this.pasif,
    required this.teskilatYok,
  });

  final int aktif;
  final int pasif;
  final int teskilatYok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(OrgStatus s, int n) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 14, color: s.foreground),
            const SizedBox(width: s4),
            Text('${Formats.number(n)} ${s.label}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: kTextSecondary)),
          ],
        );
    return Wrap(
      spacing: s12,
      runSpacing: s4,
      children: [
        item(OrgStatus.aktif, aktif),
        item(OrgStatus.pasif, pasif),
        item(OrgStatus.teskilatYok, teskilatYok),
      ],
    );
  }
}
