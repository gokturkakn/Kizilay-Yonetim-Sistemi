import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'shipment_form_screen.dart';

/// E-53 · Gönderiler — docs/UX-V2.md §6.3.
///
/// Durum **türetilir**: `received_date` boşsa `Yolda`, doluysa `Teslim Edildi`.
class ShipmentListScreen extends StatefulWidget {
  const ShipmentListScreen({super.key});

  @override
  State<ShipmentListScreen> createState() => _ShipmentListScreenState();
}

class _ShipmentListScreenState extends State<ShipmentListScreen> {
  bool _loading = true;
  Object? _error;
  List<Shipment> _items = const [];
  int _statusChip = 0; // 0 Tümü · 1 Yolda · 2 Teslim Edildi

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
      final page = await context.api2.shipments(limit: 200);
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

  List<Shipment> get _visible {
    if (_statusChip == 0) return _items;
    final delivered = _statusChip == 2;
    return _items
        .where((s) => ShipmentStatus.isDelivered(s.receivedDate) == delivered)
        .toList();
  }

  Future<void> _openForm([Shipment? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ShipmentFormScreen(existing: existing),
    ));
    if (saved == true) _load();
  }

  /// E-55 · Teslim Bilgisi Girişi (bottom sheet).
  Future<void> _enterDelivery(Shipment s) async {
    final receivedBy = TextEditingController();
    var date = DateTime.now();
    String? error;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
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
              Text('Teslim Bilgisi',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: s16),
              TextField(
                controller: receivedBy,
                decoration: InputDecoration(
                    labelText: 'Teslim Alan',
                    errorText: error,
                    isDense: true),
              ),
              const SizedBox(height: s16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 1),
                    locale: const Locale('tr'),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Teslim Tarihi', isDense: true),
                  child: Text(Formats.date(date)),
                ),
              ),
              const SizedBox(height: s24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text(Str.vazgec),
                    ),
                  ),
                  const SizedBox(width: s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (receivedBy.text.trim().isEmpty) {
                          setLocal(() => error = S2.vTeslimAlan);
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                      child: const Text(Str.kaydet),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) {
      receivedBy.dispose();
      return;
    }
    if (!mounted) {
      receivedBy.dispose();
      return;
    }
    try {
      await context.api2.updateShipment(s.id, {
        'request_id': s.requestId,
        'shipment_date': s.shipmentDate,
        'quantity': s.quantity,
        'shipping_method_id': s.shippingMethodId,
        'tracking_no': s.trackingNo,
        'received_by': receivedBy.text.trim(),
        'received_date': Formats.apiDate(date),
        'notes': s.notes,
      });
      if (!mounted) return;
      showAppSnackBar(context, S2.basariTeslim);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    } finally {
      receivedBy.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gönderiler')),
      body: Column(
        children: [
          const SizedBox(height: s8),
          LabelFilterChips(
            labels: const ['Tümü', S2.gonderiYolda, S2.gonderiTeslimEdildi],
            selectedIndex: _statusChip,
            onChanged: (i) => setState(() => _statusChip = i),
          ),
          const SizedBox(height: s8),
          Expanded(
            child: AsyncListBody<Shipment>(
              loading: _loading,
              error: _error,
              items: _visible,
              onRetry: _load,
              emptyIcon: Icons.local_shipping_outlined,
              emptyMessage: S2.bosGonderi,
              emptySubMessage: S2.bosListeAlt,
              itemBuilder: (context, s) => RecordCard(
                title: s.productName ?? 'Gönderi #${s.id}',
                trailing: ShipmentStatusBadge(receivedDate: s.receivedDate),
                lines: [
                  if (s.orgUnitName != null) s.orgUnitName!,
                  '${s.productName ?? ''} × ${Formats.number(s.quantity)} · '
                      'Talep: ${Formats.dateFromApi(s.requestDate)}',
                  '${s.shippingMethodName ?? ''} · '
                      'Gönderi: ${Formats.dateFromApi(s.shipmentDate)}',
                ],
                footer: s.trackingNo == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Takip No: ${s.trackingNo}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: kTextSecondary)),
                            ),
                            IconButton(
                              tooltip: 'Takip numarasını kopyala',
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: s.trackingNo!));
                                if (!context.mounted) return;
                                showAppSnackBar(
                                    context, S2.basariTakipKopya);
                              },
                            ),
                          ],
                        ),
                      ),
                onTap: () => _openForm(s),
                actions: [
                  if (!ShipmentStatus.isDelivered(s.receivedDate))
                    const PopupMenuItem(
                        value: 'deliver', child: Text('Teslim Bilgisi Gir')),
                ],
                onAction: (v) {
                  if (v == 'deliver') _enterDelivery(s);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Gönderi',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Gönderi')),
    );
  }
}
