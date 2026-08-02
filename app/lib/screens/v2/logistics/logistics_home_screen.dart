import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'material_request_list_screen.dart';
import 'shipment_list_screen.dart';
import 'stock_list_screen.dart';

/// E-50 · Lojistik Ana Ekranı — docs/UX-V2.md §6.3.
///
/// `saha` rolü yalnız `Malzeme Talepleri` kartını görür; özet şeritte yalnız
/// `Açık Talep` sayısı gösterilir (§8.1).
class LogisticsHomeScreen extends StatefulWidget {
  const LogisticsHomeScreen({super.key});

  @override
  State<LogisticsHomeScreen> createState() => _LogisticsHomeScreenState();
}

class _LogisticsHomeScreenState extends State<LogisticsHomeScreen> {
  DashboardSummary? _summary;
  int _delivered = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await context.api2.dashboardSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _delivered = summary.deliveredRequests;
      });
    } catch (_) {
      // özet çekilemezse şerit `—` gösterir
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = context.isAdmin;
    final s = _summary;
    String v(int? n) => n == null ? '—' : Formats.number(n);

    return Scaffold(
      appBar: AppBar(title: const Text(S2.modulLojistik)),
      body: SingleChildScrollView(
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoBlockHeader(blockKey: 'lojistik.genel', api: context.api2),
              Padding(
                padding: const EdgeInsets.all(s16),
                child: Wrap(
                  spacing: s16,
                  runSpacing: s8,
                  children: [
                    Text('Açık Talep ${v(s?.openRequests)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kTextSecondary)),
                    if (isAdmin) ...[
                      Text('Yolda ${v(s?.shipmentCount)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary)),
                      Text('Teslim Edilen ${v(s == null ? null : _delivered)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(s16, 0, s16, s16),
                child: NavCardGrid(cards: [
                  NavCard(
                    title: 'Malzeme Talepleri',
                    subtitle: 'Teşkilatlardan gelen talepler',
                    icon: Icons.playlist_add_check_outlined,
                    onTap: () => _open(const MaterialRequestListScreen()),
                  ),
                  // §8.1 — Gönderiler ve Stok `saha` rolünde hiç render edilmez.
                  if (isAdmin) ...[
                    NavCard(
                      title: 'Gönderiler',
                      subtitle: 'Kargo ve teslimat kayıtları',
                      icon: Icons.local_shipping_outlined,
                      onTap: () => _open(const ShipmentListScreen()),
                    ),
                    NavCard(
                      title: 'Stok Durumu',
                      subtitle: 'Ürün stokları ve hareketleri',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => _open(const StockListScreen()),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
