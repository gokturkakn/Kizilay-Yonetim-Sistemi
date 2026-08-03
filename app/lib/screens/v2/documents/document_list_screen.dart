import 'package:flutter/material.dart';

import '../../../core/document_filter.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../shared.dart';
import 'document_detail_screen.dart';
import 'document_form_screen.dart';
import 'document_widgets.dart';

/// E-61 · Kategori listesi — SPEC-V2-M6 §5.2/2.
///
/// Kapsam çipi **sunucuya** gider (`scope=`); `applicable_to` ile çakışmaz,
/// çakışan yalnız coğrafya kimlikleridir (API-V2 §19.4a). Dosya türü çipi
/// istemcide uygulanır: liste ucu dosya adı/MIME döndürmez, ekler tek istekte
/// çekilip belge kimliğine göre eşlenir.
class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({
    super.key,
    this.category,
    this.onlyMine = false,
  });

  final LookupItem? category;
  final bool onlyMine;

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  bool _loading = true;
  Object? _error;
  List<DocumentRecord> _items = const [];
  Map<int, DocumentFiles> _files = const {};

  late bool _onlyMine;
  String? _scope;
  String? _fileType;

  AppUser? get _user => context.session.user;

  @override
  void initState() {
    super.initState();
    _onlyMine = widget.onlyMine;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.api2;
    final filter = DocumentFilter(
      categoryId: widget.category?.id,
      scope: _scope,
      onlyMine: _onlyMine,
    );
    try {
      final page = await api.documents(filter.params(_user), limit: 300);
      // Ekler tek istekte: N+1 yerine tek `entity=documents` sorgusu.
      List<Attachment> attachments = const [];
      try {
        attachments = await api.attachments(entity: 'documents', limit: 500);
      } catch (_) {
        // ek listesi çekilemezse kartlar sunucunun saydığı adedi gösterir
      }
      if (!mounted) return;
      setState(() {
        _items = page.data;
        _files = DocumentFiles.groupBy(attachments);
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

  List<DocumentRecord> get _visible {
    if (_fileType == null) return _items;
    return _items
        .where((d) => _files[d.id]?.typeLabels.contains(_fileType) ?? false)
        .toList(growable: false);
  }

  Future<void> _open(DocumentRecord d) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: d.id)),
    );
    if (changed == true) _load();
  }

  Future<void> _newDocument() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DocumentFormScreen(lockedCategory: widget.category),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.isAdmin;
    final hasScope = UserScope.of(_user) != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category?.name ?? S2.dokTumu)),
      body: Column(
        children: [
          const SizedBox(height: s8),
          _ScopeChips(
            value: _scope,
            onChanged: (v) {
              setState(() => _scope = v);
              _load();
            },
          ),
          const SizedBox(height: s8),
          _FileTypeChips(
            value: _fileType,
            onChanged: (v) => setState(() => _fileType = v),
          ),
          if (hasScope)
            SwitchListTile(
              dense: true,
              value: _onlyMine,
              onChanged: (v) {
                setState(() => _onlyMine = v);
                _load();
              },
              title: const Text(S2.dokYalnizBana),
              contentPadding: const EdgeInsets.symmetric(horizontal: s16),
            ),
          Expanded(
            child: AsyncListBody<DocumentRecord>(
              loading: _loading,
              error: _error,
              items: _visible,
              onRetry: _load,
              emptyIcon: Icons.menu_book_outlined,
              emptyMessage: S2.dokBosKategori,
              emptySubMessage: context.isSaha ? S2.dokBosSaha : null,
              itemBuilder: (context, d) => DocumentCard(
                document: d,
                files: _files[d.id],
                onTap: () => _open(d),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              tooltip: S2.dokYeni,
              onPressed: _newDocument,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Kapsam çipleri — `Tümü` · `Genel` · `Bölge` · `İl` · `İlçe` (§5.2/2).
class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <(String?, String)>[
      (null, S2.dokKapsamTumu),
      for (final s in DocumentScope.all) (s, DocumentScope.label(s)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: s16),
      child: Row(
        children: [
          for (final (v, label) in entries) ...[
            ChoiceChip(
              label: Text(label),
              selected: value == v,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: value == v ? FontWeight.w600 : FontWeight.w400,
                color: value == v ? kPrimary : kTextPrimary,
              ),
              onSelected: (_) => onChanged(v),
            ),
            const SizedBox(width: s8),
          ],
        ],
      ),
    );
  }
}

/// Dosya türü çipleri — istemcide, çekilen ek listesine göre (§5.2/2).
class _FileTypeChips extends StatelessWidget {
  const _FileTypeChips({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: s16),
      child: Row(
        children: [
          for (final v in <String?>[null, ...FileTypeVisual.all.map((f) => f.label)]) ...[
            ChoiceChip(
              avatar: v == null
                  ? null
                  : Icon(
                      FileTypeVisual.all
                          .firstWhere((f) => f.label == v)
                          .icon,
                      size: 16,
                      color: FileTypeVisual.all
                          .firstWhere((f) => f.label == v)
                          .color,
                    ),
              label: Text(v ?? S2.dokTumTurler),
              selected: value == v,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: value == v ? FontWeight.w600 : FontWeight.w400,
                color: value == v ? kPrimary : kTextPrimary,
              ),
              onSelected: (_) => onChanged(v),
            ),
            const SizedBox(width: s8),
          ],
        ],
      ),
    );
  }
}
