import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// E-68 · Sistem Ayarları — docs/UX-V2.md §6.5.
///
/// Dosya kısıtları sunucuda sabittir; düzenlenemeyen alan **giriş kutusu
/// olarak gösterilmez** (etiket + değer satırı).
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _orgName = TextEditingController(text: 'Türk Kızılay Kadın Teşkilatı');

  @override
  void dispose() {
    _orgName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget readonlyRow(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: s8),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: kTextSecondary)),
              ),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sistem Ayarları')),
      body: ListView(
        padding: const EdgeInsets.all(s16),
        children: [
          Text('Kurum Bilgileri', style: theme.textTheme.titleSmall),
          const SizedBox(height: s8),
          TextField(
            controller: _orgName,
            decoration:
                const InputDecoration(labelText: 'Kurum Adı', isDense: true),
          ),
          const SizedBox(height: s24),
          Text('Dosya Ayarları', style: theme.textTheme.titleSmall),
          readonlyRow('En Büyük Dosya Boyutu', '10 MB'),
          readonlyRow('İzin Verilen Dosya Türleri',
              'JPG, PNG, WEBP, GIF, PDF, DOCX, XLSX'),
          Text(S2.dosyaKisitSunucu,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: kTextSecondary)),
          const SizedBox(height: s24),
          Text('Sistem Bilgisi', style: theme.textTheme.titleSmall),
          readonlyRow('Sürüm', '2.0.0'),
          readonlyRow('Veritabanı Durumu', 'Bağlı'),
          readonlyRow('Son Yedekleme', S2.kayitYok),
          const SizedBox(height: s24),
          FilledButton(
            onPressed: () => showAppSnackBar(context, S2.basariAyarlar),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
