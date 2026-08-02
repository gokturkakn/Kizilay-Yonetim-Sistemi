import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../person_picker_field.dart';
import '../shared.dart';

/// E-52 · Talep Formu — docs/UX-V2.md §6.3.
///
/// **Tek kalemli talep** (API-V2 §7.1): bir talep tek ürün + tek miktar taşır.
class MaterialRequestFormScreen extends StatefulWidget {
  const MaterialRequestFormScreen({super.key, this.existing});

  final MaterialRequest? existing;

  @override
  State<MaterialRequestFormScreen> createState() =>
      _MaterialRequestFormScreenState();
}

class _MaterialRequestFormScreenState extends State<MaterialRequestFormScreen> {
  late final FormController _controller;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final r = widget.existing;
    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(context.lookups),
      initialValues: {
        'request_date': r?.requestDate ?? Formats.apiDate(DateTime.now()),
        'org_unit_id': r?.orgUnitId,
        'product_id': r?.productId,
        'quantity': r?.quantity.toString(),
        'requested_by_person_id': r?.requestedByPersonId,
        'notes': r?.notes,
      },
      fields: [
        FieldSpec(
          key: 'request_date',
          label: 'Talep Tarihi',
          type: FieldType.date,
          required: true,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
        FieldSpec(
          key: 'org_unit_id',
          label: 'Talep Eden Teşkilat',
          type: FieldType.orgPicker,
          required: true,
          requiredMessage: S2.vTeskilatBirimi,
          optionsBuilder: (_) => orgUnitOptions(api),
        ),
        const FieldSpec(
          key: 'product_id',
          label: 'Ürün',
          type: FieldType.picker,
          lookupCategory: 'lojistik_urun',
          required: true,
          requiredMessage: S2.vUrun,
        ),
        const FieldSpec(
          key: 'quantity',
          label: 'Miktar',
          type: FieldType.number,
          required: true,
          minValue: 1,
          requiredMessage: S2.vMiktar,
        ),
        const FieldSpec(
          key: 'requested_by_person_id',
          label: 'Talep Eden Kişi',
          type: FieldType.personPicker,
        ),
        const FieldSpec(
          key: 'notes',
          label: 'Açıklama',
          type: FieldType.multiline,
          maxLength: 500,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final body = _controller.buildBody();
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateMaterialRequest(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariTalep);
      return widget.existing!.id;
    }
    final id = await api.createMaterialRequest(body);
    if (mounted) showAppSnackBar(context, S2.basariTalep);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Yeni Talep' : 'Talebi Düzenle',
      controller: _controller,
      onSave: _save,
      footer: const Padding(
        padding: EdgeInsets.fromLTRB(s16, 0, s16, s16),
        child: Text(S2.herUrunAyriTalep,
            style: TextStyle(fontSize: 12, color: kTextSecondary)),
      ),
      customFieldBuilder: (context, spec, controller) {
        if (spec.type == FieldType.personPicker) {
          return PersonPickerField(spec: spec, controller: controller);
        }
        return null;
      },
    );
  }
}
