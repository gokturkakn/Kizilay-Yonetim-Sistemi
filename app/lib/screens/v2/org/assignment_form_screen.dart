import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/common.dart';
import '../person_picker_field.dart';
import '../shared.dart';

/// E-28 · Görevlendirme Formu — docs/UX-V2.md §6.1.
class AssignmentFormScreen extends StatefulWidget {
  const AssignmentFormScreen({
    super.key,
    this.lockedUnit,
    this.existing,
  });

  final OrgUnit? lockedUnit;
  final OrgAssignment? existing;

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  late final FormController _controller;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final locked = widget.lockedUnit;
    final existing = widget.existing;
    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(context.lookups),
      initialValues: {
        'org_unit_id': locked?.id ?? existing?.orgUnitId,
        'person_id': existing?.personId,
        'role_id': existing?.roleId,
        'start_date': existing?.startDate,
        'end_date': existing?.endDate,
        'status': existing?.status ?? 'aktif',
        'notes': existing?.notes,
      },
      fields: [
        FieldSpec(
          key: 'org_unit_id',
          label: 'Teşkilat Birimi',
          type: FieldType.orgPicker,
          required: true,
          requiredMessage: S2.vTeskilatBirimi,
          // §4.2 R11 — bağlamdan geldiyse görünür ama kilitli.
          locked: locked != null,
          optionsBuilder: (_) => orgUnitOptions(api),
        ),
        const FieldSpec(
          key: 'person_id',
          label: 'Kişi',
          type: FieldType.personPicker,
          required: true,
          requiredMessage: S2.vKisi,
        ),
        const FieldSpec(
          key: 'role_id',
          label: 'Görev',
          type: FieldType.picker,
          lookupCategory: 'gorev_unvani',
          required: true,
          requiredMessage: S2.vGorev,
        ),
        const FieldSpec(
          key: 'start_date',
          label: 'Göreve Başlama Tarihi',
          type: FieldType.date,
          required: true,
          requiredMessage: S2.vBaslamaTarihi,
        ),
        const FieldSpec(
          key: 'end_date',
          label: 'Görev Bitiş Tarihi',
          type: FieldType.date,
          helper: S2.gorevDevam,
        ),
        const FieldSpec(
          key: 'status',
          label: 'Durum',
          type: FieldType.segment,
          required: true,
          defaultValue: 'aktif',
        ),
        const FieldSpec(
          key: 'notes',
          label: 'Açıklama',
          type: FieldType.multiline,
          maxLength: 500,
        ),
      ],
    );
    // Durum segmenti kod tabanlı sabit enumdur (§10/3) — lookup değil.
    _controller.seedOptions('status', const [
      FormOption(value: 'aktif', label: S2.aktif, code: 'aktif'),
      FormOption(value: 'pasif', label: S2.pasif, code: 'pasif'),
    ]);
    if (locked != null) {
      _controller.seedOptions('org_unit_id', [
        FormOption(value: locked.id, label: locked.name),
      ]);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateDates() {
    final start = DateTime.tryParse(_controller.stringValue('start_date') ?? '');
    final end = DateTime.tryParse(_controller.stringValue('end_date') ?? '');
    if (start != null && end != null && end.isBefore(start)) {
      return S2.vBitisTarihi;
    }
    return null;
  }

  Future<int?> _save() async {
    final dateError = _validateDates();
    if (dateError != null) {
      _controller.setServerError('end_date', dateError);
      throw StateError(dateError);
    }
    final body = _controller.buildBody();
    final wasGap = widget.lockedUnit?.status == 'teskilat_yok';
    try {
      if (widget.existing != null) {
        await context.api2.updateOrgAssignment(widget.existing!.id, body);
      } else {
        await context.api2.createOrgAssignment(body);
      }
    } on ApiException catch (e) {
      if (e.isConflict) {
        _controller.setServerError('person_id', S2.kisiZatenGorevli);
        rethrow;
      }
      rethrow;
    }
    if (mounted) {
      showAppSnackBar(context, S2.basariGorevlendirme);
      // Sunucu yan etkisi doğrulandıktan sonra ek bildirim (§11 N-9).
      if (wasGap && body['status'] == 'aktif') {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) showAppSnackBar(context, S2.otomatikAktif);
      }
    }
    return null; // ek kuyruğu yok
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null
          ? S2.gorevliAta
          : 'Görevlendirmeyi Düzenle',
      controller: _controller,
      onSave: _save,
      customFieldBuilder: (context, spec, controller) {
        if (spec.type == FieldType.personPicker) {
          return PersonPickerField(spec: spec, controller: controller);
        }
        return null;
      },
    );
  }
}
