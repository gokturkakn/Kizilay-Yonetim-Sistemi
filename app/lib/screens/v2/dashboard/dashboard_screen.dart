import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/lookup_cache.dart';
import '../../../core/status.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/charts.dart';
import '../../../widgets/common.dart';
import '../../../widgets/stat_tile.dart';
import '../shared.dart';
import 'dashboard_filters.dart';
import 'province_breakdown_screen.dart';
import 'region_breakdown_screen.dart';
import 'report_center_screen.dart';

/// E-10 · Dashboard — docs/UX-V2.md §5. Giriş sonrası açılan ilk ekran.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardFilters _filters = const DashboardFilters();

  bool _loading = true;
  bool _refreshing = false;
  Object? _error;

  DashboardSummary? _summary;
  OrgUnitSummary? _orgSummary;
  List<Region> _regions = const [];
  List<Province> _provinces = const [];
  List<LookupItem> _taskTypes = const [];
  List<ProvinceBreakdown> _provinceBreakdown = const [];
  List<TimeseriesPoint>? _timeseries;
  String _trendMetric = 'gorev';
  Map<String, int>? _trainingMatrix; // '{categoryId}|{methodId}' → total
  List<LookupItem> _trainingCategories = const [];
  List<LookupItem> _trainingMethods = const [];
  List<ChartDatum> _shipmentsByProduct = const [];
  bool _shipmentBreakdownTooLarge = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    final api = context.api2;
    final cache = context.lookups;
    final (from, to) = _filters.rangePreset.resolve();
    try {
      final results = await Future.wait([
        api.dashboardSummary(
          regionId: _filters.regionIdForSummary,
          provinceId: _filters.provinceIdForSummary,
          districtId: _filters.districtId,
          activityType: _filters.activityType,
          from: _filters.from ?? from,
          to: _filters.to ?? to,
        ),
        api.orgUnitSummary(regionId: _filters.regionIdForSummary),
        cache.regions(),
        cache.provinces(),
      ]);
      if (!mounted) return;
      _summary = results[0] as DashboardSummary;
      _orgSummary = results[1] as OrgUnitSummary;
      _regions = results[2] as List<Region>;
      _provinces = results[3] as List<Province>;

      // Yan yüklemeler — biri düşerse ekran çalışmaya devam eder (§11).
      await Future.wait([
        _loadTaskTypes(cache),
        _loadProvinceBreakdown(api, from, to),
        _loadTimeseries(api, from, to),
        _loadTrainingMatrix(api, cache),
        _loadShipmentBreakdown(api),
      ]);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadTaskTypes(LookupCache cache) async {
    try {
      _taskTypes = await cache.items('gorev_turu');
    } catch (_) {
      _taskTypes = const [];
    }
  }

  /// N-1 — `GET /dashboard/provinces`; uç yoksa istemcide sayılır.
  Future<void> _loadProvinceBreakdown(
      ApiV2 api, String? from, String? to) async {
    try {
      final data = await api.dashboardProvinces(
          regionId: _filters.regionIdForSummary, from: from, to: to);
      if (data != null) {
        _provinceBreakdown = data;
        return;
      }
      final page = await api.orgUnits(
          type: OrgUnitType.ilBaskanligi, limit: 1000);
      _provinceBreakdown = [
        for (final u in page.data)
          ProvinceBreakdown(
            provinceId: u.provinceId ?? 0,
            provinceName: u.provinceName ?? u.name,
            code: 0,
            aktif: u.status == 'aktif' ? 1 : 0,
            pasif: u.status == 'pasif' ? 1 : 0,
            teskilatYok: u.status == 'teskilat_yok' ? 1 : 0,
            regionName: u.regionName,
          ),
      ];
    } catch (_) {
      _provinceBreakdown = const [];
    }
  }

  /// N-2 — trend kartı; uç 404 dönerse kart **hiç render edilmez**.
  Future<void> _loadTimeseries(ApiV2 api, String? from, String? to) async {
    try {
      _timeseries = await api.dashboardTimeseries(
        metric: _trendMetric,
        interval: 'month',
        from: from,
        to: to,
        regionId: _filters.regionIdForSummary,
        provinceId: _filters.provinceIdForSummary,
      );
    } catch (_) {
      _timeseries = null;
    }
  }

  /// N-3 — kategori × yöntem kesişimi: 4 çağrının `total` değeri okunur.
  Future<void> _loadTrainingMatrix(ApiV2 api, LookupCache cache) async {
    try {
      _trainingCategories = await cache.items('egitim_kategorisi');
      _trainingMethods = await cache.items('egitim_yontemi');
      final cells = _trainingCategories.length * _trainingMethods.length;
      if (cells == 0 || cells > 6) {
        _trainingMatrix = null; // 6'yı aşarsa bölüm gizlenir
        return;
      }
      final matrix = <String, int>{};
      for (final c in _trainingCategories) {
        for (final m in _trainingMethods) {
          final page = await api.trainings(
              categoryId: c.id, methodId: m.id, limit: 1);
          matrix['${c.id}|${m.id}'] = page.total;
        }
      }
      _trainingMatrix = matrix;
    } catch (_) {
      _trainingMatrix = null;
    }
  }

  /// N-4 — ürün kırılımı istemcide gruplanır; `total > 1000` ise kart gizlenir.
  Future<void> _loadShipmentBreakdown(ApiV2 api) async {
    try {
      final page = await api.shipments(limit: 1000);
      if (page.total > 1000) {
        _shipmentBreakdownTooLarge = true;
        _shipmentsByProduct = const [];
        return;
      }
      _shipmentBreakdownTooLarge = false;
      final grouped = <String, int>{};
      for (final s in page.data) {
        final name = s.productName ?? '—';
        grouped[name] = (grouped[name] ?? 0) + s.quantity;
      }
      final entries = grouped.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = entries.take(8).toList();
      final rest = entries.skip(8).fold<int>(0, (a, e) => a + e.value);
      _shipmentsByProduct = [
        for (final e in top)
          ChartDatum(label: e.key, value: e.value.toDouble(), color: kChart1),
        if (rest > 0)
          ChartDatum(
              label: 'Diğer', value: rest.toDouble(), color: kChartOther),
      ];
    } catch (_) {
      _shipmentsByProduct = const [];
    }
  }

  void _applyFilters(DashboardFilters f) {
    setState(() => _filters = f);
    _loadAll(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S2.dashBaslik),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAll(refresh: true),
          ),
          IconButton(
            tooltip: S2.raporDisaAktar,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ReportCenterScreen(),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(
                  onRetry: _loadAll, message: v2ErrorMessage(_error!))
              : Column(
                  children: [
                    DashboardFilterBar(
                      filters: _filters,
                      regions: _regions,
                      provinces: _provinces,
                      taskTypes: _taskTypes,
                      onChanged: _applyFilters,
                    ),
                    if (_refreshing)
                      const LinearProgressIndicator(minHeight: 2),
                    const Divider(height: 1),
                    Expanded(
                      child: Opacity(
                        // §5.5 — yenilemede iskelet gösterilmez; önceki çizim
                        // %40 opaklıkla yerinde tutulur, düzen zıplamaz.
                        opacity: _refreshing ? 0.4 : 1,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(s16),
                          child: ContentWidth(child: _buildSections(context)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSections(BuildContext context) {
    final summary = _summary!;
    final layout = layoutOf(context);
    final children = <Widget>[];

    // §5.5 — uygulanmayan filtreler kullanıcıya açıkça söylenir.
    final unapplied = _filters.districtId != null || _filters.activityType != null;
    if (unapplied || _filters.hasMultiSelection) {
      children.add(Container(
        margin: const EdgeInsets.only(bottom: s16),
        padding: const EdgeInsets.all(s12),
        decoration: BoxDecoration(
          color: kWarningContainer,
          borderRadius: BorderRadius.circular(r8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: kWarning),
            const SizedBox(width: s8),
            Expanded(
              child: Text(
                [
                  if (unapplied) S2.dashFiltreUygulanmadi,
                  if (_filters.hasMultiSelection) S2.dashTekBolge,
                ].join(' '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ));
    }

    // ---- Bölüm 1: Teşkilatlanma Durumu (§5.2) ----
    final total = summary.orgTotal;
    int pct(int n) => total == 0 ? 0 : ((n / total) * 100).round();
    children.addAll([
      const SectionHeader(title: S2.dashTeskilatlanmaDurumu),
      StatTileGrid(tiles: [
        StatTile(
          label: S2.aktif,
          value: summary.orgAktif,
          subtitle: S2.dashToplamOran(pct(summary.orgAktif)),
          accentColor: kSuccess,
          icon: Icons.check_circle_outline,
          onTap: () => _openProvinceBreakdown(OrgStatus.aktif),
        ),
        StatTile(
          label: S2.pasif,
          value: summary.orgPasif,
          subtitle: S2.dashToplamOran(pct(summary.orgPasif)),
          accentColor: kInactive,
          icon: Icons.pause_circle_outline,
          onTap: () => _openProvinceBreakdown(OrgStatus.pasif),
        ),
        StatTile(
          label: S2.teskilatYok,
          value: summary.orgTeskilatYok,
          subtitle: S2.teskilatYokAlt,
          accentColor: kWarning,
          icon: Icons.location_off_outlined,
          onTap: () => _openProvinceBreakdown(OrgStatus.teskilatYok),
        ),
      ]),
      const SizedBox(height: s16),
      ChartCard(
        title: S2.dashDurumDagilimi,
        isEmpty: total == 0,
        tableData: ChartTableData(
          title: S2.dashDurumDagilimi,
          columns: const ['Durum', 'Birim', 'Oran'],
          rows: [
            [S2.aktif, Formats.number(summary.orgAktif), '%${pct(summary.orgAktif)}'],
            [S2.pasif, Formats.number(summary.orgPasif), '%${pct(summary.orgPasif)}'],
            [
              S2.teskilatYok,
              Formats.number(summary.orgTeskilatYok),
              '%${pct(summary.orgTeskilatYok)}'
            ],
          ],
          totalRow: [S2.toplam, Formats.number(total), '%100'],
        ),
        child: DonutChart(
          centerLabel: S2.dashToplamBirim,
          data: [
            ChartDatum(
                label: S2.aktif,
                value: summary.orgAktif.toDouble(),
                color: kSuccess,
                icon: Icons.check_circle_outline),
            ChartDatum(
                label: S2.pasif,
                value: summary.orgPasif.toDouble(),
                color: kInactive,
                icon: Icons.pause_circle_outline),
            ChartDatum(
                label: S2.teskilatYok,
                value: summary.orgTeskilatYok.toDouble(),
                color: kWarning,
                icon: Icons.location_off_outlined),
          ],
          onSliceTap: (i) => _openProvinceBreakdown(OrgStatus.values[i]),
        ),
      ),
    ]);

    // ---- Bölüm 2: Teşkilatlanma Kırılımı (§5.3) ----
    final regionRows = (_orgSummary?.byRegion ?? const <StatusBreakdown>[])
        .toList()
      ..sort((a, b) => b.teskilatYok.compareTo(a.teskilatYok));
    children.addAll([
      const SectionHeader(title: S2.dashTeskilatlanmaKirilimi),
      ChartCard(
        title: S2.dashBolgeBazli,
        subtitle: '${regionRows.length} bölge',
        isEmpty: regionRows.isEmpty,
        tableData: ChartTableData(
          title: S2.dashBolgeBazli,
          columns: const ['Bölge', 'Aktif', 'Pasif', 'Teşkilat Yok', 'Toplam'],
          rows: [
            for (final r in regionRows)
              [
                r.name,
                Formats.number(r.aktif),
                Formats.number(r.pasif),
                Formats.number(r.teskilatYok),
                Formats.number(r.total),
              ],
          ],
        ),
        child: HorizontalStackedBarChart(
          rows: [
            for (final r in regionRows)
              ChartRow(
                label: r.name,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RegionBreakdownScreen(filters: _filters),
                )),
                segments: [
                  ChartDatum(
                      label: S2.aktif,
                      value: r.aktif.toDouble(),
                      color: kSuccess),
                  ChartDatum(
                      label: S2.pasif,
                      value: r.pasif.toDouble(),
                      color: kInactive),
                  ChartDatum(
                      label: S2.teskilatYok,
                      value: r.teskilatYok.toDouble(),
                      color: kWarning),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: s16),
      _buildProvinceChart(context),
    ]);

    // ---- Bölüm 3: Faaliyet Özeti (§5.4) ----
    children.addAll([
      const SectionHeader(title: S2.dashFaaliyetOzeti),
      StatTileGrid(tiles: [
        StatTile(
            label: 'Gönüllü',
            value: summary.totalVolunteers,
            subtitle: 'Faaliyetlere katılan'),
        StatTile(
            label: 'Faaliyet',
            value: summary.tasks.count,
            subtitle: 'Görev kaydı'),
        StatTile(
            label: 'Eğitim',
            value: summary.trainings.count,
            subtitle: 'Düzenlenen eğitim'),
        StatTile(
            label: 'Etkinlik',
            value: summary.events.count,
            subtitle: 'Düzenlenen etkinlik'),
        StatTile(
            label: 'Toplantı',
            value: summary.meetings.count,
            subtitle: 'Yapılan toplantı'),
      ]),
      if (summary.topTaskTypes.isNotEmpty) ...[
        const SizedBox(height: s16),
        _TopTaskTypes(items: summary.topTaskTypes),
      ],
      // N-2 geri düşüşü: veri yoksa kart hiç render edilmez.
      if (_timeseries != null && _timeseries!.isNotEmpty) ...[
        const SizedBox(height: s16),
        _buildTrendCard(),
      ],
    ]);

    // ---- Bölüm 4: Eğitim Dağılımı (§5.4) ----
    if (_trainingMatrix != null) {
      children.addAll([
        const SectionHeader(title: S2.dashEgitimDagilimi),
        _TrainingMatrix(
          categories: _trainingCategories,
          methods: _trainingMethods,
          values: _trainingMatrix!,
        ),
      ]);
    }

    // ---- Bölüm 5: Lojistik (§5.4) ----
    children.addAll([
      const SectionHeader(title: S2.dashLojistik),
      StatTileGrid(tiles: [
        StatTile(
            label: 'Talep',
            value: summary.openRequests,
            subtitle: 'Açık talep'),
        StatTile(
            label: 'Gönderi',
            value: summary.shipmentCount,
            subtitle: 'Yola çıkan'),
        StatTile(
          label: 'Stok',
          value: summary.stockTotal,
          subtitle: 'Toplam ürün adedi',
          warningNote: summary.stockLow > 0
              ? '${summary.stockLow} üründe stok kritik.'
              : null,
        ),
      ]),
      const SizedBox(height: s16),
      if (_shipmentBreakdownTooLarge)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S2.urunKirilimRapor,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ReportCenterScreen(),
                  )),
                  child: const Text(S2.raporMerkezi),
                ),
              ],
            ),
          ),
        )
      else
        ChartCard(
          title: S2.dashUrunBazli,
          isEmpty: _shipmentsByProduct.isEmpty,
          tableData: ChartTableData(
            title: S2.dashUrunBazli,
            columns: const ['Ürün', 'Miktar'],
            rows: [
              for (final d in _shipmentsByProduct)
                [d.label, Formats.number(d.value.round())],
            ],
          ),
          child: HorizontalBarChart(data: _shipmentsByProduct),
        ),
      const SizedBox(height: s48),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in children)
          layout.chartColumns == 1
              ? c
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200), child: c),
      ],
    );
  }

  Widget _buildProvinceChart(BuildContext context) {
    final sorted = List<ProvinceBreakdown>.from(_provinceBreakdown)
      ..sort((a, b) => b.teskilatYok.compareTo(a.teskilatYok));
    final top = sorted.take(10).toList();
    return ChartCard(
      title: S2.dashIlBazli,
      subtitle: 'Teşkilat Yok birim sayısı · ilk 10',
      isEmpty: top.isEmpty,
      tableData: ChartTableData(
        title: S2.dashIlBazli,
        columns: const ['İl', 'Aktif', 'Pasif', 'Teşkilat Yok'],
        rows: [
          for (final p in sorted)
            [
              p.provinceName,
              Formats.number(p.aktif),
              Formats.number(p.pasif),
              Formats.number(p.teskilatYok),
            ],
        ],
      ),
      footer: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _openProvinceBreakdown(null),
          child: Text('${S2.tumunuGor} (${sorted.length} il)'),
        ),
      ),
      // Tek seri → tek renk kWarning; büyüklüğe göre koyulaştırma yasak.
      child: HorizontalBarChart(
        data: [
          for (final p in top)
            ChartDatum(
                label: p.provinceName,
                value: p.teskilatYok.toDouble(),
                color: kWarning),
        ],
        onTap: (i) => _openProvinceBreakdown(OrgStatus.teskilatYok),
      ),
    );
  }

  Widget _buildTrendCard() {
    final points = _timeseries!;
    return ChartCard(
      title: S2.dashAylikTrend,
      isEmpty: points.every((p) => p.value == 0),
      trailing: null,
      tableData: ChartTableData(
        title: S2.dashAylikTrend,
        columns: const ['Dönem', 'Adet'],
        rows: [
          for (final p in points) [p.label, Formats.number(p.value.round())],
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: s12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gorev', label: Text('Faaliyet')),
              ButtonSegment(value: 'egitim', label: Text('Eğitim')),
              ButtonSegment(value: 'etkinlik', label: Text('Etkinlik')),
              ButtonSegment(value: 'toplanti', label: Text('Toplantı')),
            ],
            selected: {_trendMetric},
            showSelectedIcon: false,
            onSelectionChanged: (sel) {
              setState(() => _trendMetric = sel.first);
              _loadAll(refresh: true);
            },
          ),
        ),
      ),
      child: LineChart(
        points: [for (final p in points) p.value],
        labels: [for (final p in points) p.shortMonthLabel],
      ),
    );
  }

  void _openProvinceBreakdown(OrgStatus? status) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProvinceBreakdownScreen(
        filters: _filters,
        initialStatus: status,
      ),
    ));
  }
}

/// `En Çok Yapılan Görev Türleri` — §5.4 (grafik değil, sade liste).
class _TopTaskTypes extends StatelessWidget {
  const _TopTaskTypes({required this.items});

  final List<TopTaskType> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = items.take(5).toList();
    final max = top.fold<int>(0, (a, b) => b.count > a ? b.count : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('En Çok Yapılan Görev Türleri',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: s12),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: s12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                            width: 20,
                            child: Text('${i + 1}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: kTextSecondary))),
                        Expanded(
                            child: Text(top[i].name,
                                style: theme.textTheme.bodyLarge)),
                        Text(Formats.number(top[i].count),
                            style: theme.textTheme.bodyLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ],
                    ),
                    const SizedBox(height: s4),
                    LinearProgressIndicator(
                      value: max == 0 ? 0 : top[i].count / max,
                      minHeight: 4,
                      backgroundColor: kBackground,
                      valueColor: const AlwaysStoppedAnimation(kChart1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `Eğitim Dağılımı (Kategori × Yöntem)` — 2×2 matris **tablosu** (§5.4).
class _TrainingMatrix extends StatelessWidget {
  const _TrainingMatrix({
    required this.categories,
    required this.methods,
    required this.values,
  });

  final List<LookupItem> categories;
  final List<LookupItem> methods;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int cell(int c, int m) => values['$c|$m'] ?? 0;
    int rowTotal(int c) =>
        methods.fold<int>(0, (a, m) => a + cell(c, m.id));
    int colTotal(int m) =>
        categories.fold<int>(0, (a, c) => a + cell(c.id, m));
    final grand =
        categories.fold<int>(0, (a, c) => a + rowTotal(c.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(s16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('')),
              for (final m in methods)
                DataColumn(
                    label: Text(m.name, style: theme.textTheme.titleSmall)),
              DataColumn(
                  label: Text(S2.toplam, style: theme.textTheme.titleSmall)),
            ],
            rows: [
              for (final c in categories)
                DataRow(cells: [
                  DataCell(Text(c.name, style: theme.textTheme.titleSmall)),
                  for (final m in methods)
                    DataCell(Text(Formats.number(cell(c.id, m.id)),
                        style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()]))),
                  DataCell(Text(Formats.number(rowTotal(c.id)),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              DataRow(
                color: const WidgetStatePropertyAll(kBackground),
                cells: [
                  DataCell(Text(S2.toplam,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  for (final m in methods)
                    DataCell(Text(Formats.number(colTotal(m.id)),
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(Formats.number(grand),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
