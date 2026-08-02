import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'lookup_item_form_screen.dart';

/// E-64 · Tanım Öğeleri — docs/UX-V2.md §6.5.
class LookupItemListScreen extends StatefulWidget {
  const LookupItemListScreen({super.key, required this.category});

  final LookupCategory category;

  @override
  State<LookupItemListScreen> createState() => _LookupItemListScreenState();
}

class _LookupItemListScreenState extends State<LookupItemListScreen> {
  bool _loading = true;
  Object? _error;
  List<LookupItem> _items = const [];
  String _query = '';
  bool _showInactive = false;

  bool get _isHierarchical => widget.category.code == 'alt_gorev';

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
      final items = await context.api2
          .lookupItems(categoryCode: widget.category.code);
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

  List<LookupItem> get _visible => _items.where((i) {
        if (!_showInactive && !i.isActive) return false;
        if (_query.trim().isEmpty) return true;
        return Formats.trContains(i.name, _query);
      }).toList();

  void _invalidateCache() => context.lookups.invalidate(widget.category.code);

  Future<void> _openForm([LookupItem? item]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => LookupItemFormScreen(
        category: widget.category,
        existing: item,
        parentOptions: _isHierarchical ? _rootItems() : const [],
      ),
    ));
    if (saved == true) {
      _invalidateCache();
      _load();
    }
  }

  /// Hiyerarşik kategoride üst tanım seçenekleri `gorev_turu`dan gelir.
  List<LookupItem> _rootItems() => const [];

  Future<void> _toggleActive(LookupItem item) async {
    try {
      await context.api2.setLookupItemActive(item.id, !item.isActive);
      _invalidateCache();
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _delete(LookupItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tanım silinsin mi?',
      body: S2.dlgGeriAlinamaz,
      confirmText: Str.sil,
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    try {
      await context.api2.deleteLookupItem(item.id);
      _invalidateCache();
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 IN_USE — kullanılmış tanım silinemez, pasif yapılabilir.
      if (e.isConflict) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(S2.dlgTanimSilinemez),
            content: const Text(S2.dlgTanimSilinemezGovde),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(Str.tamam)),
            ],
          ),
        );
        return;
      }
      if (!context.mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = List<LookupItem>.from(_visible);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _items = list);
    try {
      for (var i = 0; i < list.length; i++) {
        await context.api2.updateLookupItem(list[i].id, {'sort_order': i});
      }
      _invalidateCache();
      if (!mounted) return;
      showAppSnackBar(context, S2.basariSiralama);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: Column(
        children: [
          SearchField(
            hint: 'Ara...',
            onChanged: (v) => setState(() => _query = v),
          ),
          SwitchListTile(
            title: const Text('Pasifleri göster'),
            value: _showInactive,
            onChanged: (v) => setState(() => _showInactive = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(
                        onRetry: _load, message: v2ErrorMessage(_error!))
                    : visible.isEmpty
                        ? const EmptyState(
                            icon: Icons.list_alt_outlined,
                            message: S2.bosTanim,
                            subMessage: S2.bosListeAlt,
                          )
                        : ReorderableListView.builder(
                            itemCount: visible.length,
                            onReorder: _reorder,
                            itemBuilder: (context, i) {
                              final item = visible[i];
                              return ListTile(
                                key: ValueKey(item.id),
                                leading: const Icon(Icons.drag_handle,
                                    color: kTextDisabled),
                                title: Text(item.name,
                                    style: theme.textTheme.titleMedium),
                                subtitle: item.code == null
                                    ? null
                                    : Text(item.code!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: kTextDisabled)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(
                                          item.isActive ? S2.aktif : S2.pasif),
                                      backgroundColor: item.isActive
                                          ? kSuccessContainer
                                          : kInactiveContainer,
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        color: item.isActive
                                            ? kSuccess
                                            : kInactive,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: kTextSecondary),
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                            value: 'edit',
                                            child: Text(S2.duzenle)),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(item.isActive
                                              ? 'Pasif Yap'
                                              : 'Aktif Yap'),
                                        ),
                                        const PopupMenuItem(
                                            value: 'delete', child: Text('Sil')),
                                      ],
                                      onSelected: (v) {
                                        switch (v) {
                                          case 'edit':
                                            _openForm(item);
                                          case 'toggle':
                                            _toggleActive(item);
                                          case 'delete':
                                            _delete(item);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _openForm(item),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Tanım',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Tanım')),
    );
  }
}
