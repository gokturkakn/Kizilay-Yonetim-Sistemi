import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'lookup_item_list_screen.dart';

/// E-63 · Tanımlar (kategori listesi) — docs/UX-V2.md §6.5.
///
/// K1 lookup altyapısının yönetim yüzü — **v2'nin "kod değişikliği gerekmez"
/// vaadinin arayüzü.**
class LookupCategoryListScreen extends StatefulWidget {
  const LookupCategoryListScreen({super.key});

  @override
  State<LookupCategoryListScreen> createState() =>
      _LookupCategoryListScreenState();
}

class _LookupCategoryListScreenState extends State<LookupCategoryListScreen> {
  bool _loading = true;
  Object? _error;
  List<LookupCategory> _items = const [];
  String _query = '';

  /// Arayüzde kullanılmayan kategoriler — §10/2, §10/3, §10/4 kararları.
  static const _unusedCodes = {'bolge', 'durum', 'etkinlik_adi'};

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
      final items = await context.api2.lookupCategories();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  List<LookupCategory> get _visible => _query.trim().isEmpty
      ? _items
      : _items.where((c) => Formats.trContains(c.name, _query)).toList();

  bool get _hasPlatformCategory =>
      _items.any((c) => c.code == 'toplanti_platformu');

  Future<void> _createPlatformCategory() async {
    try {
      final cache = context.lookups;
      await context.api2
          .createLookupCategory('toplanti_platformu', 'Toplantı Platformları');
      cache.invalidate('toplanti_platformu');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tanımlar')),
      body: Column(
        children: [
          SearchField(
            hint: 'Tanım ara...',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(
                        onRetry: _load, message: v2ErrorMessage(_error!))
                    : ListView(
                        children: [
                          for (final c in _visible)
                            Column(
                              children: [
                                ListTile(
                                  title: Text(c.name,
                                      style: theme.textTheme.titleMedium),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${c.itemCount} kayıt'),
                                      // Kullanılmayan kategoriler gizlenmez,
                                      // ama açıkça işaretlenir.
                                      if (_unusedCodes.contains(c.code))
                                        Text(S2.tanimKullanilmiyor,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: kTextSecondary)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (c.isSystem)
                                        Chip(
                                          label: const Text(S2.sistem),
                                          backgroundColor: kInactiveContainer,
                                          labelStyle: const TextStyle(
                                              fontSize: 11, color: kInactive),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ),
                                      const Icon(Icons.chevron_right,
                                          color: kTextSecondary),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            LookupItemListScreen(category: c),
                                      ),
                                    );
                                    if (mounted) _load();
                                  },
                                ),
                                const Divider(height: 1),
                              ],
                            ),
                          // Lookup olmayan iki ayrı satır (§6.5 E-63).
                          ListTile(
                            title: Text('Etkinlik Takvimi',
                                style: theme.textTheme.titleMedium),
                            subtitle: const Text('Millî, dinî ve önemli günler'),
                            trailing: const Icon(Icons.chevron_right,
                                color: kTextSecondary),
                            onTap: () => showAppSnackBar(
                                context, S2.bosTakvimAlt),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text('Toplantı Platformları',
                                style: theme.textTheme.titleMedium),
                            subtitle: Text(_hasPlatformCategory
                                ? 'Çevrim içi toplantı platformları'
                                : 'Tanımlı değil'),
                            trailing: _hasPlatformCategory
                                ? const Icon(Icons.check,
                                    color: kSuccess)
                                : IconButton(
                                    tooltip: 'Kategoriyi oluştur',
                                    icon: const Icon(Icons.add),
                                    onPressed: _createPlatformCategory,
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
