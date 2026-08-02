import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/status.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../../../widgets/status_widgets.dart';
import '../shared.dart';
import 'assignment_form_screen.dart';

/// E-27 · Birim Detayı — tüm birim türleri için **tek** ekran (§6.1).
class OrgUnitDetailScreen extends StatefulWidget {
  const OrgUnitDetailScreen({
    super.key,
    required this.unitId,
    this.embedded = false,
  });

  final int unitId;

  /// İki panelli düzende sağ panelde gömülü çizim (AppBar'sız).
  final bool embedded;

  @override
  State<OrgUnitDetailScreen> createState() => _OrgUnitDetailScreenState();
}

class _OrgUnitDetailScreenState extends State<OrgUnitDetailScreen> {
  bool _loading = true;
  Object? _error;
  OrgUnit? _unit;
  List<OrgAssignment> _assignments = const [];
  List<OrgUnit> _children = const [];
  List<Attachment> _attachments = const [];
  StatusFilter _assignmentFilter =
      const StatusFilter(value: null, includeTeskilatYok: false);
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrgUnitDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.unitId != widget.unitId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.api2;
    try {
      final unit = await api.orgUnit(widget.unitId);
      final assignments = await api.orgAssignments(orgUnitId: widget.unitId);
      List<OrgUnit> children = const [];
      if (unit.type == OrgUnitType.ilBaskanligi && unit.provinceId != null) {
        final ilce = await api.orgUnits(
            type: OrgUnitType.ilceBaskanligi,
            provinceId: unit.provinceId,
            limit: 500);
        final temsil = await api.orgUnits(
            type: OrgUnitType.temsilcilik,
            provinceId: unit.provinceId,
            limit: 500);
        children = [...ilce.data, ...temsil.data];
      }
      List<Attachment> attachments = const [];
      try {
        attachments =
            await api.attachments(entity: 'org_units', entityId: widget.unitId);
      } catch (_) {
        attachments = const [];
      }
      if (!mounted) return;
      setState(() {
        _unit = unit;
        _assignments = assignments;
        _children = children;
        _attachments = attachments;
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

  bool get _hasActiveAssignment => _assignments.any((a) => a.isActive);

  Future<void> _changeStatus(OrgStatus next) async {
    final unit = _unit!;
    // §3.4 kilit kuralı: aktif görevli varken "Teşkilat Yok" seçilemez.
    if (next == OrgStatus.teskilatYok && _hasActiveAssignment) return;
    final ok = await showConfirmDialog(
      context,
      title: S2.dlgDurumBaslik,
      body: S2.dlgDurumGovde(unit.name, next.label),
    );
    if (!ok) return;
    if (!mounted) return;
    try {
      await context.api2.setOrgUnitStatus(unit.id, next.apiValue);
      _changed = true;
      if (!mounted) return;
      showAppSnackBar(context, S2.durumGuncellendi);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _assign() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AssignmentFormScreen(lockedUnit: _unit),
    ));
    if (saved == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _endAssignment(OrgAssignment a) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
      locale: const Locale('tr'),
      helpText: S2.dlgGoreviSonlandir,
    );
    if (picked == null) return;
    if (!mounted) return;
    try {
      await context.api2.updateOrgAssignment(a.id, {
        'org_unit_id': a.orgUnitId,
        'person_id': a.personId,
        'role_id': a.roleId,
        'role_title': a.roleTitle,
        'start_date': a.startDate,
        'end_date': Formats.apiDate(picked),
        'status': 'pasif',
      });
      _changed = true;
      if (!mounted) return;
      await _load();
      // §11 N-9 — son aktif görev bitince durum **kullanıcı onayıyla** düşer.
      if (!mounted) return;
      if (!_hasActiveAssignment && _unit?.status == 'aktif') {
        if (!context.mounted) return;
        final drop = await showConfirmDialog(
          context,
          title: S2.dlgGorevliKalmadi,
          body: S2.dlgGorevliKalmadiGovde,
          confirmText: S2.evet,
        );
        if (drop && mounted) {
          await context.api2
              .setOrgUnitStatus(widget.unitId, OrgStatus.teskilatYok.apiValue);
          if (!mounted) return;
          showAppSnackBar(context, S2.otomatikTeskilatYok);
          _load();
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _removeAssignment(OrgAssignment a) async {
    final ok = await showConfirmDialog(
      context,
      title: S2.dlgGorevdenCikar,
      body: S2.dlgGorevdenCikarGovde,
      confirmText: Str.cikar,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    try {
      await context.api2.deleteOrgAssignment(a.id);
      _changed = true;
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _wrap(const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _unit == null) {
      return _wrap(ErrorState(
          onRetry: _load, message: v2ErrorMessage(_error ?? Object())));
    }
    final unit = _unit!;
    final showChildren = unit.type == OrgUnitType.ilBaskanligi;
    final tabCount = 1 + (showChildren ? 1 : 0) + 1; // Görevliler + [Alt] + Ekler

    return DefaultTabController(
      length: tabCount,
      child: _wrap(
        Column(
          children: [
            _IdentityCard(unit: unit),
            if (context.isAdmin) _statusCard(unit),
            // Sekme sayısı 1'e düşerse TabBar gizlenir (§6.1 E-27/4).
            if (tabCount > 1)
              TabBar(
                labelColor: kPrimary,
                unselectedLabelColor: kTextSecondary,
                indicatorColor: kPrimary,
                tabs: [
                  const Tab(text: 'Görevliler'),
                  if (showChildren) const Tab(text: 'Alt Birimler'),
                  const Tab(text: 'Ekler'),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _assignmentsTab(),
                  if (showChildren) _childrenTab(),
                  _attachments.isEmpty
                      ? const EmptyState(
                          icon: Icons.attach_file, message: S2.ekDetayBos)
                      : SingleChildScrollView(
                          child: AttachmentList(attachments: _attachments)),
                ],
              ),
            ),
          ],
        ),
        title: unit.name,
      ),
    );
  }

  Widget _wrap(Widget body, {String? title}) {
    if (widget.embedded) return body;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title ?? 'Birim Detayı')),
        body: body,
        floatingActionButton: context.isAdmin && !_loading && _unit != null
            ? FloatingActionButton.extended(
                onPressed: _assign,
                icon: const Icon(Icons.person_add),
                label: const Text(S2.gorevliAta),
              )
            : null,
      ),
    );
  }

  Widget _statusCard(OrgUnit unit) {
    final current = orgStatusFromApi(unit.status);
    final locked = _hasActiveAssignment;
    return Padding(
      padding: const EdgeInsets.fromLTRB(s16, 0, s16, s16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Durum', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: s8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<OrgStatus>(
                  segments: [
                    for (final s in OrgStatus.values)
                      ButtonSegment(
                        value: s,
                        label: Text(s.label),
                        enabled:
                            !(s == OrgStatus.teskilatYok && locked),
                      ),
                  ],
                  selected: {current},
                  showSelectedIcon: false,
                  onSelectionChanged: (sel) => _changeStatus(sel.first),
                ),
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: s4),
                  child: Text(S2.gorevliKilit,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kTextSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _assignmentsTab() {
    final visible = _assignments
        .where((a) => _assignmentFilter.matches(a.status))
        .toList();
    return Column(
      children: [
        const SizedBox(height: s8),
        StatusFilterChips(
          filter: _assignmentFilter,
          onChanged: (s) =>
              setState(() => _assignmentFilter = _assignmentFilter.select(s)),
        ),
        const SizedBox(height: s8),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.group_off_outlined,
                  message: S2.bosGorevliler,
                  actionLabel: context.isAdmin ? S2.gorevliAta : null,
                  onAction: context.isAdmin ? _assign : null,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(s16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: s12),
                  itemBuilder: (context, i) {
                    final a = visible[i];
                    return RecordCard(
                      title: a.personName ?? 'Kişi #${a.personId}',
                      lines: [
                        if (a.roleTitle != null) a.roleTitle!,
                        _dateRange(a),
                      ],
                      trailing: OrgStatusBadge.fromApi(a.status),
                      actions: context.isAdmin
                          ? const [
                              PopupMenuItem(
                                  value: 'end',
                                  child: Text('Görevi Sonlandır')),
                              PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Görevden Çıkar')),
                            ]
                          : null,
                      onAction: (v) {
                        if (v == 'end') _endAssignment(a);
                        if (v == 'remove') _removeAssignment(a);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _dateRange(OrgAssignment a) {
    final start = Formats.dateFromApi(a.startDate);
    if (a.endDate == null || a.endDate!.isEmpty) {
      return '$start – ${S2.devamEdiyor}';
    }
    return '$start – ${Formats.dateFromApi(a.endDate)}';
  }

  Widget _childrenTab() {
    if (_children.isEmpty) {
      return const EmptyState(
          icon: Icons.account_tree_outlined, message: S2.bosAltBirim);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(s16),
      itemCount: _children.length,
      separatorBuilder: (_, _) => const SizedBox(height: s12),
      itemBuilder: (context, i) {
        final u = _children[i];
        return RecordCard(
          title: u.name,
          lines: [OrgUnitType.label(u.type)],
          trailing: OrgStatusBadge.fromApi(u.status),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrgUnitDetailScreen(unitId: u.id),
          )),
        );
      },
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.unit});

  final OrgUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(s16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.name, style: theme.textTheme.headlineSmall),
                    if (unit.locationLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Text(unit.locationLabel,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: kTextSecondary)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: s4),
                      child: Text(OrgUnitType.label(unit.type),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary)),
                    ),
                  ],
                ),
              ),
              OrgStatusBadge.fromApi(unit.status),
            ],
          ),
        ),
      ),
    );
  }
}
