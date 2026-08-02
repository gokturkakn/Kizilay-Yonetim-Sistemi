import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-42 · Görev Formu — docs/UX-V2.md §6.2 (§4 kuralları geçerli).
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.existing});

  final TaskRecord? existing;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final FormController _controller;
  late final AttachmentController _attachments;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final cache = context.lookups;
    final t = widget.existing;

    _attachments =
        AttachmentController(api: api, entity: 'tasks', entityId: t?.id);
    if (t != null) _attachments.loadExisting();

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'task_date': t?.taskDate ?? Formats.apiDate(DateTime.now()),
        'region_id': t?.regionId,
        'province_id': t?.provinceId,
        'district_id': t?.districtId,
        'branch': t?.branch,
        'org_unit_id': t?.orgUnitId,
        'task_type_id': t?.taskTypeId,
        'sub_task_id': t?.subTaskId,
        'volunteer_count': t?.volunteerCount.toString(),
        'beneficiary_count': t?.beneficiaryCount.toString(),
        'duration_hours': FormController.formatDecimal(t?.durationHours),
        'notes': t?.notes,
      },
      fields: [
        FieldSpec(
          key: 'task_date',
          label: 'Tarih',
          type: FieldType.date,
          required: true,
          noFutureDates: true, // §4.5 — ileri tarihli kayıt girilemez
          section: FormSection.faaliyet,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
        // §4.3(a) — Bölge → İl → İlçe
        FieldSpec(
          key: 'region_id',
          label: 'Bölge',
          type: FieldType.lookup,
          required: true,
          requiredMessage: S2.vBolge,
          section: FormSection.konum,
          optionsBuilder: (_) => regionOptions(cache),
        ),
        FieldSpec(
          key: 'province_id',
          label: 'İl',
          type: FieldType.picker,
          parentKey: 'region_id',
          required: true,
          requiredMessage: S2.vIl,
          section: FormSection.konum,
          optionsBuilder: (values) => provinceOptions(cache, values),
        ),
        FieldSpec(
          key: 'district_id',
          label: 'İlçe',
          type: FieldType.picker,
          parentKey: 'province_id',
          emptyOptionLabel: S2.ilGeneli, // §10/11 — `Seçilmedi` yerine
          section: FormSection.konum,
          optionsBuilder: (values) => districtOptions(cache, values),
        ),
        const FieldSpec(
          key: 'branch',
          label: 'Şube',
          type: FieldType.text,
          maxLength: 100,
          parentKey: 'province_id',
          autocompleteKey: 'branch',
          section: FormSection.konum,
        ),
        FieldSpec(
          key: 'org_unit_id',
          label: 'Kadın Teşkilatı',
          type: FieldType.orgPicker,
          required: true,
          requiredMessage: S2.vKadinTeskilati,
          section: FormSection.konum,
          optionsBuilder: (values) => orgUnitOptions(
            api,
            provinceId: values['province_id'] is int
                ? values['province_id'] as int
                : null,
          ),
        ),
        // §4.3(b) — Görev Türü → Alt Görev
        const FieldSpec(
          key: 'task_type_id',
          label: 'Görev Türü',
          type: FieldType.picker,
          lookupCategory: 'gorev_turu',
          required: true,
          requiredMessage: S2.vGorevTuru,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'sub_task_id',
          label: 'Alt Görev',
          type: FieldType.picker,
          lookupCategory: 'alt_gorev',
          parentKey: 'task_type_id',
          required: true,
          requiredMessage: S2.vAltGorev,
          emptyListHelper: S2.altGorevYok,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'volunteer_count',
          label: 'Gönüllü Sayısı',
          type: FieldType.number,
          required: true,
          requiredMessage: S2.vGonulluSayisi,
          section: FormSection.sayisal,
        ),
        const FieldSpec(
          key: 'beneficiary_count',
          label: 'Yararlanıcı Sayısı',
          type: FieldType.number,
          required: true,
          requiredMessage: S2.vYararlaniciSayisi,
          section: FormSection.sayisal,
        ),
        const FieldSpec(
          key: 'duration_hours',
          label: 'Süre (saat)',
          type: FieldType.decimal,
          required: true,
          requiredMessage: S2.vSure,
          hint: 'Örn. 2,5',
          section: FormSection.sayisal,
        ),
        const FieldSpec(
          key: 'notes',
          label: 'Açıklama',
          type: FieldType.multiline,
          maxLength: 1000,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'ek_fotograf',
          label: S2.ekFotograf,
          type: FieldType.attachment,
          attachmentKind: 'fotograf',
          section: FormSection.ekler,
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final body = _controller.buildBody();
    // §4.3(b) — alt görevi olmayan görev türünde alan gizlidir, null gider.
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateTask(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariGorev);
      return widget.existing!.id;
    }
    final id = await api.createTask(body);
    if (mounted) showAppSnackBar(context, S2.basariGorev);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null
          ? 'Yeni Görev Kaydı'
          : 'Görev Kaydını Düzenle',
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
