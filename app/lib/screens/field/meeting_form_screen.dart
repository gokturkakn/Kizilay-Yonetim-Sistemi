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

/// Toplantı Formu — UX §3.15.
///
/// Kurul formunda `body_id` otomatik koordinasyon kuruludur; komisyon
/// formunda dropdown ile seçilir.
class MeetingFormScreen extends StatefulWidget {
  const MeetingFormScreen(
      {super.key, this.meeting, required this.isKurul});

  final Meeting? meeting;
  final bool isKurul;

  bool get isEdit => meeting != null;

  @override
  State<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends State<MeetingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _decision;
  late final TextEditingController _outcome;

  DateTime? _date;
  int? _bodyId;
  List<Body> _commissions = [];
  Body? _kurul;

  bool _saving = false;
  String? _dateError;
  String? _bodyError;

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _decision = TextEditingController(text: m?.decision ?? '');
    _outcome = TextEditingController(text: m?.outcome ?? '');
    _date = m == null ? null : Formats.parseApiDate(m.meetingDate);
    _bodyId = m?.bodyId;
    _loadBodies();
  }

  @override
  void dispose() {
    _decision.dispose();
    _outcome.dispose();
    super.dispose();
  }

  Future<void> _loadBodies() async {
    try {
      final refData = context.read<RefData>();
      final bodies = await refData.bodies();
      if (!mounted) return;
      setState(() {
        _kurul = bodies.where((b) => b.isKurul).firstOrNull;
        _commissions =
            bodies.where((b) => b.type == 'komisyon').toList();
        if (widget.isKurul) _bodyId = _kurul?.id;
      });
    } catch (_) {
      // yüklenemezse kaydetme doğrulamaya takılır
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
    if (widget.isKurul) _bodyId ??= _kurul?.id;
    setState(() {
      _dateError = _date == null ? 'Tarih seçin.' : null;
      _bodyError =
          !widget.isKurul && _bodyId == null ? 'Komisyon seçin.' : null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || _date == null || _bodyId == null) return;

    final api = context.read<Api>();
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'body_id': _bodyId,
      'meeting_date': Formats.apiDate(_date!),
      'decision': _decision.text.trim(),
      'outcome': _outcome.text.trim(),
    };
    try {
      if (widget.isEdit) {
        await api.updateMeeting(widget.meeting!.id, body);
      } else {
        await api.createMeeting(body);
      }
      if (!mounted) return;
      showAppSnackBar(context, 'Toplantı kaydedildi.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, errorMessage(e));
    }
  }

  String get _title {
    if (widget.isEdit) return 'Toplantıyı Düzenle';
    return widget.isKurul
        ? 'Yeni Kurul Toplantısı'
        : 'Yeni Komisyon Toplantısı';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(s16),
            children: [
              if (!widget.isKurul) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey('body-${_commissions.length}'),
                  initialValue:
                      _commissions.any((b) => b.id == _bodyId)
                          ? _bodyId
                          : null,
                  decoration: InputDecoration(
                    labelText: 'Komisyon',
                    errorText: _bodyError,
                  ),
                  items: [
                    for (final b in _commissions)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _bodyId = v;
                    _bodyError = null;
                  }),
                ),
                const SizedBox(height: s16),
              ],
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(r8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Toplantı Tarihi',
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
                controller: _decision,
                decoration:
                    const InputDecoration(labelText: 'Toplantı Kararı'),
                maxLines: 3,
                validator: (v) =>
                    Validators.required(v, 'Toplantı kararını girin.'),
              ),
              const SizedBox(height: s16),
              TextFormField(
                controller: _outcome,
                decoration: const InputDecoration(labelText: 'Sonuç'),
                maxLines: 3,
                validator: (v) =>
                    Validators.required(v, 'Sonucu girin.'),
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
