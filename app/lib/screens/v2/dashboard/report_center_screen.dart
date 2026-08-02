import 'package:flutter/material.dart';

import '../../../core/download/file_saver.dart';
import '../../../core/strings_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';

/// Rapor tanımı — E-14 tablosu (docs/UX-V2.md §6.4).
class ReportDef {
  const ReportDef(this.name, this.subtitle, this.slug);

  final String name;
  final String subtitle;
  final String slug;
}

const kReports = <ReportDef>[
  ReportDef('Teşkilatlanma Raporu', 'Birim ve durum dağılımı', 'org-units'),
  ReportDef('Kişi Listesi', 'Tüm kayıtlı kişiler', 'persons'),
  ReportDef('Görevlendirmeler', 'Birim bazlı görev kayıtları', 'assignments'),
  ReportDef('Görev Faaliyetleri', 'Saha görev kayıtları', 'tasks'),
  ReportDef('Eğitimler', 'Eğitim kayıtları', 'trainings'),
  ReportDef('Etkinlikler', 'Etkinlik kayıtları', 'events'),
  ReportDef('Toplantılar', 'Toplantı kayıtları', 'meetings'),
  ReportDef('Lojistik Hareketleri', 'Talep, gönderi ve stok', 'field-activities'),
];

/// E-14 · Rapor Merkezi.
class ReportCenterScreen extends StatefulWidget {
  const ReportCenterScreen({super.key});

  @override
  State<ReportCenterScreen> createState() => _ReportCenterScreenState();
}

class _ReportCenterScreenState extends State<ReportCenterScreen> {
  String? _busySlug;

  /// §11 N-8 — PDF ucu 404 dönerse buton **gizlenir**; devre dışı gösterilmez.
  final Set<String> _pdfUnavailable = {};

  Future<void> _download(ReportDef def, {required bool pdf}) async {
    setState(() => _busySlug = '${def.slug}-${pdf ? 'pdf' : 'xlsx'}');
    try {
      if (pdf) {
        final bytes = await context.api2.exportPdf(def.slug, const {});
        if (bytes == null) {
          if (!mounted) return;
          setState(() {
            _pdfUnavailable.add(def.slug);
            _busySlug = null;
          });
          return;
        }
        await saveDownloadedFile(bytes, '${def.slug}.pdf');
      } else {
        final bytes = await context.api2.exportXlsx(def.slug, const {});
        await saveDownloadedFile(bytes, '${def.slug}.xlsx');
      }
      if (!mounted) return;
      showAppSnackBar(context, S2.raporIndirildi);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, S2.raporIndirilemedi);
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S2.raporMerkezi)),
      body: ListView(
        children: [
          InfoBlockHeader(blockKey: 'raporlama.genel', api: context.api2),
          const SizedBox(height: s8),
          for (final def in kReports)
            Padding(
              padding: const EdgeInsets.fromLTRB(s16, 0, s16, s12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(s16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(def.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: s4),
                            Text(def.subtitle,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: kTextSecondary)),
                          ],
                        ),
                      ),
                      _ExportButton(
                        icon: Icons.table_view_outlined,
                        color: kSuccess,
                        label: 'Excel',
                        busy: _busySlug == '${def.slug}-xlsx',
                        onPressed: () => _download(def, pdf: false),
                      ),
                      if (!_pdfUnavailable.contains(def.slug))
                        _ExportButton(
                          icon: Icons.picture_as_pdf_outlined,
                          color: kError,
                          label: 'PDF',
                          busy: _busySlug == '${def.slug}-pdf',
                          onPressed: () => _download(def, pdf: true),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(s16),
            child: Text(S2.raporFiltreNotu,
                style: TextStyle(fontSize: 12, color: kTextSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, color: color),
    );
  }
}
