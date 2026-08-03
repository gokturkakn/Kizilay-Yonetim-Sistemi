import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'strings_v2.dart';

/// Ekran genişlik sınıfı — docs/UX-V2.md §1.1.
///
/// Ölçüm **her zaman** `MediaQuery.sizeOf(context).width` ile yapılır;
/// cihaz türü tahmini yasaktır.
enum LayoutClass { compact, medium, large, expanded }

extension LayoutClassX on LayoutClass {
  /// `>= 840`: liste + detay tek Scaffold içinde iki panel olur (§2.2).
  bool get isTwoPane =>
      this == LayoutClass.large || this == LayoutClass.expanded;

  /// `< 600`: alt gezinme çubuğu; aksi hâlde gezinme rayı.
  bool get usesBottomBar => this == LayoutClass.compact;

  /// `>= 1240`: genişletilmiş (etiketli) ray.
  bool get usesExtendedRail => this == LayoutClass.expanded;

  /// KPI ızgarası sütun sayısı — §5.1.
  int get kpiColumns {
    switch (this) {
      case LayoutClass.compact:
        return 2;
      case LayoutClass.medium:
        return 3;
      case LayoutClass.large:
        return 4;
      case LayoutClass.expanded:
        return 5;
    }
  }

  /// KPI kutucuk yüksekliği — §5.1.
  double get kpiTileHeight {
    switch (this) {
      case LayoutClass.compact:
        return 96;
      case LayoutClass.medium:
        return 104;
      case LayoutClass.large:
        return 104;
      case LayoutClass.expanded:
        return 112;
    }
  }

  /// Grafik kartı ızgarası — §5.1: `< 840` tek sütun, aksi hâlde 2.
  int get chartColumns => isTwoPane ? 2 : 1;

  /// Gezinme kartı ızgarası (E-20): `<600` 1, `>=600` 2, `>=1240` 3.
  int get navCardColumns {
    switch (this) {
      case LayoutClass.compact:
        return 1;
      case LayoutClass.medium:
      case LayoutClass.large:
        return 2;
      case LayoutClass.expanded:
        return 3;
    }
  }
}

/// Genişlikten düzen sınıfı türetir — §1.1 tablosu.
LayoutClass layoutClassFor(double width) {
  if (width < kBpMedium) return LayoutClass.compact;
  if (width < kBpLarge) return LayoutClass.medium;
  if (width < kBpExpanded) return LayoutClass.large;
  return LayoutClass.expanded;
}

/// Bağlamdan düzen sınıfı.
LayoutClass layoutOf(BuildContext context) =>
    layoutClassFor(MediaQuery.sizeOf(context).width);

/// Tek hedef sıralaması, iki görünüm — §2.2.
///
/// `dokuman` (Kılavuz ve Dokümanlar) 6. ana modül olarak eklendi
/// (SPEC-V2-M6 §5.1). Sıralama **bağlayıcıdır**: alt çubuk ile "Daha Fazla"
/// bölünmesi bu sıradan türetilir (bkz. [bottomBarPlanForRole]).
enum AppDestination { panel, teskilat, saha, lojistik, dokuman, yonetim, profil }

/// Alt çubukta görünen sanal giriş (ray düzeninde yoktur).
const String kMoreDestinationKey = 'daha_fazla';

extension AppDestinationX on AppDestination {
  /// Alt çubuk etiketi (kısa) — §2.3.
  String get shortLabel {
    switch (this) {
      case AppDestination.panel:
        return 'Panel';
      case AppDestination.teskilat:
        return 'Teşkilat';
      case AppDestination.saha:
        return 'Saha';
      case AppDestination.lojistik:
        return 'Lojistik';
      case AppDestination.dokuman:
        return 'Dokümanlar';
      case AppDestination.yonetim:
        return 'Yönetim Paneli';
      case AppDestination.profil:
        return 'Profil';
    }
  }

  /// Ray etiketi (tam) — §2.3.
  String get fullLabel {
    switch (this) {
      case AppDestination.panel:
        return 'Raporlama ve Dashboard';
      case AppDestination.teskilat:
        return 'Teşkilatlanma';
      case AppDestination.saha:
        return 'Saha Faaliyetleri';
      case AppDestination.lojistik:
        return 'Lojistik';
      case AppDestination.dokuman:
        return S2.modulDokuman;
      case AppDestination.yonetim:
        return 'Yönetim Paneli';
      case AppDestination.profil:
        return 'Profil';
    }
  }

  /// `Daha Fazla` satırındaki alt yazı — E-90 (§6.6).
  String get moreSubtitle {
    switch (this) {
      case AppDestination.dokuman:
        return 'Kılavuzlar, formlar ve matbu belgeler';
      case AppDestination.yonetim:
        return 'Kullanıcılar, tanımlar ve ayarlar';
      case AppDestination.profil:
        return 'Hesap bilgileri ve çıkış';
      default:
        return fullLabel;
    }
  }

  IconData get icon {
    switch (this) {
      case AppDestination.panel:
        return Icons.dashboard_outlined;
      case AppDestination.teskilat:
        return Icons.account_tree_outlined;
      case AppDestination.saha:
        return Icons.volunteer_activism_outlined;
      case AppDestination.lojistik:
        return Icons.local_shipping_outlined;
      case AppDestination.dokuman:
        return Icons.menu_book_outlined;
      case AppDestination.yonetim:
        return Icons.settings_outlined;
      case AppDestination.profil:
        return Icons.person_outline;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case AppDestination.panel:
        return Icons.dashboard;
      case AppDestination.teskilat:
        return Icons.account_tree;
      case AppDestination.saha:
        return Icons.volunteer_activism;
      case AppDestination.lojistik:
        return Icons.local_shipping;
      case AppDestination.dokuman:
        return Icons.menu_book;
      case AppDestination.yonetim:
        return Icons.settings;
      case AppDestination.profil:
        return Icons.person;
    }
  }
}

/// Role göre görünür hedefler — §8.1 + SPEC-V2-M6 §5.1.
///
/// `genel_merkez`: 7 hedef · `saha`: Saha · Lojistik · Dokümanlar · Profil.
/// Kılavuz ve Dokümanlar **her iki rolde de** görünür; saha için okuma ve
/// indirme, genel merkez için ayrıca yükleme ve yayından kaldırma modülüdür.
List<AppDestination> destinationsForRole(String role) {
  if (role == 'saha') {
    return const [
      AppDestination.saha,
      AppDestination.lojistik,
      AppDestination.dokuman,
      AppDestination.profil,
    ];
  }
  return AppDestination.values;
}

/// Giriş sonrası açılan ilk hedef — §8.1.
AppDestination initialDestinationForRole(String role) =>
    role == 'saha' ? AppDestination.saha : AppDestination.panel;

/// Alt çubuk en fazla bu kadar öğe taşır — §2.2 (Material `NavigationBar`).
const int kMaxBottomBarItems = 5;

/// Alt çubukta (`< 600`) render edilecek hedefler — §2.2.
///
/// Tek kural, rol ayrımı yok: rolün hedefleri alt çubuğa **sığıyorsa** hepsi
/// sekmedir; sığmıyorsa ilk `kMaxBottomBarItems - 1` hedef sekme olur, kalanı
/// sanal `Daha Fazla` girişinin altına iner.
///
/// * `genel_merkez` (7 hedef): Panel · Teşkilat · Saha · Lojistik + Daha Fazla
///   (Dokümanlar, Yönetim Paneli, Profil) — SPEC-V2-M6 §5.1.
/// * `saha` (4 hedef): Saha · Lojistik · Dokümanlar · Profil, `Daha Fazla`
///   **render edilmez** (§8.1).
class BottomBarPlan {
  const BottomBarPlan({required this.destinations, required this.hasMore});

  final List<AppDestination> destinations;
  final bool hasMore;

  int get itemCount => destinations.length + (hasMore ? 1 : 0);
}

BottomBarPlan bottomBarPlanForRole(String role) {
  final all = destinationsForRole(role);
  if (all.length <= kMaxBottomBarItems) {
    return BottomBarPlan(destinations: all, hasMore: false);
  }
  return BottomBarPlan(
    destinations: all.take(kMaxBottomBarItems - 1).toList(growable: false),
    hasMore: true,
  );
}

/// `Daha Fazla` ekranında (E-90) listelenecek hedefler — alt çubuğa sığmayan
/// kuyruk. Alt çubukta `Daha Fazla` yoksa boş liste döner.
List<AppDestination> moreDestinationsForRole(String role) {
  final plan = bottomBarPlanForRole(role);
  if (!plan.hasMore) return const [];
  return destinationsForRole(role)
      .skip(plan.destinations.length)
      .toList(growable: false);
}

/// Kırılma noktası geçişi: `< 600` → `>= 600` sırasında `Daha Fazla`
/// kökündeyken hangi hedefe geçileceği (§2.2).
AppDestination destinationAfterMoreCollapse(String role) =>
    role == 'saha' ? AppDestination.profil : AppDestination.yonetim;
