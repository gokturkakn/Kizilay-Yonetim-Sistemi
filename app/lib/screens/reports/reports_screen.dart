import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/download/file_saver.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'audit_log_screen.dart';

/// Raporlar — UX §3.18 (yalnız `genel_merkez`).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ExportSpec {
  const _ExportSpec(this.title, this.subtitle, this.endpointName);

  final String title;
  final String subtitle;
  final String endpointName; // /export/{name}.xlsx
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _exports = [
    _ExportSpec(
        'Kişi Listesi', 'Tüm kayıtlı kişiler (.xlsx)', 'persons'),
    _ExportSpec('Saha Faaliyetleri', 'Görev formu kayıtları (.xlsx)',
        'field-activities'),
    _ExportSpec('Yönetsel Faaliyetler',
        'Kurul ve komisyon toplantıları (.xlsx)', 'meetings'),
    _ExportSpec(
        'Görev Atamaları', 'Atama kayıtları (.xlsx)', 'assignments'),
  ];

  final Set<String> _downloading = {};

  Future<void> _download(_ExportSpec spec) async {
    if (_downloading.contains(spec.endpointName)) return;
    setState(() => _downloading.add(spec.endpointName));
    final api = context.read<Api>();
    try {
      final bytes = await api.exportXlsx(spec.endpointName);
      await saveDownloadedFile(bytes, '${spec.endpointName}.xlsx');
      if (mounted) showAppSnackBar(context, 'Rapor indirildi.');
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Rapor indirilemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _downloading.remove(spec.endpointName));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.all(s16),
        children: [
          Text('Excel Raporları', style: theme.textTheme.titleSmall),
          const SizedBox(height: s8),
          for (final spec in _exports) ...[
            Card(
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r12),
                ),
                leading:
                    const Icon(Icons.table_view_outlined, color: kSuccess),
                title:
                    Text(spec.title, style: theme.textTheme.titleMedium),
                subtitle: Text(
                  spec.subtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kTextSecondary),
                ),
                trailing: _downloading.contains(spec.endpointName)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.download, color: kTextSecondary),
                onTap: () => _download(spec),
              ),
            ),
            const SizedBox(height: s8),
          ],
          const SizedBox(height: s16),
          Text('Kayıt Takibi', style: theme.textTheme.titleSmall),
          const SizedBox(height: s8),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r12),
              ),
              leading: const Icon(Icons.history, color: kPrimary),
              title: Text('Değişiklik Günlüğü',
                  style: theme.textTheme.titleMedium),
              subtitle: Text(
                'Kim, ne zaman, neyi değiştirdi',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kTextSecondary),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: kTextSecondary),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AuditLogScreen(),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
