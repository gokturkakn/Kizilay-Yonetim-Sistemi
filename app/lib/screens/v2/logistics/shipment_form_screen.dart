import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/formatters.dart';
import '../../../core/status.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-54 · Gönderi Formu — docs/UX-V2.md §6.3.
///
/// **Gönderi daima bir talepten oluşturulur** (API `request_id` zorunlu);
/// ürün, miktar ve alıcı teşkilat talepten okunur (§10/22).
class ShipmentFormScreen extends StatefulWidget {
  const ShipmentFormScreen({super.key, this.lockedRequest, this.existing});

  final MaterialRequest? lockedRequest;
  final Shipment? existing;

  @override
  State<ShipmentFormScreen> createState() => _ShipmentFormScreenState();
}

class _ShipmentFormScreenState extends State<ShipmentFormScreen> {
  late final FormController _controller;
  late final AttachmentController _attachments;
  final Map<int, MaterialRequest> _requestsById = {};

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final s = widget.existing;
    final locked = widget.lockedRequest;
    if (locked != null) _requestsById[locked.id] = locked;

    _attachments =
        AttachmentController(api: api, entity: 'shipments', entityId: s?.id);
    if (s != null) _attachments.loadExisting();

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(context.lookups),
      initialValues: {
        'request_id': locked?.id ?? s?.requestId,
        'shipment_date': s?.shipmentDate ?? Formats.apiDate(DateTime.now()),
        'quantity': (s?.quantity ?? locked?.remainingQuantity)?.toString(),
        'shipping_method_id': s?.shippingMethodId,
        'tracking_no': s?.trackingNo,
        'received_by': s?.receivedBy,
        'received_date': s?.receivedDate,
        'notes': s?.notes,
      },
      fields: [
        FieldSpec(
          key: 'request_id',
          label: 'Talep',
          type: FieldType.picker,
          required: true,
          requiredMessage: S2.vTalep,
          locked: locked != null,
          section: FormSection.gonderi,
          optionsBuilder: (_) async {
            final page = await api.materialRequests(limit: 200);
            final open =
                page.data.where((r) => RequestStatus.isOpen(r.status)).toList();
            for (final r in open) {
              _requestsById[r.id] = r;
            }
            return [
              for (final r in open)
                FormOption(
                  value: r.id,
                  label:
                      '${r.productName ?? ''} × ${Formats.number(r.quantity)} — ${r.orgUnitName ?? ''}',
                  subtitle: Formats.dateFromApi(r.requestDate),
                ),
            ];
          },
        ),
        FieldSpec(
          key: 'shipment_date',
          label: 'Gönderi Tarihi',
          type: FieldType.date,
          required: true,
          requiredMessage: 'Gönderi tarihi seçin.',
          section: FormSection.gonderi,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
        const FieldSpec(
          key: 'quantity',
          label: 'Miktar',
          type: FieldType.number,
          required: true,
          minValue: 1,
          requiredMessage: S2.vMiktar,
          section: FormSection.gonderi,
        ),
        const FieldSpec(
          key: 'shipping_method_id',
          label: 'Gönderim Şekli',
          type: FieldType.lookup,
          lookupCategory: 'gonderim_sekli',
          required: true,
          requiredMessage: S2.vGonderimSekli,
          section: FormSection.gonderi,
        ),
        // R2 koşullu alan: yalnız `Gönderim Şekli = Kargo`.
        const FieldSpec(
          key: 'tracking_no',
          label: 'Kargo Takip No',
          type: FieldType.text,
          maxLength: 50,
          required: true,
          requiredMessage: S2.vTakipNo,
          visibleWhen: VisibleWhen.code('shipping_method_id', 'kargo'),
          section: FormSection.gonderi,
        ),
        const FieldSpec(
          key: 'received_by',
          label: 'Teslim Alan',
          type: FieldType.text,
          maxLength: 100,
          section: FormSection.teslim,
        ),
        const FieldSpec(
          key: 'received_date',
          label: 'Teslim Tarihi',
          type: FieldType.date,
          helper: S2.teslimHelper,
          section: FormSection.teslim,
        ),
        const FieldSpec(
          key: 'notes',
          label: 'Açıklama',
          type: FieldType.multiline,
          maxLength: 500,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'ek_dokuman',
          label: S2.ekDokuman,
          type: FieldType.attachment,
          attachmentKind: 'dokuman',
          section: FormSection.ekler,
        ),
      ],
    );
    if (locked != null) {
      _controller.seedOptions('request_id', [
        FormOption(
          value: locked.id,
          label:
              '${locked.productName ?? ''} × ${Formats.number(locked.quantity)} — ${locked.orgUnitName ?? ''}',
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final requestId = _controller.intValue('request_id');
    final request = requestId == null ? null : _requestsById[requestId];
    final quantity = _controller.intValue('quantity') ?? 0;
    if (request != null && quantity > request.remainingQuantity) {
      _controller.setServerError('quantity', S2.vGonderiMiktar);
      throw StateError('quantity');
    }
    final start = DateTime.tryParse(_controller.stringValue('shipment_date') ?? '');
    final received =
        DateTime.tryParse(_controller.stringValue('received_date') ?? '');
    if (start != null && received != null && received.isBefore(start)) {
      _controller.setServerError('received_date', S2.vTeslimTarihi);
      throw StateError('received_date');
    }

    final body = _controller.buildBody();
    final api = context.api2;
    try {
      if (widget.existing != null) {
        await api.updateShipment(widget.existing!.id, body);
        if (mounted) showAppSnackBar(context, S2.basariGonderiStok);
        return widget.existing!.id;
      }
      final id = await api.createShipment(body);
      if (mounted) showAppSnackBar(context, S2.basariGonderiStok);
      return id;
    } on ApiException catch (e) {
      if (e.code == 'INSUFFICIENT_STOCK') {
        _controller.setServerError('quantity', e.message);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Yeni Gönderi' : 'Gönderiyi Düzenle',
      controller: _controller,
      attachments: _attachments,
      onSave: _save,
      customFieldBuilder: (context, spec, controller) {
        if (spec.type == FieldType.attachment) {
          return AttachmentField(
            controller: _attachments,
            kind: spec.attachmentKind!,
            label: spec.label,
          );
        }
        return null;
      },
    );
  }
}
