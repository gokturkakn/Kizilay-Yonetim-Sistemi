import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'document_form_screen.dart';
import 'document_widgets.dart';

/// E-62 · Belge detayı — SPEC-V2-M6 §5.2/3.
///
/// Açıklama, sürüm, ekli dosyalar, birincil **İndir** eylemi; genel merkez
/// için Düzenle / Yayından Kaldır. `scope_label`, `is_expired` ve
/// `attachment_count` sunucudan geldiği gibi gösterilir.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final int documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _loading = true;
  bool _downloading = false;
  Object? _error;
  DocumentRecord? _doc;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await context.api2.document(widget.documentId);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _download(Attachment a) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final ok = await downloadDocumentAttachment(
      context,
      api: context.api2,
      documentId: widget.documentId,
      attachment: a,
    );
    if (!mounted) return;
    setState(() => _downloading = false);
    // İndirme sayacı arttı; detay tazelenerek gerçek değer gösterilir.
    if (ok) _load();
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentFormScreen(existing: _doc)),
    );
    if (saved == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _toggleActive() async {
    final doc = _doc!;
    if (doc.isActive) {
      final ok = await showConfirmDialog(
        context,
        title: S2.dokYayindanKaldirBaslik,
        body: S2.dokYayindanKaldirGovde,
      );
      if (!ok) return;
    }
    if (!mounted) return;
    try {
      await context.api2.setDocumentActive(doc.id, !doc.isActive);
      _changed = true;
      if (!mounted) return;
      showAppSnackBar(context,
          doc.isActive ? S2.dokYayindanKaldirildi : S2.dokYayinaAlindi);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _delete() async {
    final api = context.api2;
    if (!await confirmDelete(context, S2.dokSilBaslik)) return;
    try {
      await api.deleteDocument(widget.documentId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.isAdmin;
    final doc = _doc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(doc?.title ?? S2.modulDokuman),
          actions: [
            if (isAdmin && doc != null)
              PopupMenuButton<String>(
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text(S2.duzenle)),
                  PopupMenuItem(
                    value: 'active',
                    child: Text(
                        doc.isActive ? S2.dokYayindanKaldir : S2.dokYayinaAl),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text(Str.sil)),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _edit();
                    case 'active':
                      _toggleActive();
                    case 'delete':
                      _delete();
                  }
                },
              ),
          ],
        ),
        body: _body(doc),
        floatingActionButton: doc == null || doc.attachments.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed:
                    _downloading ? null : () => _download(doc.attachments.first),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kOnPrimary),
                      )
                    : const Icon(Icons.download),
                label: const Text(S2.dokIndir),
              ),
      ),
    );
  }

  Widget _body(DocumentRecord? doc) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorState(onRetry: _load, message: v2ErrorMessage(_error!));
    }
    if (doc == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: s8),
              Wrap(
                spacing: s8,
                runSpacing: s8,
                children: [
                  ScopeBadge(document: doc),
                  if (doc.isExpired) const ExpiredBadge(),
                  if (!doc.isActive) const UnpublishedBadge(),
                ],
              ),
              const SizedBox(height: s16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(label: S2.dokKategori, value: doc.categoryName),
                      _Row(label: S2.dokSurum, value: doc.version),
                      _Row(
                          label: S2.dokYayinTarihi,
                          value: doc.publishedAt == null
                              ? null
                              : Formats.dateFromApi(doc.publishedAt)),
                      _Row(
                          label: S2.dokSonGecerlilik,
                          value: doc.validUntil == null
                              ? null
                              : Formats.dateFromApi(doc.validUntil)),
                      _Row(
                          label: S2.dokIndirmeSayisi,
                          value: Formats.number(doc.downloadCount)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: s16),
              Text(S2.dokAciklama, style: theme.textTheme.titleSmall),
              const SizedBox(height: s4),
              Text(
                (doc.description ?? '').trim().isEmpty
                    ? S2.dokAciklamaYok
                    : doc.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: (doc.description ?? '').trim().isEmpty
                        ? kTextSecondary
                        : kTextPrimary),
              ),
              const SizedBox(height: s24),
              Text(S2.dokEkler, style: theme.textTheme.titleSmall),
              const SizedBox(height: s8),
              if (doc.attachments.isEmpty)
                Text(S2.dokDosyaYok,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: kTextSecondary))
              else
                for (final a in doc.attachments)
                  _AttachmentRow(
                    attachment: a,
                    busy: _downloading,
                    onDownload: () => _download(a),
                  ),
              const SizedBox(height: s48),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: kTextSecondary)),
          ),
          Expanded(
            child: Text(
              (value ?? '').isEmpty ? '—' : value!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachment,
    required this.onDownload,
    required this.busy,
  });

  final Attachment attachment;
  final VoidCallback onDownload;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = FileTypeVisual.of(attachment.fileName, attachment.mime);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: s4),
      child: Row(
        children: [
          Icon(visual.icon, color: visual.color),
          const SizedBox(width: s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formats.truncateFileName(attachment.fileName),
                    style: theme.textTheme.bodyMedium),
                Text(
                  '${visual.label} · ${Formats.fileSize(attachment.size)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kTextSecondary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: busy ? null : onDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text(S2.dokIndir),
          ),
        ],
      ),
    );
  }
}
