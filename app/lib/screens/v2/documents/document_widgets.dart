/// Modül 6 · ortak görsel parçalar — SPEC-V2-M6 §5.2/§5.3.
library;

import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/download/file_saver.dart';
import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// Kapsam rozeti — metin **sunucudan** gelir (`scope_label`), istemcide
/// yeniden türetilmez (SPEC-V2-M6 §5 / API-V2 §19.5).
class ScopeBadge extends StatelessWidget {
  const ScopeBadge({super.key, required this.document});

  final DocumentRecord document;

  @override
  Widget build(BuildContext context) {
    final isGenel = document.scope == DocumentScope.genel;
    return StatusBadge(
      label: document.scopeLabel,
      foreground: isGenel ? kInactive : kInfo,
      background: isGenel ? kInactiveContainer : kInfoContainer,
    );
  }
}

/// "Süresi doldu" — `is_expired` sunucuda `date('now')` ile hesaplanır.
class ExpiredBadge extends StatelessWidget {
  const ExpiredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(
      label: S2.dokSuresiDoldu,
      foreground: kError,
      background: kErrorContainer,
    );
  }
}

/// Yayından kaldırılmış doküman — yalnız genel merkez görür (saha 404 alır).
class UnpublishedBadge extends StatelessWidget {
  const UnpublishedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBadge(
      label: S2.dokYayindaDegil,
      foreground: kWarning,
      background: kWarningContainer,
    );
  }
}

/// Dosya adı/MIME → tür ikonu ve rengi (ek listesindeki desenin aynısı).
class FileTypeVisual {
  const FileTypeVisual(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;

  /// Filtre çipi etiketi: `PDF` · `Word` · `Excel` · `Görsel` · `Dosya`.
  final String label;

  static const pdf = FileTypeVisual(Icons.picture_as_pdf_outlined, kError, 'PDF');
  static const word =
      FileTypeVisual(Icons.description_outlined, kInfo, 'Word');
  static const excel = FileTypeVisual(Icons.table_view_outlined, kSuccess, 'Excel');
  static const image = FileTypeVisual(Icons.image_outlined, kWarning, 'Görsel');
  static const other =
      FileTypeVisual(Icons.insert_drive_file_outlined, kTextSecondary, 'Dosya');

  static const all = [pdf, word, excel, image, other];

  static FileTypeVisual of(String fileName, [String mime = '']) {
    final n = fileName.toLowerCase();
    if (n.endsWith('.pdf') || mime == 'application/pdf') return pdf;
    if (n.endsWith('.docx') || n.endsWith('.doc')) return word;
    if (n.endsWith('.xlsx') || n.endsWith('.xls')) return excel;
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        mime.startsWith('image/')) {
      return image;
    }
    return other;
  }
}

/// Bir dokümanın ek özeti — liste kartındaki "dosya türü ikonu ve boyutu"
/// (§5.2/2). Liste ucu yalnız `attachment_count` döndürdüğü için ekler tek
/// istekte (entity=documents) çekilip belge kimliğine göre gruplanır.
class DocumentFiles {
  const DocumentFiles(this.items);

  final List<Attachment> items;

  bool get isEmpty => items.isEmpty;
  int get totalSize => items.fold(0, (a, b) => a + b.size);
  FileTypeVisual get visual =>
      items.isEmpty ? FileTypeVisual.other : FileTypeVisual.of(items.first.fileName, items.first.mime);

  Set<String> get typeLabels =>
      items.map((a) => FileTypeVisual.of(a.fileName, a.mime).label).toSet();

  static Map<int, DocumentFiles> groupBy(List<Attachment> all) {
    final map = <int, List<Attachment>>{};
    for (final a in all) {
      map.putIfAbsent(a.entityId, () => []).add(a);
    }
    return map.map((k, v) => MapEntry(k, DocumentFiles(v)));
  }
}

/// E-61 doküman kartı — §5.2/2: başlık, sürüm, yayın tarihi, dosya türü
/// ikonu ve boyutu, kapsam rozeti, süresi dolmuşsa uyarı rozeti.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.document,
    this.files,
    this.onTap,
    this.showCategory = false,
  });

  final DocumentRecord document;
  final DocumentFiles? files;
  final VoidCallback? onTap;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = files;
    final visual = f == null || f.isEmpty
        ? FileTypeVisual.other
        : f.visual;
    final meta = <String>[
      if (document.version != null && document.version!.isNotEmpty)
        document.version!,
      if (document.publishedAt != null && document.publishedAt!.isNotEmpty)
        Formats.dateFromApi(document.publishedAt),
      if (showCategory && (document.categoryName ?? '').isNotEmpty)
        document.categoryName!,
    ];

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r12),
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visual.icon, color: visual.color, size: 32),
              const SizedBox(width: s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, style: theme.textTheme.titleMedium),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: s4),
                        child: Text(
                          meta.join(' · '),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: kTextSecondary),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: s4),
                      child: Text(
                        _fileLine(f, document.attachmentCount),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kTextSecondary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: s8),
                      child: Wrap(
                        spacing: s8,
                        runSpacing: s4,
                        children: [
                          ScopeBadge(document: document),
                          if (document.isExpired) const ExpiredBadge(),
                          if (!document.isActive) const UnpublishedBadge(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  static String _fileLine(DocumentFiles? files, int count) {
    if (files == null) {
      // Ek listesi henüz gelmedi: sunucunun saydığı değer gösterilir.
      return count == 0 ? S2.dokDosyaYok : S2.dokDosyaSayisi(count);
    }
    if (files.isEmpty) return S2.dokDosyaYok;
    return '${files.typeLabels.join(', ')} · '
        '${S2.dokDosyaSayisi(files.items.length)} · '
        '${Formats.fileSize(files.totalSize)}';
  }
}

/// İndirme akışı — §5.2/3 ve API-V2 §19.4.
///
/// Sıra **bağlayıcıdır**: önce `POST /documents/:id/download` (sayaç), sonra
/// dosya çekilir. Sayaç çağrısı başarısız olursa indirme yine de denenmez —
/// aksi hâlde "hangi belge kullanıldı" verisi sessizce bozulur.
Future<bool> downloadDocumentAttachment(
  BuildContext context, {
  required ApiV2 api,
  required int documentId,
  required Attachment attachment,
}) async {
  try {
    await api.registerDocumentDownload(documentId);
    final bytes = await api.downloadAttachment(attachment.id);
    await saveDownloadedFile(bytes, attachment.fileName,
        mimeType: attachment.mime.isEmpty ? null : attachment.mime);
    if (context.mounted) showAppSnackBar(context, S2.dokIndirildi);
    return true;
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, v2ErrorMessage(e, fallback: S2.ekIndirilemedi));
    }
    return false;
  }
}
