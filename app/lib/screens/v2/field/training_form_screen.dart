import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-44 · Eğitim Formu — docs/UX-V2.md §6.2, §4.3(d) matrisi.
class TrainingFormScreen extends StatefulWidget {
  const TrainingFormScreen({super.key, this.existing});

  final TrainingRecord? existing;

  @override
  State<TrainingFormScreen> createState() => _TrainingFormScreenState();
}

class _TrainingFormScreenState extends State<TrainingFormScreen> {
  late final FormController _controller;
  late final AttachmentController _attachments;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final cache = context.lookups;
    final t = widget.existing;

    _attachments =
        AttachmentController(api: api, entity: 'trainings', entityId: t?.id);
    if (t != null) _attachments.loadExisting();

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'training_date': t?.trainingDate ?? Formats.apiDate(DateTime.now()),
        'region_id': t?.regionId,
        'province_id': t?.provinceId,
        'org_unit_id': t?.orgUnitId,
        'category_id': t?.categoryId,
        'method_id': t?.methodId,
        'topic_id': t?.topicId,
        'trainer': t?.trainer,
        'participant_count': t?.participantCount.toString(),
        'volunteer_count': t?.volunteerCount.toString(),
        'duration_hours': FormController.formatDecimal(t?.durationHours),
        'notes': t?.notes,
      },
      fields: [
        FieldSpec(
          key: 'training_date',
          label: 'Tarih',
          type: FieldType.date,
          required: true,
          noFutureDates: true,
          section: FormSection.faaliyet,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
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
          key: 'org_unit_id',
          label: 'Düzenleyen Teşkilat',
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
        // §4.3(d) — Kategori × Yöntem matrisi → Konu listesini filtreler.
        const FieldSpec(
          key: 'category_id',
          label: 'Kategori',
          type: FieldType.segment,
          lookupCategory: 'egitim_kategorisi',
          required: true,
          requiredMessage: S2.vEgitimKategorisi,
          section: FormSection.egitim,
        ),
        const FieldSpec(
          key: 'method_id',
          label: 'Yöntem',
          type: FieldType.segment,
          lookupCategory: 'egitim_yontemi',
          required: true,
          requiredMessage: S2.vEgitimYontemi,
          section: FormSection.egitim,
        ),
        FieldSpec(
          key: 'topic_id',
          label: 'Konu',
          type: FieldType.picker,
          parentKey: 'category_id,method_id',
          required: true,
          requiredMessage: S2.vEgitimKonusu,
          emptyListHelper: S2.konuYok,
          section: FormSection.egitim,
          optionsBuilder: (_) async {
            final items = await cache.items('egitim_konusu');
            return items
                .map((e) => FormOption(
                    value: e.id, label: e.name, code: e.code))
                .toList();
          },
        ),
        // §4.3(d) — Yöntem Çevrim İçi ise Platform alanı (c) kuralıyla gelir.
        const FieldSpec(
          key: 'platform_id',
          label: 'Platform',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_platformu',
          required: true,
          requiredMessage: S2.vPlatform,
          visibleWhen: VisibleWhen.code('method_id', 'cevrim_ici'),
          section: FormSection.egitim,
        ),
        const FieldSpec(
          key: 'platform_name',
          label: 'Platform Adı',
          type: FieldType.text,
          required: true,
          maxLength: 60,
          requiredMessage: S2.vPlatformAdi,
          visibleWhen: VisibleWhen.code('platform_id', 'diger'),
          section: FormSection.egitim,
        ),
        const FieldSpec(
          key: 'trainer',
          label: 'Eğitmen',
          type: FieldType.text,
          maxLength: 100,
          required: true,
          requiredMessage: S2.vEgitmen,
          section: FormSection.egitim,
        ),
        const FieldSpec(
          key: 'participant_count',
          label: 'Katılımcı Sayısı',
          type: FieldType.number,
          required: true,
          requiredMessage: S2.vKatilimciSayisi,
          section: FormSection.sayisal,
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
          key: 'ek_katilim',
          label: S2.ekKatilimListesi,
          type: FieldType.attachment,
          attachmentKind: 'katilim_listesi',
          section: FormSection.ekler,
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
    // Platform API sütunu yok; seçilen değer açıklamaya taşınmaz, atılır.
    body.remove('platform_id');
    body.remove('platform_name');
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateTraining(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariEgitim);
      return widget.existing!.id;
    }
    final id = await api.createTraining(body);
    if (mounted) showAppSnackBar(context, S2.basariEgitim);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null
          ? 'Yeni Eğitim Kaydı'
          : 'Eğitim Kaydını Düzenle',
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
