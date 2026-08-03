import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'document_form_fields.dart';

/// E-63 · Belge formu (yalnız `genel_merkez`) — SPEC-V2-M6 §5.2/4.
///
/// `Kapsam` seçimi Bölge/İl/İlçe alanlarını **dinamik açar** (§4.2 R2); alan
/// tanımı [documentFormFields] içindedir ve testte bağlamsız doğrulanır.
class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({super.key, this.existing, this.lockedCategory});

  final DocumentRecord? existing;

  /// Kategori listesinden açıldıysa kategori ön dolu gelir (§4.2 R11).
  final LookupItem? lockedCategory;

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  late final FormController _controller;
  late final AttachmentController _attachments;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final cache = context.lookups;
    final d = widget.existing;

    _attachments =
        AttachmentController(api: api, entity: 'documents', entityId: d?.id);
    if (d != null) _attachments.loadExisting();

    final fields = documentFormFields(
      regions: (_) => regionOptions(cache),
      provinces: (values) => provinceOptions(cache, values),
      districts: (values) => districtOptions(cache, values),
    );

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      fields: [
        for (final f in fields)
          if (f.key == 'category_id' && widget.lockedCategory != null)
            f.copyWith(required: true, locked: true)
          else
            f,
      ],
      initialValues: {
        'title': d?.title,
        'category_id': d?.categoryId ?? widget.lockedCategory?.id,
        'version': d?.version,
        'published_at': d?.publishedAt,
        'valid_until': d?.validUntil,
        'scope': d?.scope ?? DocumentScope.genel,
        'region_id': d?.regionId,
        'province_id': d?.provinceId,
        'district_id': d?.districtId,
        'description': d?.description,
      },
    );
    final locked = widget.lockedCategory;
    if (locked != null) {
      _controller.seedOptions('category_id',
          [FormOption(value: locked.id, label: locked.name, code: locked.code)]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final body = _controller.buildBody();
    // Kapsam `genel`'e çekildiyse gizli coğrafya alanları gövdeye `null`
    // gider (R2.2) ve sunucudaki eski değerler temizlenir (API-V2 §19.3).
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateDocument(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.dokKaydedildi);
      return widget.existing!.id;
    }
    final id = await api.createDocument(body);
    if (mounted) showAppSnackBar(context, S2.dokKaydedildi);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? S2.dokYeni : S2.dokDuzenle,
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
