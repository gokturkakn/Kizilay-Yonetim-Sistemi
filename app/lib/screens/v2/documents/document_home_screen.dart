import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/document_filter.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'document_form_screen.dart';
import 'document_list_screen.dart';
import 'document_search_screen.dart';

/// E-60 · Kılavuz ve Dokümanlar ana ekranı — SPEC-V2-M6 §5.2/1.
///
/// Kategori kartları (her kartta belge sayısı), üstte arama kutusu ve
/// `Yalnız bana ait olanlar` anahtarı. Sayımlar **listeyle aynı filtreden**
/// gelir: anahtar açıldığında kartlardaki sayılar da birebir eşleşme moduna
/// geçer, aksi hâlde kart "12 belge" derken liste 1 belge gösterirdi.
class DocumentHomeScreen extends StatefulWidget {
  const DocumentHomeScreen({super.key});

  @override
  State<DocumentHomeScreen> createState() => _DocumentHomeScreenState();
}

class _DocumentHomeScreenState extends State<DocumentHomeScreen> {
  bool _loading = true;
  Object? _error;
  bool _onlyMine = false;

  List<LookupItem> _categories = const [];
  List<DocumentRecord> _documents = const [];

  AppUser? get _user => context.session.user;

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
    final api = context.api2;
    final lookups = context.lookups;
    final filter = DocumentFilter(onlyMine: _onlyMine);
    try {
      final results = await Future.wait([
        lookups.items('dokuman_kategorisi'),
        api.documents(filter.params(_user), limit: 500),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = (results[0] as List<LookupItem>)
            .where((c) => c.isActive)
            .toList(growable: false);
        _documents = (results[1] as Paged2<DocumentRecord>).data;
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

  int _countFor(int categoryId) =>
      _documents.where((d) => d.categoryId == categoryId).length;

  void _openCategory(LookupItem category) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DocumentListScreen(
            category: category,
            onlyMine: _onlyMine,
          ),
        ))
        .then((_) => _load());
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DocumentSearchScreen(onlyMine: _onlyMine),
        ))
        .then((_) => _load());
  }

  Future<void> _newDocument() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DocumentFormScreen()),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.isAdmin;
    // Kırılımı olmayan hesapta (ör. ülke geneli genel merkez) anahtarın
    // gönderecek bir kimliği yoktur; sessizce etkisiz durmaktansa gizlenir.
    final hasScope = UserScope.of(_user) != null;

    return Scaffold(
      appBar: AppBar(title: const Text(S2.modulDokuman)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchBox(onTap: _openSearch),
                if (hasScope)
                  SwitchListTile(
                    value: _onlyMine,
                    onChanged: (v) {
                      setState(() => _onlyMine = v);
                      _load();
                    },
                    title: const Text(S2.dokYalnizBana),
                    subtitle: const Text(S2.dokYalnizBanaAlt),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: s16),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(s16, s8, s16, s16),
                  child: _body(context),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _newDocument,
              icon: const Icon(Icons.add),
              label: const Text(S2.dokYeni),
            )
          : null,
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: s48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 240,
        child: ErrorState(onRetry: _load, message: v2ErrorMessage(_error!)),
      );
    }
    if (_categories.isEmpty) {
      return SizedBox(
        height: 240,
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          message: S2.dokBosGenel,
          subMessage: context.isSaha ? S2.dokBosSaha : null,
        ),
      );
    }
    return NavCardGrid(cards: [
      for (final c in _categories)
        NavCard(
          title: c.name,
          subtitle: S2.dokBelgeSayisi(_countFor(c.id)),
          icon: Icons.folder_outlined,
          onTap: () => _openCategory(c),
        ),
    ]);
  }
}

/// Arama kutusu — dokunuşta E-64'e götürür (§5.2/5).
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(s16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r8),
        child: InputDecorator(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: kTextSecondary),
            isDense: true,
          ),
          child: Text(S2.dokAramaIpucu,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: kTextSecondary)),
        ),
      ),
    );
  }
}
