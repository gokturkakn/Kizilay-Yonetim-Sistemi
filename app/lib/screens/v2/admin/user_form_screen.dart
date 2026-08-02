import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/strings_v2.dart';
import '../../../core/validators.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';

/// E-62 · Kullanıcı Formu — docs/UX-V2.md §6.5.
class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.existing});

  final UserAccount? existing;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  late final FormController _controller;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final cache = context.lookups;
    final u = widget.existing;
    _controller = FormController(
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'name': u?.name,
        'email': u?.email,
        'role': u?.role ?? 'saha',
        'region_id': u?.regionId,
        'province_id': u?.provinceId,
        'is_active': u?.isActive ?? true,
      },
      fields: [
        const FieldSpec(
          key: 'name',
          label: 'Ad Soyad',
          type: FieldType.text,
          required: true,
          requiredMessage: S2.vAdSoyad,
        ),
        const FieldSpec(
          key: 'email',
          label: 'E-posta',
          type: FieldType.email,
          required: true,
          requiredMessage: 'E-posta adresi gerekli.',
        ),
        const FieldSpec(
          key: 'role',
          label: 'Rol',
          type: FieldType.segment,
          required: true,
          defaultValue: 'saha',
        ),
        FieldSpec(
          key: 'region_id',
          label: 'Kapsam — Bölge',
          type: FieldType.lookup,
          emptyOptionLabel: 'Tüm bölgeler',
          helper: 'Boş bırakılırsa kullanıcı tüm bölgeleri görür.',
          optionsBuilder: (_) => regionOptions(cache),
        ),
        FieldSpec(
          key: 'province_id',
          label: 'Kapsam — İl',
          type: FieldType.picker,
          parentKey: 'region_id',
          emptyOptionLabel: 'Tüm iller',
          optionsBuilder: (values) => provinceOptions(cache, values),
        ),
        const FieldSpec(
          key: 'is_active',
          label: 'Durum',
          type: FieldType.segment,
          required: true,
          defaultValue: true,
        ),
        // Şifre yalnız yeni kayıtta gösterilir; düzenlemede `Şifre Belirle`.
        if (_isNew)
          const FieldSpec(
            key: 'password',
            label: 'Şifre',
            type: FieldType.password,
            required: true,
            minLength: 8,
            requiredMessage: S2.vSifreKisa,
          ),
      ],
    );
    _controller.seedOptions('role', const [
      FormOption(value: 'genel_merkez', label: 'Genel Merkez'),
      FormOption(value: 'saha', label: 'Saha'),
    ]);
    _controller.seedOptions('is_active', const [
      FormOption(value: true, label: S2.aktif),
      FormOption(value: false, label: S2.pasif),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<int?> _save() async {
    final email = _controller.stringValue('email') ?? '';
    if (!Validators.isValidEmail(email)) {
      _controller.setServerError('email', 'Geçerli bir e-posta adresi girin.');
      throw StateError('email');
    }
    final api = context.api2;
    final body = <String, dynamic>{
      'name': _controller.stringValue('name'),
      'email': email,
      'role': _controller.value('role'),
      'region_id': _controller.intValue('region_id'),
      'province_id': _controller.intValue('province_id'),
      if (_isNew) 'password': _controller.stringValue('password'),
    };
    try {
      if (_isNew) {
        await api.createUser(body);
      } else {
        await api.updateUser(widget.existing!.id, body);
        final active = _controller.value('is_active') == true;
        if (active != widget.existing!.isActive) {
          await api.setUserActive(widget.existing!.id, active);
        }
      }
    } on ApiException catch (e) {
      if (e.isConflict) {
        _controller.setServerError('email', S2.epostaCakisma);
      }
      rethrow;
    }
    if (mounted) showAppSnackBar(context, S2.basariKullanici);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _isNew ? 'Yeni Kullanıcı' : 'Kullanıcıyı Düzenle',
      controller: _controller,
      onSave: _save,
      // Yöneticiye olmayan bir güvence verilmez (§6.5, API-V2 §11 notu).
      footer: const NoticeCard(text: S2.kapsamUyari),
    );
  }
}
