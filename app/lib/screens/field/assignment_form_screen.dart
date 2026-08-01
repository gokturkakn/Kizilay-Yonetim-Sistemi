import 'package:flutter/material.dart';
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
import 'person_picker_screen.dart';

/// Atama Formu — UX §3.17. `saha` rolü için salt okunur detay.
class AssignmentFormScreen extends StatefulWidget {
  const AssignmentFormScreen(
      {super.key, this.assignment, this.readOnly = false});

  final Assignment? assignment;
  final bool readOnly;

  bool get isEdit => assignment != null;

  @override
  State<AssignmentFormScreen> createState() =>
      _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  String? _personName;
  int? _personId;
  DateTime? _date;
  String _status = 'atandi';

  bool _saving = false;
  String? _personError;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _title = TextEditingController(text: a?.title ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _personId = a?.personId;
    _personName = a?.personName;
    _date = a == null
        ? DateTime.now()
        : Formats.parseApiDate(a.assignedDate) ?? DateTime.now();
    _status = a?.status ?? 'atandi';
    if (a != null && _personName == null) _resolvePersonName(a.personId);
  }

  Future<void> _resolvePersonName(int personId) async {
    try {
      final p = await context.read<Api>().personById(personId);
      if (mounted) setState(() => _personName = p.fullName);
    } catch (_) {
      // ad çözülemedi — "—" gösterilir
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPerson() async {
    final selected =
        await Navigator.of(context).push<Person>(MaterialPageRoute(
      builder: (_) => const PersonPickerScreen(),
    ));
    if (selected != null && mounted) {
      setState(() {
        _personId = selected.id;
        _personName = selected.fullName;
        _personError = null;
      });
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
      _personError = _personId == null ? 'Kişi seçin.' : null;
      _dateError = _date == null ? 'Tarih seçin.' : null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || _personId == null || _date == null) return;

    final api = context.read<Api>();
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'person_id': _personId,
      'title': _title.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'assigned_date': Formats.apiDate(_date!),
      'status': _status,
    };
    try {
      if (widget.isEdit) {
        await api.updateAssignment(widget.assignment!.id, body);
      } else {
        await api.createAssignment(body);
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Atama kaydedildi.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, errorMessage(e));
    }
  }

  String get _screenTitle {
    if (widget.readOnly) return 'Görev Ataması';
    return widget.isEdit ? 'Atamayı Düzenle' : 'Yeni Görev Ataması';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refData = context.read<RefData>();
    final assignment = widget.assignment;
    final personLabel = _personName ??
        (assignment != null
            ? refData.assignmentPersonName(assignment)
            : '');
    final locked = widget.readOnly;
    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(s16),
            children: [
              InkWell(
                onTap: locked ? null : _pickPerson,
                borderRadius: BorderRadius.circular(r8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Kişi',
                    errorText: _personError,
                    suffixIcon: locked
                        ? null
                        : const Icon(Icons.search,
                            color: kTextSecondary),
                  ),
                  child: Text(
                    personLabel,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _title,
                readOnly: locked,
                decoration:
                    const InputDecoration(labelText: 'Görev Başlığı'),
                validator: (v) =>
                    Validators.required(v, 'Görev başlığı gerekli.'),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _description,
                readOnly: locked,
                decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)'),
                maxLines: 3,
              ),
              const SizedBox(height: s16),
              InkWell(
                onTap: locked ? null : _pickDate,
                borderRadius: BorderRadius.circular(r8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Atama Tarihi',
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
              const SizedBox(height: s24),
              Text('Durum', style: theme.textTheme.titleSmall),
              const SizedBox(height: s8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'atandi', label: Text(Str.atandi)),
                  ButtonSegment(
                      value: 'devam', label: Text(Str.devam)),
                  ButtonSegment(
                      value: 'tamamlandi',
                      label: Text(Str.tamamlandi)),
                ],
                selected: {_status},
                onSelectionChanged: locked
                    ? null
                    : (sel) => setState(() => _status = sel.first),
              ),
              if (!locked) ...[
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
              ],
              const SizedBox(height: s16),
            ],
          ),
        ),
      ),
    );
  }
}
