import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/ref_data.dart';
import '../../core/strings.dart';
import '../../core/validators.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Kişi Formu (yeni/düzenle) — UX §3.9.
class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({
    super.key,
    this.person,
    this.initialProvinceId,
    this.initialDistrictId,
    this.initialUnitType,
  });

  final Person? person;
  final int? initialProvinceId;
  final int? initialDistrictId;
  final String? initialUnitType;

  bool get isEdit => person != null;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _tcNo;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _profession;

  DateTime? _birthDate;
  String _unitType = 'il_teskilati';
  int? _provinceId;
  int? _districtId;
  bool _isActive = true;

  List<Province> _provinces = [];
  List<District> _districts = [];
  bool _loadingDistricts = false;

  bool _saving = false;
  bool _dirty = false;
  String? _birthDateError;
  String? _tcServerError;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName = TextEditingController(text: p?.lastName ?? '');
    _tcNo = TextEditingController(text: p?.tcNo ?? '');
    _phone = TextEditingController(
        text: p == null ? '' : _maskedPhone(p.phone));
    _email = TextEditingController(text: p?.email ?? '');
    _profession = TextEditingController(text: p?.profession ?? '');
    _birthDate = Formats.parseApiDate(p?.birthDate);
    _unitType = p?.unitType ?? widget.initialUnitType ?? 'il_teskilati';
    _provinceId = p?.provinceId ?? widget.initialProvinceId;
    _districtId = p?.districtId ?? widget.initialDistrictId;
    _isActive = p?.isActive ?? true;
    _loadProvinces();
    if (_provinceId != null && _unitType == 'ilce_teskilati') {
      _loadDistricts(_provinceId!);
    }
  }

  String _maskedPhone(String stored) {
    final digits = Formats.phoneDigits(stored);
    if (digits.length != 11) return stored;
    return '0(${digits.substring(1, 4)}) ${digits.substring(4, 7)} '
        '${digits.substring(7, 9)} ${digits.substring(9, 11)}';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _tcNo.dispose();
    _phone.dispose();
    _email.dispose();
    _profession.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final list = await context.read<RefData>().provinces();
      if (mounted) setState(() => _provinces = list);
    } catch (_) {
      // dropdown boş kalır; kaydetme zaten il zorunluluğuna takılır
    }
  }

  Future<void> _loadDistricts(int provinceId) async {
    setState(() {
      _loadingDistricts = true;
      _districts = [];
    });
    try {
      final list = await context.read<RefData>().districtsOf(provinceId);
      if (mounted) {
        setState(() {
          _districts = list;
          _loadingDistricts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1980, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      locale: const Locale('tr'),
      confirmText: Str.tamam,
      cancelText: Str.vazgec,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _tcServerError = null;
      _birthDateError = _birthDate == null ? 'Doğum tarihi gerekli.' : null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || _birthDate == null) return;

    final api = context.read<Api>();
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'tc_no': _tcNo.text.trim(),
      'birth_date': Formats.apiDate(_birthDate!),
      'phone': Formats.phoneDigits(_phone.text),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'profession':
          _profession.text.trim().isEmpty ? null : _profession.text.trim(),
      'unit_type': _unitType,
      'province_id': _provinceId,
      'district_id':
          _unitType == 'ilce_teskilati' ? _districtId : null,
      'is_active': _isActive,
    };
    try {
      if (widget.isEdit) {
        await api.updatePerson(widget.person!.id, body);
      } else {
        await api.createPerson(body);
      }
      if (!mounted) return;
      _dirty = false;
      showAppSnackBar(context, 'Kişi kaydedildi.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if ((e.statusCode == 409 || e.statusCode == 400) &&
          (Formats.trLower(e.message).contains('tc') ||
              e.code.contains('tc'))) {
        setState(() => _tcServerError =
            'Bu TC kimlik numarası ile kayıtlı bir kişi zaten var.');
        _formKey.currentState!.validate();
      } else if (e.isForbidden) {
        showAppSnackBar(context, Str.hataYetki);
      } else if (e.isNetwork) {
        showAppSnackBar(context, Str.hataAg);
      } else {
        showAppSnackBar(context, 'Kayıt başarısız. Lütfen tekrar deneyin.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Kayıt başarısız. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _confirmExit() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text(
            'Bu sayfadan çıkarsanız girdiğiniz bilgiler silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Str.vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDistrict = _unitType == 'ilce_teskilati';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Kişiyi Düzenle' : 'Yeni Kişi'),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: _markDirty,
            child: ListView(
              padding: const EdgeInsets.all(s16),
              children: [
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Ad'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.required(v, 'Ad gerekli.'),
                ),
                const SizedBox(height: s16),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      Validators.required(v, 'Soyad gerekli.'),
                ),
                const SizedBox(height: s16),
                TextFormField(
                  controller: _tcNo,
                  decoration:
                      const InputDecoration(labelText: 'TC Kimlik No'),
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (v) {
                    if (_tcServerError != null) return _tcServerError;
                    return Validators.tcNo(v);
                  },
                  onChanged: (_) {
                    if (_tcServerError != null) {
                      setState(() => _tcServerError = null);
                    }
                  },
                ),
                const SizedBox(height: s16),
                // Doğum Tarihi
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(r8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Doğum Tarihi',
                      errorText: _birthDateError,
                      suffixIcon: const Icon(Icons.calendar_today_outlined,
                          color: kTextSecondary),
                    ),
                    child: Text(
                      _birthDate == null
                          ? ''
                          : Formats.date(_birthDate!),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: s16),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: '0(5XX) XXX XX XX',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [TrPhoneInputFormatter()],
                  validator: Validators.phone,
                ),
                const SizedBox(height: s16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.optionalEmail,
                ),
                const SizedBox(height: s16),
                TextFormField(
                  controller: _profession,
                  decoration: const InputDecoration(labelText: 'Meslek'),
                ),
                const SizedBox(height: s24),
                Text('Birim Türü', style: theme.textTheme.titleSmall),
                const SizedBox(height: s8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'il_teskilati',
                        label: Text(Str.birimIl)),
                    ButtonSegment(
                        value: 'ilce_teskilati',
                        label: Text(Str.birimIlce)),
                    ButtonSegment(
                        value: 'temsilcilik',
                        label: Text(Str.birimTemsilcilik)),
                  ],
                  selected: {_unitType},
                  onSelectionChanged: (sel) {
                    setState(() {
                      _unitType = sel.first;
                      if (_unitType != 'ilce_teskilati') {
                        _districtId = null;
                      } else if (_provinceId != null) {
                        _loadDistricts(_provinceId!);
                      }
                      _dirty = true;
                    });
                  },
                ),
                const SizedBox(height: s16),
                DropdownButtonFormField<int>(
                  initialValue: _provinceId,
                  decoration: const InputDecoration(labelText: 'İl'),
                  items: [
                    for (final p in _provinces)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _provinceId = v;
                      _districtId = null; // il değişince ilçe sıfırlanır
                      _dirty = true;
                    });
                    if (v != null && _unitType == 'ilce_teskilati') {
                      _loadDistricts(v);
                    }
                  },
                  validator: (v) => v == null ? 'İl seçin.' : null,
                ),
                if (showDistrict) ...[
                  const SizedBox(height: s16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('district-$_provinceId'),
                    initialValue: _districts
                            .any((d) => d.id == _districtId)
                        ? _districtId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'İlçe',
                      suffixIcon: _loadingDistricts
                          ? const Padding(
                              padding: EdgeInsets.all(s12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    items: [
                      for (final d in _districts)
                        DropdownMenuItem(
                            value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _districtId = v;
                        _dirty = true;
                      });
                    },
                    validator: (v) => v == null ? 'İlçe seçin.' : null,
                  ),
                ],
                const SizedBox(height: s24),
                Card(
                  child: SwitchListTile(
                    title: const Text(Str.aktif),
                    value: _isActive,
                    activeThumbColor: Colors.white,
                    activeTrackColor: kSuccess,
                    onChanged: (v) {
                      setState(() {
                        _isActive = v;
                        _dirty = true;
                      });
                    },
                  ),
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
      ),
    );
  }
}
