import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';

/// E-67 · Bildirimler — docs/UX-V2.md §6.5.
///
/// Gönderim bu sürümde devre dışıdır; ayarlar kaydedilir. Kullanıcıya
/// çalışıyormuş gibi gösterilmez (§10/18).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _items = <(String, String)>[
    ('Yeni malzeme talebi', 'Bir teşkilat yeni talep açtığında bildirilir.'),
    ('Talep onaylandı', 'Talebiniz onaylandığında bildirilir.'),
    ('Gönderi teslim edildi', 'Teslim bilgisi girildiğinde bildirilir.'),
    ('Görev bitiş tarihi yaklaşan görevliler',
        'Görev bitişine 30 gün kalan görevliler için bildirilir.'),
    ('Teşkilat Yok durumuna düşen birim',
        'Bir birimde görevli kalmadığında bildirilir.'),
  ];

  final Map<int, bool> _values = {for (var i = 0; i < _items.length; i++) i: true};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListView(
        children: [
          const NoticeCard(text: S2.bildirimDevreDisi),
          for (var i = 0; i < _items.length; i++)
            SwitchListTile(
              title: Text(_items[i].$1, style: theme.textTheme.titleMedium),
              subtitle: Text(_items[i].$2,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kTextSecondary)),
              value: _values[i] ?? false,
              onChanged: (v) => setState(() => _values[i] = v),
            ),
          Padding(
            padding: const EdgeInsets.all(s16),
            child: FilledButton(
              onPressed: () => showAppSnackBar(context, S2.basariBildirimAyar),
              child: const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
