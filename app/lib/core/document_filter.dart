/// Doküman listesi kapsam filtresi — API-V2 §19.4a.
///
/// Sunucuda **iki ayrı mod** vardır ve ikisi aynı istekte gönderilemez
/// (gönderilirse 400):
///
/// * **Bana uygulananlar** — `applicable_to=<düzey>:<id>`: kullanıcıyı
///   ilgilendiren her şey (ilçe + il + bölge + genel), en dardan en genişe.
///   Kütüphanenin **varsayılan** görünümüdür.
/// * **Birebir eşleşme** — `region_id` / `province_id` / `district_id`:
///   kapsamı tam olarak orası olan belgeler; `genel` kapsamı **hariç** kalır.
///   `Yalnız bana ait olanlar` anahtarı bu moda geçirir.
///
/// Bu dosya iki modun karışmasını **tek noktada** engeller: sorgu haritası
/// yalnız buradan üretilir, dolayısıyla iki mod hiçbir ekranda birleşemez.
library;

import '../models/models.dart';

/// `applicable_to` düzey adları — sözleşme sabiti (API-V2 §19.4a).
class DocumentScopeLevel {
  const DocumentScopeLevel._();

  static const region = 'region';
  static const province = 'province';
  static const district = 'district';
}

/// Kullanıcının coğrafi kırılımı — en dar bilinen düzey.
///
/// v2.1'de `users` tablosunda ilçe yoktur; `district` düzeyi sözleşmede
/// bulunduğu için desteklenir ama pratikte `province`/`region` gelir.
class UserScope {
  const UserScope({required this.level, required this.id});

  /// Kullanıcının en dar kırılımını seçer; hiçbiri yoksa `null`.
  static UserScope? of(AppUser? user) {
    if (user == null) return null;
    if (user.districtId != null) {
      return UserScope(level: DocumentScopeLevel.district, id: user.districtId!);
    }
    if (user.provinceId != null) {
      return UserScope(level: DocumentScopeLevel.province, id: user.provinceId!);
    }
    if (user.regionId != null) {
      return UserScope(level: DocumentScopeLevel.region, id: user.regionId!);
    }
    return null;
  }

  final String level;
  final int id;

  /// `applicable_to` parametre değeri: `district:64`.
  String get applicableTo => '$level:$id';

  /// Birebir eşleşme parametresinin adı: `district_id` / `province_id` / …
  String get exactKey => '${level}_id';
}

/// Bir doküman listesi isteğinin tüm filtreleri.
class DocumentFilter {
  const DocumentFilter({
    this.categoryId,
    this.query,
    this.scope,
    this.onlyMine = false,
    this.isActive,
  });

  final int? categoryId;

  /// `q` — başlık + açıklama, Türkçe büyük/küçük harf duyarsız (sunucuda).
  final String? query;

  /// `scope` çipi (`genel` | `bolge` | `il` | `ilce`); `applicable_to` ile
  /// birlikte gönderilebilir — çakışan yalnız coğrafya kimlikleridir.
  final String? scope;

  /// `Yalnız bana ait olanlar` — birebir eşleşme moduna geçirir.
  final bool onlyMine;

  final bool? isActive;

  DocumentFilter copyWith({
    int? categoryId,
    String? query,
    String? scope,
    bool? onlyMine,
    bool? isActive,
    bool clearCategory = false,
    bool clearScope = false,
    bool clearQuery = false,
  }) =>
      DocumentFilter(
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        query: clearQuery ? null : (query ?? this.query),
        scope: clearScope ? null : (scope ?? this.scope),
        onlyMine: onlyMine ?? this.onlyMine,
        isActive: isActive ?? this.isActive,
      );

  /// Sorgu parametreleri. **İki kapsam modu asla birlikte üretilmez.**
  ///
  /// * `onlyMine == false` → kullanıcının kırılımı varsa `applicable_to`.
  /// * `onlyMine == true`  → yalnız `<düzey>_id` birebir eşleşmesi.
  /// * Kırılımı olmayan kullanıcı (ör. ülke geneli genel merkez hesabı) →
  ///   coğrafya parametresi hiç gönderilmez; liste tüm kapsamları döner.
  Map<String, Object?> params(AppUser? user) {
    final out = <String, Object?>{
      if (categoryId != null) 'category_id': categoryId,
      if (scope != null && scope!.isNotEmpty) 'scope': scope,
      if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
      if (isActive != null) 'is_active': isActive! ? 1 : 0,
    };
    final userScope = UserScope.of(user);
    if (userScope == null) return out;
    if (onlyMine) {
      out[userScope.exactKey] = userScope.id;
    } else {
      out['applicable_to'] = userScope.applicableTo;
    }
    return out;
  }

  /// Anahtar yoksa anahtar da hiç gönderilmez — bkz. [params].
  static const List<String> exactGeoKeys = [
    'region_id',
    'province_id',
    'district_id',
  ];

  /// İki modun karıştığı bir sorguyu **istemcide** yakalar (sunucu 400 döner).
  static bool hasConflict(Map<String, Object?> params) =>
      params['applicable_to'] != null &&
      exactGeoKeys.any((k) => params[k] != null);
}
