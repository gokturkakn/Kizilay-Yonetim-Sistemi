import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-56 · Stok Durumu — docs/UX-V2.md §6.3.
class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key, this.lowOnly = false});

  final bool lowOnly;

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  bool _loading = true;
  Object? _error;
  List<StockItem> _items = const [];
  late bool _lowOnly = widget.lowOnly;
  String _query = '';

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
      final items = await context.api2.stockItems(lowOnly: _lowOnly);
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

  List<StockItem> get _visible => _query.trim().isEmpty
      ? _items
      : _items
          .where((i) => Formats.trContains(i.productName, _query))
          .toList();

  Future<void> _editMinQuantity(StockItem item) async {
    final controller =
        TextEditingController(text: item.minQuantity.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kritik Seviyeyi Değiştir'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Kritik Seviye'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(Str.vazgec)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(Str.kaydet)),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        await context.api2.setStockMinQuantity(
            item.productId, int.tryParse(controller.text) ?? 0);
        if (!mounted) return;
        showAppSnackBar(context, S2.basariKritikSeviye);
        _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, v2ErrorMessage(e));
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    final lowCount = _items.where((i) => i.isLow).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Stok Durumu')),
      body: Column(
        children: [
          SearchField(
            hint: 'Ürün ara...',
            onChanged: (v) => setState(() => _query = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: s16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Yalnız azalanlar'),
                selected: _lowOnly,
                onSelected: (v) {
                  setState(() => _lowOnly = v);
                  _load();
                },
              ),
            ),
          ),
          if (lowCount > 0 && !_lowOnly)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(s16, s8, s16, 0),
              padding: const EdgeInsets.all(s12),
              decoration: BoxDecoration(
                color: kWarningContainer,
                borderRadius: BorderRadius.circular(r8),
              ),
              child: Text(S2.stokKritikOzet(lowCount),
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: s8),
          Expanded(
            child: AsyncListBody<StockItem>(
              loading: _loading,
              error: _error,
              items: visible,
              onRetry: _load,
              emptyIcon: Icons.inventory_2_outlined,
              emptyMessage: _lowOnly ? S2.bosStokKritik : S2.bosStok,
              itemBuilder: (context, item) => Card(
                child: ListTile(
                  title: Text(item.productName,
                      style: theme.textTheme.titleMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kritik seviye: ${Formats.number(item.minQuantity)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary)),
                      if (item.isLow)
                        Text(
                          item.quantity == 0 ? S2.stokYok : S2.stokKritik,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWarning),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.isLow)
                        const Icon(Icons.trending_down,
                            size: 18, color: kWarning),
                      const SizedBox(width: s4),
                      Text(
                        Formats.number(item.quantity),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: item.isLow ? kWarning : kTextPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (context.isAdmin)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: kTextSecondary),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'min',
                                child: Text('Kritik Seviyeyi Değiştir')),
                          ],
                          onSelected: (_) => _editMinQuantity(item),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StockMovementScreen(item: item),
                  )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// E-57 · Stok Hareketleri.
class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, required this.item});

  final StockItem item;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  bool _loading = true;
  List<StockMovement> _movements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await context.api2.stockMovements(productId: widget.item.productId);
      if (!mounted) return;
      setState(() {
        _movements = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addStock() async {
    final qty = TextEditingController();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok Girişi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Miktar'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(Str.vazgec)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(Str.kaydet)),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        await context.api2.createStockMovement({
          'product_id': widget.item.productId,
          'direction': 'giris',
          'quantity': int.tryParse(qty.text) ?? 0,
          'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
        });
        _load();
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(context, v2ErrorMessage(e));
      }
    }
    qty.dispose();
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inSum = _movements
        .where((m) => m.isIn)
        .fold<int>(0, (a, m) => a + m.quantity);
    final outSum = _movements
        .where((m) => !m.isIn)
        .fold<int>(0, (a, m) => a + m.quantity);
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.productName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(s16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mevcut Stok',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary)),
                        Text(Formats.number(widget.item.quantity),
                            style: theme.textTheme.headlineSmall),
                      ],
                    ),
                    Text('Giriş ${Formats.number(inSum)}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: kSuccess)),
                    Text('Çıkış ${Formats.number(outSum)}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: kWarning)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _movements.isEmpty
                    ? const EmptyState(
                        icon: Icons.swap_vert,
                        message: S2.bosStokHareket,
                      )
                    : ListView.separated(
                        itemCount: _movements.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = _movements[i];
                          return ListTile(
                            leading: Icon(
                              m.isIn
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: m.isIn ? kSuccess : kWarning,
                            ),
                            title: Text(
                                '${m.isIn ? '+' : '−'}${Formats.number(m.quantity)}'),
                            subtitle: Text(m.reason ?? ''),
                            trailing: Text(
                                Formats.dateTimeFromApi(m.createdAt),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: kTextSecondary)),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: context.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addStock,
              icon: const Icon(Icons.add),
              label: const Text('Stok Girişi'),
            )
          : null,
    );
  }
}
