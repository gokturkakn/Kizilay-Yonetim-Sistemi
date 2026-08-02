import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/status.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/pickers.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../../../widgets/status_widgets.dart';
import '../shared.dart';
import 'assignment_form_screen.dart';
import 'org_home_screen.dart';
import 'org_unit_detail_screen.dart';

/// E-21…E-26 · Teşkilat birimi listeleri — docs/UX-V2.md §6.1.
///
/// Altı alt modül **aynı iskeleti** paylaşır: bilgilendirme metni başlığı +
/// filtre çipleri (3 durum) + birim listesi.
class OrgUnitListScreen extends StatefulWidget {
  const OrgUnitListScreen({super.key, required this.module});

  final OrgModule module;

  @override
  State<OrgUnitListScreen> createState() => _OrgUnitListScreenState();
}

class _OrgUnitListScreenState extends State<OrgUnitListScreen> {
  bool _loading = true;
  Object? _error;
  List<OrgUnit> _units = const [];
  StatusFilter _status = StatusFilter.forOrgUnits();
  String _query = '';
  int? _regionFilter;
  Province? _selectedProvince;
  List<Region> _regions = const [];
  OrgUnit? _selectedUnit;

  @override
  void initState() {
    super.initState();
    if (!widget.module.requiresProvince) _load();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await context.lookups.regions();
      if (!mounted) return;
      setState(() => _regions = regions);
    } catch (_) {
      // bölge filtresi olmadan da liste çalışır
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.api2.orgUnits(
        type: widget.module.unitType,
        regionId: _regionFilter,
        provinceId: _selectedProvince?.id,
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _units = page.data;
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

  List<OrgUnit> get _visible {
    return _units.where((u) {
      if (!_status.matches(u.status)) return false;
      if (_query.trim().isEmpty) return true;
      return Formats.trContains(u.name, _query) ||
          Formats.trContains(u.provinceName ?? '', _query);
    }).toList();
  }

  Future<void> _pickProvince() async {
    final provinces = await context.lookups.provinces();
    if (!mounted) return;
    if (!context.mounted) return;
    final picked = await showOptionPicker(
      context,
      title: 'İl',
      options: [
        for (final p in provinces) FormOption(value: p.id, label: p.name),
      ],
    );
    if (picked == null) return;
    setState(() {
      _selectedProvince = provinces.firstWhere((p) => p.id == picked.value);
    });
    _load();
  }

  Future<void> _openDetail(OrgUnit unit) async {
    if (layoutOf(context).isTwoPane) {
      setState(() => _selectedUnit = unit);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OrgUnitDetailScreen(unitId: unit.id),
    ));
    if (changed == true) _load();
  }

  Future<void> _assign(OrgUnit unit) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AssignmentFormScreen(lockedUnit: unit),
    ));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final needsProvince = module.requiresProvince && _selectedProvince == null;
    final visible = _visible;
    final title = module == OrgModule.ilceBaskanliklari &&
            _selectedProvince != null
        ? '${_selectedProvince!.name} İlçe Başkanlıkları'
        : module.title;

    final list = Column(
      children: [
        InfoBlockHeader(blockKey: module.contentKey, api: context.api2),
        if (!needsProvince) ...[
          if (module != OrgModule.koordinasyonKurulu)
            SearchField(
              hint: module.searchHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          if (_selectedProvince != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: s16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(_selectedProvince!.name),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _selectedProvince = null;
                      _units = const [];
                    });
                  },
                ),
              ),
            ),
          if (_regions.isNotEmpty &&
              (module == OrgModule.ilBaskanliklari ||
                  module == OrgModule.temsilcilikler))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: s16),
              child: DropdownButtonFormField<int?>(
                initialValue: _regionFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Bölge', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tümü')),
                  for (final r in _regions)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) {
                  setState(() => _regionFilter = v);
                  _load();
                },
              ),
            ),
          const SizedBox(height: s8),
          StatusFilterChips(
            filter: _status,
            onChanged: (s) => setState(() => _status = _status.select(s)),
          ),
          StatusSummaryStrip(
            aktif: visible.where((u) => u.status == 'aktif').length,
            pasif: visible.where((u) => u.status == 'pasif').length,
            teskilatYok:
                visible.where((u) => u.status == 'teskilat_yok').length,
          ),
        ],
        Expanded(
          child: needsProvince
              ? EmptyState(
                  icon: Icons.location_city_outlined,
                  message: S2.bosIlceSecilmedi,
                  actionLabel: 'İl Seç',
                  onAction: _pickProvince,
                )
              : AsyncListBody<OrgUnit>(
                  loading: _loading,
                  error: _error,
                  items: visible,
                  onRetry: _load,
                  emptyIcon: Icons.account_tree_outlined,
                  emptyMessage: _query.trim().isNotEmpty
                      ? '"$_query" ile eşleşen kayıt bulunamadı.'
                      : module.emptyMessage,
                  itemBuilder: (context, u) => _OrgUnitCard(
                    unit: u,
                    onTap: () => _openDetail(u),
                    onAssign: context.isAdmin ? () => _assign(u) : null,
                    selected: _selectedUnit?.id == u.id,
                  ),
                ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (module.requiresProvince && _selectedProvince != null)
            IconButton(
              tooltip: 'İl Seç',
              icon: const Icon(Icons.location_city_outlined),
              onPressed: _pickProvince,
            ),
        ],
      ),
      body: TwoPaneLayout(
        list: list,
        detail: _selectedUnit == null
            ? null
            : OrgUnitDetailScreen(
                key: ValueKey(_selectedUnit!.id),
                unitId: _selectedUnit!.id,
                embedded: true,
              ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    if (!context.isAdmin) return null;
    if (widget.module == OrgModule.koordinasyonKurulu) {
      final unit = _units.isEmpty ? null : _units.first;
      if (unit == null) return null;
      return _fab(
        icon: Icons.person_add,
        label: S2.gorevliAta,
        onPressed: () => _assign(unit),
      );
    }
    if (widget.module == OrgModule.temsilcilikler) {
      return _fab(
        icon: Icons.add,
        label: 'Yeni Temsilcilik',
        onPressed: () => _createUnit(OrgUnitType.temsilcilik),
      );
    }
    if (widget.module == OrgModule.komisyonlar) {
      return _fab(
        icon: Icons.add,
        label: 'Yeni Komisyon',
        onPressed: () => _createUnit(OrgUnitType.komisyon),
      );
    }
    return null;
  }

  Widget _fab({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    // §2.2 — `>= 600`'de genişletilmiş FAB.
    if (layoutOf(context).usesBottomBar) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: label,
        child: Icon(icon),
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Future<void> _createUnit(String type) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => OrgUnitFormScreen(type: type),
    ));
    if (saved == true) _load();
  }
}

class _OrgUnitCard extends StatelessWidget {
  const _OrgUnitCard({
    required this.unit,
    required this.onTap,
    this.onAssign,
    this.selected = false,
  });

  final OrgUnit unit;
  final VoidCallback onTap;
  final VoidCallback? onAssign;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGap = unit.status == 'teskilat_yok';
    return Card(
      color: selected ? kPrimaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(r12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: kInactiveContainer,
                child: Icon(
                  unit.type == OrgUnitType.komisyon
                      ? Icons.diversity_3_outlined
                      : Icons.location_city_outlined,
                  color: kTextSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(unit.name,
                              style: theme.textTheme.titleMedium),
                        ),
                        const SizedBox(width: s8),
                        OrgStatusBadge.fromApi(unit.status),
                      ],
                    ),
                    if (unit.locationLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Text(unit.locationLabel,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                      ),
                    // §3.3a — "Teşkilat Yok" bir aksiyon davetidir.
                    if (isGap) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Text(S2.gorevliYok,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                      ),
                      if (onAssign != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                visualDensity: VisualDensity.compact),
                            onPressed: onAssign,
                            child: const Text(S2.gorevliAta),
                          ),
                        ),
                    ] else if (unit.assignmentCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Text('${unit.assignmentCount} görevli',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni birim formu (E-23 komisyon / E-26 temsilcilik).
class OrgUnitFormScreen extends StatefulWidget {
  const OrgUnitFormScreen({super.key, required this.type});

  final String type;

  @override
  State<OrgUnitFormScreen> createState() => _OrgUnitFormScreenState();
}

class _OrgUnitFormScreenState extends State<OrgUnitFormScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  int? _regionId;
  int? _provinceId;
  String _status = 'aktif';
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Ad girin.');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      await context.api2.createOrgUnit({
        'type': widget.type,
        'name': _name.text.trim(),
        'region_id': _regionId,
        'province_id': _provinceId,
        'status': _status,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCommission = widget.type == OrgUnitType.komisyon;
    return Scaffold(
      appBar: AppBar(
        title: Text(isCommission ? 'Yeni Komisyon' : 'Yeni Temsilcilik'),
      ),
      body: SingleChildScrollView(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.all(s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                      labelText: 'Ad', errorText: _nameError, isDense: true),
                ),
                const SizedBox(height: s16),
                if (!isCommission) ...[
                  FutureBuilder(
                    future: context.lookups.regions(),
                    builder: (context, snapshot) {
                      final regions = snapshot.data ?? const <Region>[];
                      return DropdownButtonFormField<int?>(
                        initialValue: _regionId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Bölge', isDense: true),
                        items: [
                          for (final r in regions)
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                        ],
                        onChanged: (v) => setState(() {
                          _regionId = v;
                          _provinceId = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: s16),
                  FutureBuilder(
                    future: context.lookups.provinces(regionId: _regionId),
                    builder: (context, snapshot) {
                      final provinces = snapshot.data ?? const <Province>[];
                      return DropdownButtonFormField<int?>(
                        initialValue: _provinceId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'İl', isDense: true),
                        items: [
                          for (final p in provinces)
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                        ],
                        onChanged: (v) => setState(() => _provinceId = v),
                      );
                    },
                  ),
                  const SizedBox(height: s16),
                ],
                const Text('Durum', style: TextStyle(color: kTextSecondary)),
                const SizedBox(height: s4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'aktif', label: Text(S2.aktif)),
                    ButtonSegment(value: 'pasif', label: Text(S2.pasif)),
                    ButtonSegment(
                        value: 'teskilat_yok', label: Text(S2.teskilatYok)),
                  ],
                  selected: {_status},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _status = s.first),
                ),
                const SizedBox(height: s16),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Açıklama', isDense: true),
                ),
                const SizedBox(height: s24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
