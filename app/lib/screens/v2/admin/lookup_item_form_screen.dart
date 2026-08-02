import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../forms/form_controller.dart';
import '../../../models/models_v2.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-65 · Tanım Öğesi Formu — docs/UX-V2.md §6.5.
class LookupItemFormScreen extends StatefulWidget {
  const LookupItemFormScreen({
    super.key,
    required this.category,
    this.existing,
    this.parentOptions = const [],
  });

  final LookupCategory category;
  final LookupItem? existing;
  final List<LookupItem> parentOptions;

  @override
  State<LookupItemFormScreen> createState() => _LookupItemFormScreenState();
}

class _LookupItemFormScreenState extends State<LookupItemFormScreen> {
  late final FormController _controller;

  bool get _isHierarchical => widget.category.code == 'alt_gorev';

  @override
  void initState() {
    super.initState();
    final cache = context.lookups;
    final item = widget.existing;
    _controller = FormController(
      lookupResolver: lookupResolverFor(cache),
      initialValues: {
        'name': item?.name,
        'code': item?.code,
        'parent_id': item?.parentId,
        'sort_order': item?.sortOrder.toString(),
        'is_active': item?.isActive ?? true,
      },
      fields: [
        const FieldSpec(
          key: 'name',
          label: 'Ad',
          type: FieldType.text,
          maxLength: 120,
          required: true,
          requiredMessage: S2.vAd,
        ),
        const FieldSpec(
          key: 'code',
          label: 'Kod',
          type: FieldType.text,
          maxLength: 40,
          helper: 'Boş bırakılırsa addan otomatik üretilir.',
        ),
        // Üst Tanım yalnız hiyerarşik kategorilerde (`alt_gorev`).
        if (_isHierarchical)
          const FieldSpec(
            key: 'parent_id',
            label: 'Üst Tanım',
            type: FieldType.picker,
            lookupCategory: 'gorev_turu',
            required: true,
            requiredMessage: S2.vUstTanim,
          ),
        const FieldSpec(
          key: 'sort_order',
          label: 'Sıra',
          type: FieldType.number,
          helper: 'Boş bırakılırsa listenin sonuna eklenir.',
        ),
        const FieldSpec(
          key: 'is_active',
          label: 'Durum',
          type: FieldType.segment,
          required: true,
          defaultValue: true,
        ),
      ],
    );
    _controller.seedOptions('is_active', const [
      FormOption(value: true, label: S2.aktif, code: 'aktif'),
      FormOption(value: false, label: S2.pasif, code: 'pasif'),
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _codePattern = RegExp(r'^[a-z0-9_]+$');

  Future<int?> _save() async {
    final code = _controller.stringValue('code');
    if (code != null && !_codePattern.hasMatch(code)) {
      _controller.setServerError('code', S2.vKodBicim);
      throw StateError(S2.vKodBicim);
    }
    final body = <String, dynamic>{
      'category_code': widget.category.code,
      'name': _controller.stringValue('name'),
      'code': ?code,
      if (_isHierarchical) 'parent_id': _controller.intValue('parent_id'),
      if (_controller.stringValue('sort_order') != null)
        'sort_order': _controller.intValue('sort_order'),
      'is_active': _controller.value('is_active') == true,
    };
    try {
      if (widget.existing != null) {
        await context.api2.updateLookupItem(widget.existing!.id, body);
      } else {
        await context.api2.createLookupItem(body);
      }
    } on ApiException catch (e) {
      if (e.isConflict) {
        _controller.setServerError('code', S2.vKodCakisma);
      }
      rethrow;
    }
    if (mounted) showAppSnackBar(context, S2.basariTanim);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Yeni Tanım' : 'Tanımı Düzenle',
      controller: _controller,
      onSave: _save,
    );
  }
}
