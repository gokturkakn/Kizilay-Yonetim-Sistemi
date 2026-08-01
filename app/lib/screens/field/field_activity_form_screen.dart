import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/formatters.dart';
import '../../core/session.dart';
import '../../core/ref_data.dart';
import '../../core/strings.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Görev Formu (saha faaliyeti, yeni/düzenle) — UX §3.13.
class FieldActivityFormScreen extends StatefulWidget {
  const FieldActivityFormScreen({super.key, this.activity});

  final FieldActivity? activity;

  bool get isEdit => activity != null;

  @override
  State<FieldActivityFormScreen> createState() =>
      _FieldActivityFormScreenState();
}

class _FieldActivityFormScreenState
    extends State<FieldActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _volunteerCount;
  late final TextEditingController _beneficiaryCount;
  late final TextEditingController _notes;

  int? _taskAreaId;
  DateTime? _date;
  int? _provinceId;
  int? _districtId;

  List<TaskArea> _taskAreas = [];
  List<Province> _provinces = [];
  List<District> _districts = [];

  bool _saving = false;
  String? _taskAreaError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _volunteerCount = TextEditingController(
        text: a == null ? '' : '${a.volunteerCount}');
    _beneficiaryCount = TextEditingController(
        text: a == null ? '' : '${a.beneficiaryCount}');
    _notes = TextEditingController(text: a?.notes ?? '');
    _taskAreaId = a?.taskAreaId;
    _date = a == null
        ? DateTime.now()
        : (Formats.parseApiDate(a.activityDate) ?? DateTime.now());
    _provinceId = a?.provinceId;
    _districtId = a?.districtId;
    _loadRefs();
  }

  @override
  void dispose() {
    _volunteerCount.dispose();
    _beneficiaryCount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    final refData = context.read<RefData>();
    try {
      final areas = await refData.taskAreas();
      final provinces = await refData.provinces();
      if (!mounted) return;
      setState(() {
        _taskAreas = areas.where((t) => t.isActive).toList();
        _provinces = provinces;
      });
      if (_provinceId != null) await _loadDistricts(_provinceId!);
    } catch (_) {
      // referans veri yüklenemedi; kaydetme doğrulamaya takılır
    }
  }

  Future<void> _loadDistricts(int provinceId) async {
    try {
      final list =
          await context.read<RefData>().districtsOf(provinceId);
      if (mounted) setState(() => _districts = list);
    } catch (_) {
      if (mounted) setState(() => _districts = []);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      locale: const Locale('tr'),
      confirmText: Str.tamam,
      cancelText: Str.vazgec,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _taskAreaError = _taskAreaId == null ? 'Görev alanı seçin.' : null;
      _dateError = _date == null ? 'Tarih seçin.' : null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || _taskAreaId == null || _date == null) return;

    final api = context.read<Api>();
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'task_area_id': _taskAreaId,
      'activity_date': Formats.apiDate(_date!),
      'volunteer_count': int.parse(_volunteerCount.text.trim()),
      'beneficiary_count': int.parse(_beneficiaryCount.text.trim()),
      'province_id': _provinceId,
      'district_id': _provinceId == null ? null : _districtId,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.isEdit) {
        await api.updateFieldActivity(widget.activity!.id, body);
      } else {
        await api.createFieldActivity(body);
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Faaliyet kaydedildi.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isEdit ? 'Görev Formunu Düzenle' : 'Yeni Görev Formu'),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(s16),
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey('task-area-${_taskAreas.length}'),
                initialValue:
                    _taskAreas.any((t) => t.id == _taskAreaId)
                        ? _taskAreaId
                        : null,
                decoration: InputDecoration(
                  labelText: 'Görev Alanı',
                  errorText: _taskAreaError,
                ),
                items: [
                  for (final t in _taskAreas)
                    DropdownMenuItem(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() {
                  _taskAreaId = v;
                  _taskAreaError = null;
                }),
              ),
              const SizedBox(height: s16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(r8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tarih',
                    errorText: _dateError,
                    suffixIcon: const Icon(Icons.calendar_today_outlined,
                        color: kTextSecondary),
                  ),
                  child: Text(
                    _date == null ? '' : Formats.date(_date!),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _volunteerCount,
                decoration: const InputDecoration(
                    labelText: 'Katılan Gönüllü Sayısı'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    Validators.positiveCount(v, 'Gönüllü sayısı girin.'),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _beneficiaryCount,
                decoration:
                    const InputDecoration(labelText: 'Yararlanıcı Sayısı'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => Validators.positiveCount(
                    v, 'Yararlanıcı sayısı girin.'),
              ),
              const SizedBox(height: s16),
              DropdownButtonFormField<int?>(
                key: ValueKey('province-${_provinces.length}'),
                initialValue: _provinceId,
                decoration:
                    const InputDecoration(labelText: 'İl (isteğe bağlı)'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text(Str.secilmedi)),
                  for (final p in _provinces)
                    DropdownMenuItem<int?>(
                        value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) {
                  setState(() {
                    _provinceId = v;
                    _districtId = null;
                    _districts = [];
                  });
                  if (v != null) _loadDistricts(v);
                },
              ),
              const SizedBox(height: s16),
              DropdownButtonFormField<int?>(
                key: ValueKey('district-$_provinceId-${_districts.length}'),
                initialValue: _districts.any((d) => d.id == _districtId)
                    ? _districtId
                    : null,
                decoration: const InputDecoration(
                    labelText: 'İlçe (isteğe bağlı)'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text(Str.secilmedi)),
                  for (final d in _districts)
                    DropdownMenuItem<int?>(
                        value: d.id, child: Text(d.name)),
                ],
                onChanged: _provinceId == null
                    ? null
                    : (v) => setState(() => _districtId = v),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)'),
                maxLines: 3,
              ),
              const SizedBox(height: s32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: kOnPrimary,
                        ),
                      )
                    : const Text(Str.kaydet),
              ),
              const SizedBox(height: s16),
            ],
          ),
        ),
      ),
    );
  }
}
