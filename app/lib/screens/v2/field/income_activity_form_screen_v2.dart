import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// Gelir Getirici Faaliyet Formu — SPEC-V2 §3.2E, API-V2 §6.5.
///
/// Görev/Eğitim/Etkinlik/Toplantı'nın kardeşi ama AYRI bir modül: kendi mali
/// sonucu (gelir/gider/net) olan tek faaliyet türü budur. `Net Gelir` sunucuda
/// hesaplanır; formda YAZILABİLİR bir alan olarak gösterilmez.
class IncomeActivityFormScreenV2 extends StatefulWidget {
  const IncomeActivityFormScreenV2({super.key, this.existing});

  final IncomeActivityRecord? existing;

  @override
  State<IncomeActivityFormScreenV2> createState() =>
      _IncomeActivityFormScreenV2State();
}

class _IncomeActivityFormScreenV2State
    extends State<IncomeActivityFormScreenV2> {
  late final FormController _controller;
  late final AttachmentController _attachments;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final cache = context.lookups;
    final ia = widget.existing;

    _attachments = AttachmentController(
        api: api, entity: 'income_activities', entityId: ia?.id);
    if (ia != null) _attachments.loadExisting();

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'name': ia?.name,
        'activity_type_id': ia?.activityTypeId,
        'purpose': ia?.purpose,
        'activity_date': ia?.activityDate ?? Formats.apiDate(DateTime.now()),
        'region_id': ia?.regionId,
        'province_id': ia?.provinceId,
        'district_id': ia?.districtId,
        'org_unit_id': ia?.orgUnitId,
        'location': ia?.location,
        'target_income': FormController.formatDecimal(ia?.targetIncome),
        'income_amount': FormController.formatDecimal(ia?.incomeAmount),
        'expense_amount': FormController.formatDecimal(ia?.expenseAmount),
        'participant_count': ia?.participantCount.toString(),
        'volunteer_count': ia?.volunteerCount.toString(),
        'supporting_orgs': ia?.supportingOrgs,
        'sponsors': ia?.sponsors,
        'notes': ia?.notes,
      },
      fields: [
        const FieldSpec(
          key: 'name',
          label: 'Faaliyet Adı',
          type: FieldType.text,
          required: true,
          maxLength: 200,
          requiredMessage: S2.vGelirFaaliyetAdi,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'activity_type_id',
          label: 'Faaliyet Türü',
          type: FieldType.lookup,
          lookupCategory: 'gelir_getirici_faaliyet_turu',
          required: true,
          requiredMessage: S2.vGelirFaaliyetTuru,
          section: FormSection.faaliyet,
        ),
        FieldSpec(
          key: 'activity_date',
          label: 'Tarih',
          type: FieldType.date,
          required: true,
          section: FormSection.faaliyet,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
        const FieldSpec(
          key: 'purpose',
          label: 'Amaç',
          type: FieldType.multiline,
          maxLength: 500,
          section: FormSection.faaliyet,
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
          emptyOptionLabel: S2.ilGeneli,
          section: FormSection.konum,
          optionsBuilder: (values) => districtOptions(cache, values),
        ),
        FieldSpec(
          key: 'org_unit_id',
          label: 'Düzenleyen Kadın Teşkilatı',
          type: FieldType.orgPicker,
          required: true,
          requiredMessage: S2.vDuzenleyenTeskilat,
          section: FormSection.konum,
          optionsBuilder: (values) => orgUnitOptions(
            api,
            provinceId: values['province_id'] is int
                ? values['province_id'] as int
                : null,
          ),
        ),
        const FieldSpec(
          key: 'location',
          label: 'Faaliyet Yeri',
          type: FieldType.text,
          maxLength: 150,
          section: FormSection.konum,
        ),
        const FieldSpec(
          key: 'target_income',
          label: 'Hedeflenen Gelir (isteğe bağlı)',
          type: FieldType.decimal,
          hint: 'Örn. 50000',
          invalidMessage: S2.vTutarBicim,
          section: FormSection.gelir,
        ),
        const FieldSpec(
          key: 'income_amount',
          label: 'Gelir Tutarı (TL)',
          type: FieldType.decimal,
          required: true,
          hint: 'Örn. 62000',
          requiredMessage: S2.vGelirTutari,
          invalidMessage: S2.vTutarBicim,
          section: FormSection.gelir,
        ),
        const FieldSpec(
          key: 'expense_amount',
          label: 'Gider Tutarı (TL, isteğe bağlı)',
          type: FieldType.decimal,
          hint: 'Örn. 8000',
          invalidMessage: S2.vTutarBicim,
          section: FormSection.gelir,
        ),
        const FieldSpec(
          key: 'participant_count',
          label: 'Katılımcı Sayısı',
          type: FieldType.number,
          section: FormSection.katilim,
        ),
        const FieldSpec(
          key: 'volunteer_count',
          label: 'Gönüllü Sayısı',
          type: FieldType.number,
          section: FormSection.katilim,
        ),
        const FieldSpec(
          key: 'supporting_orgs',
          label: 'Destek Veren Kurum/Kuruluşlar',
          type: FieldType.multiline,
          maxLength: 500,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'sponsors',
          label: 'Sponsorlar',
          type: FieldType.multiline,
          maxLength: 500,
          section: FormSection.aciklama,
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
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateIncomeActivity(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariGelir);
      return widget.existing!.id;
    }
    final id = await api.createIncomeActivity(body);
    if (mounted) showAppSnackBar(context, S2.basariGelir);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null
          ? 'Yeni Gelir Getirici Faaliyet'
          : 'Gelir Getirici Faaliyeti Düzenle',
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
