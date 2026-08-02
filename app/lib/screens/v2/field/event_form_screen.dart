import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/attachments.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'calendar_event_picker_screen.dart';

/// E-46 · Etkinlik Formu — docs/UX-V2.md §6.2, §4.3(e).
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.existing});

  final EventRecord? existing;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  late final FormController _controller;
  late final AttachmentController _attachments;
  CalendarEvent? _selectedEvent;
  String? _lastYear;

  @override
  void initState() {
    super.initState();
    final api = context.api2;
    final cache = context.lookups;
    final e = widget.existing;

    _attachments =
        AttachmentController(api: api, entity: 'events', entityId: e?.id);
    if (e != null) _attachments.loadExisting();

    _controller = FormController(
      roleIsSaha: context.isSaha,
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'event_date': e?.eventDate ?? Formats.apiDate(DateTime.now()),
        'event_type_id': e?.eventTypeId,
        'calendar_event_id': e?.calendarEventId,
        'region_id': e?.regionId,
        'province_id': e?.provinceId,
        'org_unit_id': e?.orgUnitId,
        'participant_count': e?.participantCount.toString(),
        'volunteer_count': e?.volunteerCount.toString(),
        'beneficiary_count': e?.beneficiaryCount.toString(),
        'notes': e?.notes,
      },
      fields: [
        FieldSpec(
          key: 'event_date',
          label: 'Tarih',
          type: FieldType.date,
          required: true,
          noFutureDates: true,
          section: FormSection.faaliyet,
          defaultValue: Formats.apiDate(DateTime.now()),
        ),
        const FieldSpec(
          key: 'event_type_id',
          label: 'Etkinlik Türü',
          type: FieldType.lookup,
          lookupCategory: 'etkinlik_turu',
          requiredMessage: S2.vEtkinlikTuru,
          section: FormSection.faaliyet,
        ),
        const FieldSpec(
          key: 'calendar_event_id',
          label: 'Etkinlik Adı',
          type: FieldType.picker,
          required: true,
          requiredMessage: S2.vEtkinlikAdi,
          section: FormSection.faaliyet,
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
          key: 'beneficiary_count',
          label: 'Yararlanıcı Sayısı',
          type: FieldType.number,
          required: true,
          requiredMessage: S2.vYararlaniciSayisi,
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
    if (e?.calendarEventId != null) {
      _controller.seedOptions('calendar_event_id', [
        FormOption(
            value: e!.calendarEventId!, label: e.calendarEventName ?? ''),
      ]);
    }
    _lastYear = _yearOf(_controller.stringValue('event_date'));
    _controller.addListener(_onYearMaybeChanged);
  }

  String? _yearOf(String? apiDate) {
    final d = DateTime.tryParse(apiDate ?? '');
    return d?.year.toString();
  }

  /// §4.3(e) — Tarih değişince ve seçili etkinliğin o yıl karşılığı yoksa
  /// Etkinlik Adı temizlenir ve kullanıcıya **söylenir** (R1.3'ün tek istisnası).
  void _onYearMaybeChanged() {
    final year = _yearOf(_controller.stringValue('event_date'));
    if (year == _lastYear) return;
    _lastYear = year;
    if (_controller.value('calendar_event_id') == null) return;
    _controller.setValue('calendar_event_id', null);
    _selectedEvent = null;
    if (mounted) showAppSnackBar(context, S2.etkinlikListesiGuncellendi);
  }

  @override
  void dispose() {
    _controller.removeListener(_onYearMaybeChanged);
    _controller.dispose();
    _attachments.dispose();
    super.dispose();
  }

  Future<void> _pickCalendarEvent() async {
    final date =
        DateTime.tryParse(_controller.stringValue('event_date') ?? '') ??
            DateTime.now();
    final typeCode = _controller.selectedOption('event_type_id')?.code;
    final picked = await Navigator.of(context).push<CalendarEvent>(
      MaterialPageRoute(
        builder: (_) => CalendarEventPickerScreen(
          year: date.year,
          categoryCode: typeCode,
        ),
      ),
    );
    if (picked == null) return;
    _selectedEvent = picked;
    _controller.seedOptions('calendar_event_id', [
      FormOption(value: picked.id, label: picked.name, code: picked.category),
    ]);
    _controller.markTouched('calendar_event_id');
    _controller.setValue('calendar_event_id', picked.id);
  }

  Future<int?> _save() async {
    final body = _controller.buildBody();
    final api = context.api2;
    if (widget.existing != null) {
      await api.updateEvent(widget.existing!.id, body);
      if (mounted) showAppSnackBar(context, S2.basariEtkinlik);
      return widget.existing!.id;
    }
    final id = await api.createEvent(body);
    if (mounted) showAppSnackBar(context, S2.basariEtkinlik);
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null
          ? 'Yeni Etkinlik Kaydı'
          : 'Etkinlik Kaydını Düzenle',
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
        // Etkinlik Adı: readOnly, klavye **hiçbir koşulda** açılmaz (R6).
        if (spec.key == 'calendar_event_id') {
          final selected = controller.selectedOption(spec.key);
          final error = controller.displayError(spec);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spec.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: kTextSecondary)),
              const SizedBox(height: s4),
              InkWell(
                onTap: _pickCalendarEvent,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixIcon:
                        Icon(Icons.chevron_right, color: kTextSecondary),
                  ),
                  child: Text(
                    selected?.label ?? _selectedEvent?.name ?? Str.secilmedi,
                    style: TextStyle(
                      color: selected == null ? kTextDisabled : kTextPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: s4),
                  child: Text(error,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kError)),
                ),
            ],
          );
        }
        return null;
      },
    );
  }
}
