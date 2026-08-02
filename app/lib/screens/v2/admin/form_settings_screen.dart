import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// E-69 · Form Yönetimi — docs/UX-V2.md §6.5.
class FormSettingsScreen extends StatefulWidget {
  const FormSettingsScreen({super.key});

  @override
  State<FormSettingsScreen> createState() => _FormSettingsScreenState();
}

class _FieldSetting {
  _FieldSetting(this.name, {this.required = false, this.locked = false});

  final String name;
  bool visible = true;
  bool required;

  /// Sistemin çalışması için gereken alanlar (tarih, konum, tür).
  final bool locked;
}

class _FormSettingsScreenState extends State<FormSettingsScreen> {
  static const _forms = [
    'Görev Formu',
    'Eğitim Formu',
    'Etkinlik Formu',
    'Toplantı Formu',
    'Kişi Formu',
    'Talep Formu',
    'Gönderi Formu',
  ];

  String _selected = _forms.first;
  late final Map<String, List<_FieldSetting>> _settings = {
    for (final f in _forms) f: _fieldsFor(f),
  };

  List<_FieldSetting> _fieldsFor(String form) {
    switch (form) {
      case 'Görev Formu':
        return [
          _FieldSetting('Tarih', required: true, locked: true),
          _FieldSetting('Bölge', required: true, locked: true),
          _FieldSetting('İl', required: true, locked: true),
          _FieldSetting('İlçe'),
          _FieldSetting('Şube'),
          _FieldSetting('Kadın Teşkilatı', required: true),
          _FieldSetting('Görev Türü', required: true, locked: true),
          _FieldSetting('Alt Görev', required: true),
          _FieldSetting('Gönüllü Sayısı', required: true),
          _FieldSetting('Yararlanıcı Sayısı', required: true),
          _FieldSetting('Süre (saat)', required: true),
          _FieldSetting('Açıklama'),
        ];
      case 'Toplantı Formu':
        return [
          _FieldSetting('Toplantı Türü', required: true, locked: true),
          _FieldSetting('Tarih', required: true, locked: true),
          _FieldSetting('Toplantı Yöntemi', required: true, locked: true),
          _FieldSetting('Düzenleyen Teşkilat', required: true),
          _FieldSetting('Katılımcılar'),
          _FieldSetting('Katılımcı Sayısı'),
          _FieldSetting('Gündem', required: true),
          _FieldSetting('Alınan Kararlar', required: true),
          _FieldSetting('Sonuç'),
        ];
      default:
        return [
          _FieldSetting('Tarih', required: true, locked: true),
          _FieldSetting('Bölge', required: true, locked: true),
          _FieldSetting('İl', required: true, locked: true),
          _FieldSetting('Açıklama'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _settings[_selected]!;
    return Scaffold(
      appBar: AppBar(title: const Text('Form Yönetimi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(s16),
            child: DropdownButtonFormField<String>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Form', isDense: true),
              items: [
                for (final f in _forms)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) => setState(() => _selected = v ?? _selected),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: fields.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = fields[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: s16, vertical: s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: theme.textTheme.titleMedium),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Görünür'),
                              value: f.visible,
                              onChanged: f.locked
                                  ? null
                                  : (v) => setState(() {
                                        f.visible = v;
                                        // Görünür kapanırsa Zorunlu da kapanır.
                                        if (!v) f.required = false;
                                      }),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Zorunlu'),
                              value: f.required,
                              onChanged: f.locked || !f.visible
                                  ? null
                                  : (v) => setState(() => f.required = v),
                            ),
                          ),
                        ],
                      ),
                      if (f.locked)
                        Text(S2.sistemAlanZorunlu,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(S2.formAyarNotu,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(height: s8),
                FilledButton(
                  onPressed: () =>
                      showAppSnackBar(context, S2.basariFormAyar),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
