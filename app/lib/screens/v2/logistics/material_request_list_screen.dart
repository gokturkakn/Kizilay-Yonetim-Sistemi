import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/status.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/status_widgets.dart';
import '../shared.dart';
import 'material_request_form_screen.dart';
import 'shipment_form_screen.dart';

/// E-51 · Malzeme Talepleri — docs/UX-V2.md §6.3.
class MaterialRequestListScreen extends StatefulWidget {
  const MaterialRequestListScreen({super.key});

  @override
  State<MaterialRequestListScreen> createState() =>
      _MaterialRequestListScreenState();
}

class _MaterialRequestListScreenState extends State<MaterialRequestListScreen> {
  bool _loading = true;
  Object? _error;
  List<MaterialRequest> _items = const [];
  int _statusChip = 0;

  static const _chipLabels = [
    'Tümü',
    S2.talepTalep,
    S2.talepOnaylandi,
    S2.talepGonderildi,
    S2.talepTeslimEdildi,
    S2.talepIptal,
  ];

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
      final page = await context.api2.materialRequests(limit: 200);
      if (!mounted) return;
      setState(() {
        _items = page.data;
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

  List<MaterialRequest> get _visible {
    if (_statusChip == 0) return _items;
    final status = RequestStatus.values[_statusChip - 1];
    return _items.where((r) => r.status == status).toList();
  }

  Future<void> _openForm([MaterialRequest? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MaterialRequestFormScreen(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _setStatus(MaterialRequest r, String status) async {
    if (status == 'iptal') {
      final ok = await showConfirmDialog(
        context,
        title: S2.dlgTalepIptal,
        body: S2.dlgTalepIptalGovde,
        confirmText: 'İptal Et',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    try {
      await context.api2.setMaterialRequestStatus(r.id, status);
      if (!mounted) return;
      showAppSnackBar(context, S2.talepDurumGuncellendi);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _delete(MaterialRequest r) async {
    final api = context.api2;
    if (!await confirmDelete(context, 'Talep silinsin mi?')) return;
    try {
      await api.deleteMaterialRequest(r.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(S2.dlgTalepSilinemez),
            content: const Text(S2.dlgTalepSilinemezGovde),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(Str.tamam)),
            ],
          ),
        );
        return;
      }
      if (!context.mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _createShipment(MaterialRequest r) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ShipmentFormScreen(lockedRequest: r),
    ));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Malzeme Talepleri')),
      body: Column(
        children: [
          const SizedBox(height: s8),
          LabelFilterChips(
            labels: _chipLabels,
            selectedIndex: _statusChip,
            onChanged: (i) => setState(() => _statusChip = i),
          ),
          const SizedBox(height: s8),
          Expanded(
            child: AsyncListBody<MaterialRequest>(
              loading: _loading,
              error: _error,
              items: _visible,
              onRetry: _load,
              emptyIcon: Icons.playlist_add_check_outlined,
              emptyMessage: S2.bosTalep,
              emptySubMessage: 'İlk talebi eklemek için + butonuna dokunun.',
              itemBuilder: (context, r) => RecordCard(
                title: r.orgUnitName ?? 'Talep #${r.id}',
                trailing: RequestStatusBadge(status: r.status),
                lines: [
                  '${r.productName ?? ''} × ${Formats.number(r.quantity)}'
                      '${r.shippedQuantity > 0 ? ' (${Formats.number(r.shippedQuantity)} gönderildi)' : ''}',
                  'Talep Tarihi: ${Formats.dateFromApi(r.requestDate)}',
                ],
                onTap: () => _openForm(r),
                actions: isAdmin
                    ? [
                        if (r.status == 'talep')
                          const PopupMenuItem(
                              value: 'approve', child: Text('Onayla')),
                        if (RequestStatus.isOpen(r.status))
                          const PopupMenuItem(
                              value: 'cancel', child: Text('İptal Et')),
                        if (RequestStatus.isOpen(r.status))
                          const PopupMenuItem(
                              value: 'ship', child: Text('Gönderi Oluştur')),
                        const PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ]
                    : null,
                onAction: (v) {
                  switch (v) {
                    case 'approve':
                      _setStatus(r, 'onaylandi');
                    case 'cancel':
                      _setStatus(r, 'iptal');
                    case 'ship':
                      _createShipment(r);
                    case 'delete':
                      _delete(r);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Talep',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Talep')),
    );
  }
}
