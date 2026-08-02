import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../../widgets/status_widgets.dart';
import '../shared.dart';
import 'org_unit_list_screen.dart';

/// E-20 · Teşkilatlanma Ana Ekranı — docs/UX-V2.md §6.1.
class OrgHomeScreen extends StatefulWidget {
  const OrgHomeScreen({super.key});

  @override
  State<OrgHomeScreen> createState() => _OrgHomeScreenState();
}

class _OrgHomeScreenState extends State<OrgHomeScreen> {
  OrgUnitSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await context.api2.orgUnitSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false); // özet şerit `—` gösterir
    }
  }

  void _open(OrgModule module) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrgUnitListScreen(module: module),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text(S2.modulTeskilatlanma)),
      body: SingleChildScrollView(
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusSummaryStrip(
                aktif: s?.aktif ?? 0,
                pasif: s?.pasif ?? 0,
                teskilatYok: s?.teskilatYok ?? 0,
                loading: _loading || s == null,
              ),
              Padding(
                padding: const EdgeInsets.all(s16),
                child: NavCardGrid(
                  cards: [
                    for (final m in OrgModule.values)
                      NavCard(
                        title: m.title,
                        subtitle: m.subtitle,
                        icon: m.icon,
                        onTap: () => _open(m),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Teşkilatlanma alt modülleri (E-21…E-26) — hepsi aynı iskeleti kullanır.
enum OrgModule {
  koordinasyonKurulu,
  bolgeTemsilcileri,
  komisyonlar,
  ilBaskanliklari,
  ilceBaskanliklari,
  temsilcilikler,
}

extension OrgModuleX on OrgModule {
  String get title {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return 'Koordinasyon Kurulu';
      case OrgModule.bolgeTemsilcileri:
        return 'Bölge Temsilcileri';
      case OrgModule.komisyonlar:
        return 'Komisyonlar';
      case OrgModule.ilBaskanliklari:
        return 'İl Kadın Başkanlıkları';
      case OrgModule.ilceBaskanliklari:
        return 'İlçe Kadın Başkanlıkları';
      case OrgModule.temsilcilikler:
        return 'Temsilcilikler';
    }
  }

  String get subtitle {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return 'Kurul üyeleri ve görevlendirmeleri';
      case OrgModule.bolgeTemsilcileri:
        return '7 bölge ve temsilcileri';
      case OrgModule.komisyonlar:
        return 'Komisyonlar ve üyelikleri';
      case OrgModule.ilBaskanliklari:
        return '81 il başkanlığı';
      case OrgModule.ilceBaskanliklari:
        return 'İlçe başkanlıkları';
      case OrgModule.temsilcilikler:
        return 'İl ve ilçe temsilcilikleri';
    }
  }

  IconData get icon {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return Icons.account_balance_outlined;
      case OrgModule.bolgeTemsilcileri:
        return Icons.map_outlined;
      case OrgModule.komisyonlar:
        return Icons.diversity_3_outlined;
      case OrgModule.ilBaskanliklari:
        return Icons.location_city_outlined;
      case OrgModule.ilceBaskanliklari:
        return Icons.holiday_village_outlined;
      case OrgModule.temsilcilikler:
        return Icons.storefront_outlined;
    }
  }

  /// `org_units.type` karşılığı.
  String get unitType {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return OrgUnitType.koordinasyonKurulu;
      case OrgModule.bolgeTemsilcileri:
        return OrgUnitType.bolgeTemsilciligi;
      case OrgModule.komisyonlar:
        return OrgUnitType.komisyon;
      case OrgModule.ilBaskanliklari:
        return OrgUnitType.ilBaskanligi;
      case OrgModule.ilceBaskanliklari:
        return OrgUnitType.ilceBaskanligi;
      case OrgModule.temsilcilikler:
        return OrgUnitType.temsilcilik;
    }
  }

  /// §6.1.1 bilgilendirme metni anahtarı.
  String get contentKey {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return 'teskilatlanma.koordinasyon_kurulu';
      case OrgModule.bolgeTemsilcileri:
        return 'teskilatlanma.bolge_temsilcileri';
      case OrgModule.komisyonlar:
        return 'teskilatlanma.komisyonlar';
      case OrgModule.ilBaskanliklari:
        return 'teskilatlanma.il_baskanliklari';
      case OrgModule.ilceBaskanliklari:
        return 'teskilatlanma.ilce_baskanliklari';
      case OrgModule.temsilcilikler:
        return 'teskilatlanma.temsilcilikler';
    }
  }

  /// Filtre sonucu boşsa gösterilecek metin (§9.7).
  String get emptyMessage {
    switch (this) {
      case OrgModule.koordinasyonKurulu:
        return S2.bosKurul;
      case OrgModule.bolgeTemsilcileri:
        return S2.bosBolge;
      case OrgModule.komisyonlar:
        return S2.bosKomisyon;
      case OrgModule.ilBaskanliklari:
        return S2.bosIlBaskanlik;
      case OrgModule.ilceBaskanliklari:
        return S2.bosIlce;
      case OrgModule.temsilcilikler:
        return S2.bosTemsilcilik;
    }
  }

  /// E-25 önce il seçimi ister.
  bool get requiresProvince => this == OrgModule.ilceBaskanliklari;

  String get searchHint {
    switch (this) {
      case OrgModule.ilBaskanliklari:
        return 'İl ara...';
      case OrgModule.ilceBaskanliklari:
        return 'İlçe ara...';
      case OrgModule.temsilcilikler:
        return 'Temsilcilik ara...';
      default:
        return 'Ara...';
    }
  }
}
