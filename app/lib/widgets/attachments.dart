import 'package:flutter/material.dart';

import '../core/api_v2.dart';
import '../core/filepick/file_pick.dart';
import '../core/formatters.dart';
import '../core/layout.dart';
import '../core/strings.dart';
import '../core/strings_v2.dart';
import '../models/models_v2.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Ek öğesinin 4 durumu — docs/UX-V2.md §7.6.
enum UploadState { bekliyor, yukleniyor, tamam, hata }

class PendingAttachment {
  PendingAttachment({required this.file, required this.kind});

  final PickedFile file;
  final String kind;
  UploadState state = UploadState.bekliyor;
  String? error;
}

/// Ek kuyruğu ve yüklemesi — §7.6 "önce kaydet, sonra yükle".
///
/// Yeni kayıtta dosyalar yüklenmez, yerel kuyruğa alınır; `Kaydet` sonrası
/// dönen `id` ile sırayla yüklenir. Kısmi başarısızlıkta kayıt geri alınmaz.
class AttachmentController extends ChangeNotifier {
  AttachmentController({
    required this.api,
    required this.entity,
    this.entityId,
  });

  final ApiV2 api;
  final String entity;
  int? entityId;

  final List<Attachment> existing = [];
  final List<PendingAttachment> queue = [];
  bool _uploading = false;

  bool get isUploading => _uploading;
  bool get hasPending => queue.any((q) => q.state != UploadState.tamam);
  int get failedCount =>
      queue.where((q) => q.state == UploadState.hata).length;

  int get totalCount => existing.length + queue.length;

  List<Attachment> ofKind(String kind) =>
      existing.where((a) => a.kind == kind).toList();

  List<PendingAttachment> pendingOfKind(String kind) =>
      queue.where((q) => q.kind == kind).toList();

  Future<void> loadExisting() async {
    final id = entityId;
    if (id == null) return;
    try {
      final list = await api.attachments(entity: entity, entityId: id);
      existing
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // ek listesi çekilemezse form yine çalışır
    }
  }

  /// Dosya ekler. Kayıt zaten varsa **hemen** yükler (§7.6/5), yoksa kuyruğa
  /// alır. Doğrulama hatası varsa metni döndürür.
  Future<String?> add(PickedFile file, String kind) async {
    if (totalCount >= AttachmentRules.maxPerRecord) return S2.ekHataAdet;
    final error = AttachmentRules.validate(file, kind);
    if (error != null) return error;

    final item = PendingAttachment(file: file, kind: kind);
    queue.add(item);
    notifyListeners();

    if (entityId != null) {
      await _upload(item);
    }
    return null;
  }

  void remove(PendingAttachment item) {
    queue.remove(item);
    notifyListeners();
  }

  Future<bool> deleteExisting(Attachment a) async {
    try {
      await api.deleteAttachment(a.id);
      existing.remove(a);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kayıt oluştuktan sonra kuyruğu sırayla yükler; başarısız sayısını döner.
  Future<int> uploadQueue(int id) async {
    entityId = id;
    _uploading = true;
    notifyListeners();
    var failed = 0;
    for (final item in List<PendingAttachment>.from(queue)) {
      if (item.state == UploadState.tamam) continue;
      final ok = await _upload(item);
      if (!ok) failed++;
    }
    _uploading = false;
    notifyListeners();
    return failed;
  }

  Future<bool> _upload(PendingAttachment item) async {
    final id = entityId;
    if (id == null) return false;
    item.state = UploadState.yukleniyor;
    item.error = null;
    notifyListeners();
    try {
      final uploaded = await api.uploadAttachment(
        entity: entity,
        entityId: id,
        kind: item.kind,
        fileName: item.file.name,
        bytes: item.file.bytes,
      );
      item.state = UploadState.tamam;
      existing.add(uploaded);
      queue.remove(item);
      notifyListeners();
      return true;
    } catch (e) {
      item.state = UploadState.hata;
      item.error = v2ErrorMessage(e, fallback: S2.ekHataSunucu);
      notifyListeners();
      return false;
    }
  }

  Future<void> retry(PendingAttachment item) => _upload(item);
}

/// Formdaki ek alanı — §7.3.
class AttachmentField extends StatelessWidget {
  const AttachmentField({
    super.key,
    required this.controller,
    required this.kind,
    required this.label,
    this.enabled = true,
  });

  final AttachmentController controller;
  final String kind;
  final String label;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final files = await pickFiles(accept: AttachmentRules.acceptFor(kind));
    if (files.isEmpty) return;
    for (final f in files) {
      final error = await controller.add(f, kind);
      if (error != null && context.mounted) {
        showAppSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final existing = controller.ofKind(kind);
        final pending = controller.pendingOfKind(kind);
        final isPhoto = AttachmentRules.isPhotoKind(kind);
        final count = existing.length + pending.length;
        final totalBytes = existing.fold<int>(0, (a, b) => a + b.size) +
            pending.fold<int>(0, (a, b) => a + b.file.size);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: s8),
            if (isPhoto)
              Wrap(
                spacing: s8,
                runSpacing: s8,
                children: [
                  for (final a in existing)
                    _Thumb(
                      label: a.fileName,
                      onRemove: enabled
                          ? () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: S2.ekSilBaslik,
                                body: S2.ekSilGovde(a.fileName),
                                confirmText: Str.sil,
                                destructive: true,
                              );
                              if (!ok) return;
                              final deleted =
                                  await controller.deleteExisting(a);
                              if (context.mounted) {
                                showAppSnackBar(
                                    context,
                                    deleted
                                        ? S2.ekSilindi
                                        : S2.ekIndirilemedi);
                              }
                            }
                          : null,
                    ),
                  for (final p in pending)
                    _Thumb(
                      label: p.file.name,
                      state: p.state,
                      error: p.error,
                      onRetry: () => controller.retry(p),
                      onRemove: enabled ? () => controller.remove(p) : null,
                    ),
                  if (enabled) _AddBox(onTap: () => _pick(context)),
                ],
              )
            else ...[
              for (final a in existing)
                _DocRow(
                  fileName: a.fileName,
                  size: a.size,
                  onRemove: enabled
                      ? () async {
                          final ok = await showConfirmDialog(
                            context,
                            title: S2.ekSilBaslik,
                            body: S2.ekSilGovde(a.fileName),
                            confirmText: Str.sil,
                            destructive: true,
                          );
                          if (!ok) return;
                          await controller.deleteExisting(a);
                        }
                      : null,
                ),
              for (final p in pending)
                _DocRow(
                  fileName: p.file.name,
                  size: p.file.size,
                  state: p.state,
                  error: p.error,
                  onRetry: () => controller.retry(p),
                  onRemove: enabled ? () => controller.remove(p) : null,
                ),
              if (enabled)
                Padding(
                  padding: const EdgeInsets.only(top: s8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _AddBox(onTap: () => _pick(context)),
                  ),
                ),
            ],
            if (count == 0)
              Padding(
                padding: const EdgeInsets.only(top: s4),
                child: Text(S2.ekBosDurum,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: s8),
                child: Text(
                  '$count dosya · toplam ${Formats.fileSize(totalBytes)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kTextSecondary),
                ),
              ),
            if (controller.entityId == null && pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: s4),
                child: Text(S2.ekKuyrukNotu,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary)),
              ),
          ],
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.label,
    this.state,
    this.error,
    this.onRemove,
    this.onRetry,
  });

  final String label;
  final UploadState? state;
  final String? error;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final busy = state == UploadState.yukleniyor;
    final queued = state == UploadState.bekliyor;
    final failed = state == UploadState.hata;
    return SizedBox(
      width: kThumbSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Opacity(
                opacity: busy || queued ? 0.4 : 1,
                child: Container(
                  width: kThumbSize,
                  height: kThumbSize,
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(r8),
                    border: Border.all(
                        color: failed ? kError : kBorder, width: failed ? 2 : 1),
                  ),
                  child: Center(
                    child: failed
                        ? const Icon(Icons.error_outline, color: kError)
                        : queued
                            ? const Icon(Icons.schedule, color: kTextSecondary)
                            : busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.image_outlined,
                                    color: kTextSecondary),
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    tooltip: 'Eki sil',
                    iconSize: 20,
                    icon: const CircleAvatar(
                      radius: 10,
                      backgroundColor: kSurface,
                      child: Icon(Icons.close, size: 14, color: kTextSecondary),
                    ),
                    onPressed: onRemove,
                  ),
                ),
            ],
          ),
          const SizedBox(height: s4),
          Text(
            queued ? S2.ekSirada : Formats.truncateFileName(label, max: 14),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: failed ? kError : kTextSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (failed && onRetry != null)
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: onRetry,
              child: const Text('Tekrar Dene', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.fileName,
    required this.size,
    this.state,
    this.error,
    this.onRemove,
    this.onRetry,
  });

  final String fileName;
  final int size;
  final UploadState? state;
  final String? error;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  IconData get _icon {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.xlsx')) return Icons.table_view_outlined;
    return Icons.description_outlined;
  }

  Color get _iconColor {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return kError;
    if (lower.endsWith('.xlsx')) return kSuccess;
    return kInfo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: _iconColor, size: 20),
              const SizedBox(width: s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Formats.truncateFileName(fileName),
                        style: theme.textTheme.bodyMedium),
                    Text(
                      state == UploadState.bekliyor
                          ? S2.ekSirada
                          : Formats.fileSize(size),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kTextSecondary),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Eki sil',
                  icon: const Icon(Icons.close, size: 18, color: kTextSecondary),
                  onPressed: onRemove,
                ),
            ],
          ),
          if (state == UploadState.yukleniyor)
            const Padding(
              padding: EdgeInsets.only(top: s4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: s4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kError)),
                  ),
                  if (onRetry != null)
                    TextButton(
                        onPressed: onRetry, child: const Text('Tekrar Dene')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddBox extends StatelessWidget {
  const _AddBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r8),
      child: Container(
        width: kThumbSize,
        height: kThumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r8),
          border: Border.all(color: kBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: kTextSecondary),
            Text(S2.ekle,
                style: TextStyle(fontSize: 12, color: kTextSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Detay ekranındaki ek listesi — §7.8.
class AttachmentList extends StatelessWidget {
  const AttachmentList({super.key, required this.attachments});

  final List<Attachment> attachments;

  static const _kindLabels = {
    'fotograf': S2.ekFotograf,
    'dokuman': S2.ekDokuman,
    'tutanak': S2.ekTutanak,
    'sunum': S2.ekSunum,
    'katilim_listesi': S2.ekKatilimListesi,
  };

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const EmptyState(
        icon: Icons.attach_file,
        message: S2.ekDetayBos,
      );
    }
    final theme = Theme.of(context);
    final columns = layoutOf(context) == LayoutClass.compact ? 3 : 5;
    final children = <Widget>[];
    for (final entry in _kindLabels.entries) {
      final list = attachments.where((a) => a.kind == entry.key).toList();
      if (list.isEmpty) continue; // boş tür başlığı gösterilmez
      children.add(Padding(
        padding: const EdgeInsets.only(top: s16, bottom: s8),
        child: Text(entry.value, style: theme.textTheme.titleSmall),
      ));
      if (entry.key == 'fotograf') {
        children.add(GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: s8,
          mainAxisSpacing: s8,
          children: [
            for (var i = 0; i < list.length; i++)
              Container(
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(r8),
                  border: Border.all(color: kBorder),
                ),
                child: const Center(
                    child: Icon(Icons.image_outlined, color: kTextSecondary)),
              ),
          ],
        ));
      } else {
        for (final a in list) {
          children.add(_DocRow(fileName: a.fileName, size: a.size));
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: s16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
