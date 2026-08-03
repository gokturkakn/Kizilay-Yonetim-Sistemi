import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/document_filter.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'document_detail_screen.dart';
import 'document_widgets.dart';

/// E-64 · Doküman arama — SPEC-V2-M6 §5.2/5.
///
/// Arama **sunucuda** yapılır (`q=`): başlık + açıklama, Türkçe büyük/küçük
/// harf duyarsız (`tr_lower`). İstemcide yeniden filtrelenmez; aksi hâlde
/// `I↔ı` kuralı iki yerde iki türlü uygulanırdı.
class DocumentSearchScreen extends StatefulWidget {
  const DocumentSearchScreen({super.key, this.onlyMine = false});

  final bool onlyMine;

  @override
  State<DocumentSearchScreen> createState() => _DocumentSearchScreenState();
}

class _DocumentSearchScreenState extends State<DocumentSearchScreen> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  Object? _error;
  List<DocumentRecord> _items = const [];
  String _lastQuery = '';

  AppUser? get _user => context.session.user;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final q = value.trim();
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() {
        _items = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final filter = DocumentFilter(query: q, onlyMine: widget.onlyMine);
    try {
      final page =
          await context.api2.documents(filter.params(_user), limit: 200);
      if (!mounted || _lastQuery != q) return; // eskiyen yanıt yazmaz
      setState(() {
        _items = page.data;
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

  Future<void> _open(DocumentRecord d) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: d.id)),
    );
    if (mounted && _lastQuery.isNotEmpty) _search(_lastQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S2.dokAramaBaslik)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(s16, s16, s16, s8),
            child: TextField(
              controller: _text,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: S2.dokAramaIpucu,
                helperText: S2.dokAramaIpucuAlt,
                prefixIcon: const Icon(Icons.search, color: kTextSecondary),
                isDense: true,
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _text.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_lastQuery.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        message: S2.dokAramaBaslik,
        subMessage: S2.dokAramaIpucuAlt,
      );
    }
    return AsyncListBody<DocumentRecord>(
      loading: _loading,
      error: _error,
      items: _items,
      onRetry: () => _search(_lastQuery),
      emptyIcon: Icons.search_off,
      emptyMessage: S2.dokAramaBos,
      itemBuilder: (context, d) => DocumentCard(
        document: d,
        showCategory: true,
        onTap: () => _open(d),
      ),
    );
  }
}
