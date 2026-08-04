import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'income_activity_form_screen_v2.dart';

/// Gelir Getirici Faaliyetler Listesi — SPEC-V2 §3.2E.
class IncomeActivityListScreen extends StatefulWidget {
  const IncomeActivityListScreen({super.key});

  @override
  State<IncomeActivityListScreen> createState() =>
      _IncomeActivityListScreenState();
}

class _IncomeActivityListScreenState extends State<IncomeActivityListScreen> {
  bool _loading = true;
  Object? _error;
  List<IncomeActivityRecord> _items = const [];

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
      final page = await context.api2.incomeActivities(limit: 200);
      if (!mounted) return;
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

  Future<void> _openForm([IncomeActivityRecord? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => IncomeActivityFormScreenV2(existing: existing),
    ));
    if (saved == true) _load();
  }

  Future<void> _delete(IncomeActivityRecord ia) async {
    final api = context.api2;
    if (!await confirmDelete(
        context, 'Gelir getirici faaliyet kaydı silinsin mi?')) {
      return;
    }
    try {
      await api.deleteIncomeActivity(ia.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gelir Getirici Faaliyetler')),
      body: AsyncListBody<IncomeActivityRecord>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.volunteer_activism_outlined,
        emptyMessage: S2.bosGelir,
        emptySubMessage: S2.bosListeAlt,
        header:
            InfoBlockHeader(blockKey: 'saha.gelir', api: context.api2),
        itemBuilder: (context, ia) => RecordCard(
          title: ia.name,
          trailingText: Formats.dateFromApi(ia.activityDate),
          lines: [
            [ia.activityTypeName, ia.provinceName, ia.orgUnitName]
                .whereType<String>()
                .where((e) => e.isNotEmpty)
                .join(' · '),
            'Gelir ${Formats.currency(ia.incomeAmount)} · '
                'Net ${Formats.currency(ia.netIncome)}',
          ],
          footer: Padding(
            padding: const EdgeInsets.only(top: s8),
            child: Wrap(
              spacing: s8,
              children: [
                if (ia.activityTypeName != null)
                  Chip(
                    label: Text(ia.activityTypeName!),
                    backgroundColor: kInfoContainer,
                    labelStyle: const TextStyle(color: kInfo, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          onTap: () => _openForm(ia),
          actions: context.isAdmin
              ? const [PopupMenuItem(value: 'delete', child: Text('Sil'))]
              : null,
          onAction: (v) {
            if (v == 'delete') _delete(ia);
          },
        ),
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Gelir Getirici Faaliyet',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Faaliyet')),
    );
  }
}
