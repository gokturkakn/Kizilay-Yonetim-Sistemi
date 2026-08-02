import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-49 · Toplantı Formu — docs/UX-V2.md §6.2, §4.3(c).
///
/// **Dinamik form motorunun amiral örneği:** `Toplantı Yöntemi` seçimi
/// `Yüz Yüze` → `Toplantı Yeri`, `Çevrim İçi` → `Platform` alanını gösterir;
/// uymayan alanın anahtarı gövdeye **hiç konmaz** (sunucu 400 döndürür).
class MeetingFormScreenV2 extends StatefulWidget {
  const MeetingFormScreenV2({super.key, this.existing});

  final MeetingV2? existing;

  @override
  State<MeetingFormScreenV2> createState() => _MeetingFormScreenV2State();
}

class _MeetingFormScreenV2State extends State<MeetingFormScreenV2> {
  FormController? _controller;
  late final AttachmentController _attachments;

  /// §4.3(c) — `toplanti_platformu` kategorisi yoksa (404) alan serbest
  /// metne düşer ve `Platform Adı` hiç gösterilmez.
  bool _platformLookupMissing = false;

  @override
  void initState() {
    super.initState();
    _attachments = AttachmentController(
      api: context.api2,
      entity: 'meetings',
      entityId: widget.existing?.id,
    );
    if (widget.existing != null) _attachments.loadExisting();
    _init();
  }

  /// Kategori önce yoklanır; 404 ise Platform alanı serbest metne düşer
  /// (kategori Tanımlar'dan eklenince dropdown kendiliğinden devreye girer —
  /// kod değişikliği gerekmez).
  Future<void> _init() async {
    try {
      await context.lookups.items('toplanti_platformu');
    } catch (_) {
      // yoklama başarısızsa dropdown denenir
    }
    if (!mounted) return;
    _platformLookupMissing =
        context.lookups.isCategoryMissing('toplanti_platformu');
    setState(_buildController);
  }

  void _buildController() {
    final api = context.api2;
    final cache = context.lookups;
    final m = widget.existing;
    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'meeting_type_id': m?.meetingTypeId,
        'meeting_date': m?.meetingDate,
        'method_id': m?.methodId,
        'location': m?.location,
        'platform_text': m?.platform,
        'org_unit_id': m?.orgUnitId,
        'participants': m?.participants,
        'participant_count': m?.participantCount?.toString(),
        'agenda': m?.agenda,
        'decision': m?.decision,
        'outcome': m?.outcome,
      },
      fields: [
        const FieldSpec(
          key: 'meeting_type_id',
          label: 'Toplantı Türü',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_turu',
          required: true,
          requiredMessage: S2.vToplantiYontemi,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'meeting_date',
          label: 'Tarih',
          type: FieldType.date,
          required: true,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'method_id',
          label: 'Toplantı Yöntemi',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_yontemi',
          required: true,
          requiredMessage: S2.vToplantiYontemi,
          section: FormSection.faaliyet,
        ),
        // Yüz Yüze dalı.
        const FieldSpec(
          key: 'location',
          label: 'Toplantı Yeri',
          type: FieldType.text,
          required: true,
          maxLength: 120,
          minLength: 3,
          requiredMessage: S2.vToplantiYeri,
          visibleWhen: VisibleWhen.code('method_id', 'yuz_yuze'),
          omitWhenHidden: true,
          section: FormSection.faaliyet,
        ),
        // Çevrim İçi dalı — seçilen öğenin ADI metin olarak `platform`a yazılır.
        if (!_platformLookupMissing) ...[
          const FieldSpec(
            key: 'platform_id',
            label: 'Platform',
            type: FieldType.lookup,
            lookupCategory: 'toplanti_platformu',
            required: true,
            requiredMessage: S2.vPlatform,
            visibleWhen: VisibleWhen.code('method_id', 'cevrim_ici'),
            omitWhenHidden: true,
            section: FormSection.faaliyet,
          ),
          const FieldSpec(
            key: 'platform_name',
            label: 'Platform Adı',
            type: FieldType.text,
            required: true,
            maxLength: 60,
            requiredMessage: S2.vPlatformAdi,
            visibleWhen: VisibleWhen.code('platform_id', 'diger'),
            section: FormSection.faaliyet,
          ),
        ] else
          // 404 geri düşüşü: serbest metin, `Platform Adı` hiç gösterilmez.
          const FieldSpec(
            key: 'platform_text',
            label: 'Platform',
            type: FieldType.text,
            required: true,
            maxLength: 60,
            hint: 'Örn. Zoom, Microsoft Teams',
            requiredMessage: S2.vPlatform,
            visibleWhen: VisibleWhen.code('method_id', 'cevrim_ici'),
            omitWhenHidden: true,
            section: FormSection.faaliyet,
          ),
        FieldSpec(
          key: 'org_unit_id',
          label: 'Düzenleyen Teşkilat',
          type: FieldType.orgPicker,
          required: true,
          requiredMessage: S2.vDuzenleyenTeskilat,
          section: FormSection.konum,
          optionsBuilder: (_) => orgUnitOptions(api),
        ),
        const FieldSpec(
          key: 'participants',
          label: 'Katılımcılar',
          type: FieldType.multiline,
          maxLength: 500,
          hint: 'Örn. 12 kurul üyesi',
          section: FormSection.katilim,
        ),
        const FieldSpec(
          key: 'participant_count',
          label: 'Katılımcı Sayısı',
          type: FieldType.number,
          section: FormSection.katilim,
        ),
        const FieldSpec(
          key: 'agenda',
          label: 'Gündem',
          type: FieldType.multiline,
          required: true,
          maxLength: 2000,
          requiredMessage: S2.vGundem,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'decision',
          label: 'Alınan Kararlar',
          type: FieldType.multiline,
          required: true,
          maxLength: 2000,
          requiredMessage: S2.vKararlar,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'outcome',
          label: 'Sonuç',
          type: FieldType.multiline,
          maxLength: 1000,
          section: FormSection.aciklama,
        ),
        const FieldSpec(
          key: 'ek_tutanak',
          label: S2.ekTutanak,
          type: FieldType.attachment,
          attachmentKind: 'tutanak',
          section: FormSection.ekler,
        ),
        const FieldSpec(
          key: 'ek_sunum',
          label: S2.ekSunum,
          type: FieldType.attachment,
          attachmentKind: 'sunum',
          section: FormSection.ekler,
        ),
        const FieldSpec(
          key: 'ek_fotograf',
          label: S2.ekFotograf,
          type: FieldType.attachment,
          attachmentKind: 'fotograf',
          section: FormSection.ekler,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final controller = _controller!;
    final body = controller.buildBody();

    // `platform` API'de **serbest metin** sütunudur: seçilen öğenin adı yazılır.
    final onlineVisible = _platformLookupMissing
        ? controller.isVisibleKey('platform_text')
        : controller.isVisibleKey('platform_id');
    body.remove('platform_id');
    body.remove('platform_name');
    body.remove('platform_text');
    if (onlineVisible) {
      if (_platformLookupMissing) {
        body['platform'] = controller.stringValue('platform_text');
      } else {
        final selected = controller.selectedOption('platform_id');
        body['platform'] = selected?.effectiveCode == 'diger'
            ? controller.stringValue('platform_name')
            : selected?.label;
      }
    }

    final api = context.api2;
    if (widget.existing != null) {
      await api.updateMeeting(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariToplanti);
      return widget.existing!.id;
    }
    final id = await api.createMeeting(body);
    if (mounted) showAppSnackBar(context, S2.basariToplanti);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return FormScaffold(
      title: widget.existing == null
          ? 'Yeni Toplantı Kaydı'
          : 'Toplantı Kaydını Düzenle',
      controller: controller,
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
