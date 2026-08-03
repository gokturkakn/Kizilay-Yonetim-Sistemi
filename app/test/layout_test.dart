import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/core/layout.dart';

/// Uyarlanabilir düzen — docs/UX-V2.md §1.1, §2.2, §8.1.
void main() {
  group('§1.1 — kırılma noktası seçimi', () {
    test('genişlik → düzen sınıfı tablosu', () {
      expect(layoutClassFor(320), LayoutClass.compact);
      expect(layoutClassFor(599.9), LayoutClass.compact);
      expect(layoutClassFor(600), LayoutClass.medium);
      expect(layoutClassFor(839), LayoutClass.medium);
      expect(layoutClassFor(840), LayoutClass.large);
      expect(layoutClassFor(1239), LayoutClass.large);
      expect(layoutClassFor(1240), LayoutClass.expanded);
      expect(layoutClassFor(1920), LayoutClass.expanded);
    });

    test('masaüstü penceresi küçülünce mobil düzene düşer', () {
      expect(layoutClassFor(1400).usesBottomBar, isFalse);
      expect(layoutClassFor(500).usesBottomBar, isTrue);
    });

    test('§2.2 — alt çubuk yalnız < 600, ray >= 600', () {
      expect(layoutClassFor(599).usesBottomBar, isTrue);
      expect(layoutClassFor(600).usesBottomBar, isFalse);
      expect(layoutClassFor(1239).usesExtendedRail, isFalse);
      expect(layoutClassFor(1240).usesExtendedRail, isTrue);
    });

    test('§2.2 — iki panelli düzen eşiği 840', () {
      expect(layoutClassFor(839).isTwoPane, isFalse);
      expect(layoutClassFor(840).isTwoPane, isTrue);
      expect(layoutClassFor(1300).isTwoPane, isTrue);
    });

    test('§5.1 — KPI ızgarası sütun ve yükseklik tablosu', () {
      expect(layoutClassFor(400).kpiColumns, 2);
      expect(layoutClassFor(700).kpiColumns, 3);
      expect(layoutClassFor(900).kpiColumns, 4);
      expect(layoutClassFor(1400).kpiColumns, 5);

      expect(layoutClassFor(400).kpiTileHeight, 96);
      expect(layoutClassFor(700).kpiTileHeight, 104);
      expect(layoutClassFor(900).kpiTileHeight, 104);
      expect(layoutClassFor(1400).kpiTileHeight, 112);
    });

    test('§5.1 — grafik kartları < 840 tek sütun', () {
      expect(layoutClassFor(500).chartColumns, 1);
      expect(layoutClassFor(839).chartColumns, 1);
      expect(layoutClassFor(840).chartColumns, 2);
    });

    test('§6.1 — gezinme kartı ızgarası', () {
      expect(layoutClassFor(400).navCardColumns, 1);
      expect(layoutClassFor(700).navCardColumns, 2);
      expect(layoutClassFor(1000).navCardColumns, 2);
      expect(layoutClassFor(1300).navCardColumns, 3);
    });
  });

  group('§2.2/§8.1 — hedefler ve rol görünürlüğü', () {
    // SPEC-V2-M6 §5.1 — Kılavuz ve Dokümanlar 6. ana modül olarak eklendi.
    test('genel_merkez 7 hedef görür (Dokümanlar dahil)', () {
      final d = destinationsForRole('genel_merkez');
      expect(d.length, 7);
      expect(d, [
        AppDestination.panel,
        AppDestination.teskilat,
        AppDestination.saha,
        AppDestination.lojistik,
        AppDestination.dokuman,
        AppDestination.yonetim,
        AppDestination.profil,
      ]);
    });

    test('saha 4 hedef görür; Panel ve Teşkilat render edilmez', () {
      final d = destinationsForRole('saha');
      expect(d, [
        AppDestination.saha,
        AppDestination.lojistik,
        AppDestination.dokuman,
        AppDestination.profil,
      ]);
      expect(d.contains(AppDestination.panel), isFalse);
      expect(d.contains(AppDestination.teskilat), isFalse);
      expect(d.contains(AppDestination.yonetim), isFalse);
    });

    test('giriş sonrası ilk hedef role göre değişir', () {
      expect(initialDestinationForRole('genel_merkez'), AppDestination.panel);
      expect(initialDestinationForRole('saha'), AppDestination.saha);
    });

    test('genel_merkez alt çubuğu 4 hedef + Daha Fazla = 5 sekme', () {
      final plan = bottomBarPlanForRole('genel_merkez');
      expect(plan.hasMore, isTrue);
      expect(plan.itemCount, 5);
      expect(plan.destinations, [
        AppDestination.panel,
        AppDestination.teskilat,
        AppDestination.saha,
        AppDestination.lojistik,
      ]);
    });

    // SPEC-V2-M6 §5.1 — saha 3 sekmeden 4'e çıkar:
    // Saha · Lojistik · Dokümanlar · Profil; `Daha Fazla` yine yoktur.
    test('saha alt çubuğu 4 sekmelidir ve Daha Fazla render edilmez', () {
      final plan = bottomBarPlanForRole('saha');
      expect(plan.hasMore, isFalse);
      expect(plan.itemCount, 4);
      expect(plan.destinations, [
        AppDestination.saha,
        AppDestination.lojistik,
        AppDestination.dokuman,
        AppDestination.profil,
      ]);
      expect(moreDestinationsForRole('saha'), isEmpty);
    });

    test('§5.1 — Dokümanlar: saha doğrudan sekme, genel merkez Daha Fazla', () {
      // saha: alt çubuğun kendisinde, `Daha Fazla` kuyruğunda değil.
      expect(bottomBarPlanForRole('saha').destinations,
          contains(AppDestination.dokuman));
      expect(moreDestinationsForRole('saha'),
          isNot(contains(AppDestination.dokuman)));

      // genel_merkez: alt çubuğa sığmaz → Yönetim Paneli ve Profil ile birlikte
      // `Daha Fazla` altına iner.
      expect(bottomBarPlanForRole('genel_merkez').destinations,
          isNot(contains(AppDestination.dokuman)));
      expect(moreDestinationsForRole('genel_merkez'), [
        AppDestination.dokuman,
        AppDestination.yonetim,
        AppDestination.profil,
      ]);
    });

    test('§5.1 — >= 600 rayda Dokümanlar her iki rolde tam hedeftir', () {
      // Ray hedefleri rolün tüm hedefleridir; `Daha Fazla` bölünmesi yoktur.
      expect(destinationsForRole('saha'), contains(AppDestination.dokuman));
      expect(
          destinationsForRole('genel_merkez'), contains(AppDestination.dokuman));
      expect(AppDestination.dokuman.fullLabel, 'Kılavuz ve Dokümanlar');
      expect(AppDestination.dokuman.shortLabel, 'Dokümanlar');
    });

    test('kırılma noktası geçişinde Daha Fazla kökü hedefe taşınır', () {
      expect(destinationAfterMoreCollapse('genel_merkez'),
          AppDestination.yonetim);
      expect(destinationAfterMoreCollapse('saha'), AppDestination.profil);
    });

    test('§2.3 — etiketler mobilde kısa, rayda tam', () {
      expect(AppDestination.panel.shortLabel, 'Panel');
      expect(AppDestination.panel.fullLabel, 'Raporlama ve Dashboard');
      expect(AppDestination.teskilat.shortLabel, 'Teşkilat');
      expect(AppDestination.teskilat.fullLabel, 'Teşkilatlanma');
      expect(AppDestination.saha.shortLabel, 'Saha');
      expect(AppDestination.saha.fullLabel, 'Saha Faaliyetleri');
    });

    test('her hedefin boş ve dolu ikonu farklıdır', () {
      for (final d in AppDestination.values) {
        expect(d.icon, isNot(d.selectedIcon), reason: d.name);
      }
    });
  });
}
