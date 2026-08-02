import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/models_v2.dart';
import 'api_client.dart';
import 'api_v2.dart';

/// Tanım (lookup) önbelleği — docs/UX-V2.md §4.2 R4.
///
/// Listeler **oturum başına** önbelleğe alınır; `Tanımlar` modülünde kayıt
/// değişince [invalidate] ile geçersizleşir. Kodda sabit liste yazmak yasaktır.
class LookupCache extends ChangeNotifier {
  LookupCache(this.api);

  final ApiV2 api;

  final Map<String, List<LookupItem>> _items = {};
  final Map<String, Future<List<LookupItem>>> _inFlight = {};

  /// 404 dönen kategoriler — uç yoksa arayüz geri düşüş uygular
  /// (ör. `toplanti_platformu`, §4.3c).
  final Set<String> _missingCategories = {};

  List<Region>? _regions;
  final Map<int?, List<Province>> _provinces = {};
  final Map<int, List<District>> _districts = {};

  static String _key(String category, int? parentId) =>
      parentId == null ? category : '$category|$parentId';

  bool isCategoryMissing(String category) =>
      _missingCategories.contains(category);

  /// Önbellekte varsa senkron döner (form ilk çiziminde kullanılır).
  List<LookupItem>? peek(String category, {int? parentId}) =>
      _items[_key(category, parentId)];

  Future<List<LookupItem>> items(String category, {int? parentId}) {
    final key = _key(category, parentId);
    final cached = _items[key];
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _load(category, parentId, key);
    _inFlight[key] = future;
    return future;
  }

  Future<List<LookupItem>> _load(
      String category, int? parentId, String key) async {
    try {
      final list = await api.lookups(category,
          parentId: parentId, isActive: true);
      _items[key] = list;
      _missingCategories.remove(category);
      return list;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Kategori tanımlı değil — geri düşüş için işaretlenir, boş liste döner.
        _missingCategories.add(category);
        _items[key] = const [];
        return const [];
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<List<Region>> regions() async => _regions ??= await api.regions();

  List<Region>? get cachedRegions => _regions;

  Future<List<Province>> provinces({int? regionId}) async {
    final cached = _provinces[regionId];
    if (cached != null) return cached;
    final list = await api.provinces(regionId: regionId);
    _provinces[regionId] = list;
    return list;
  }

  List<Province>? cachedProvinces({int? regionId}) => _provinces[regionId];

  Future<List<District>> districts(int provinceId) async {
    final cached = _districts[provinceId];
    if (cached != null) return cached;
    final list = await api.districts(provinceId);
    _districts[provinceId] = list;
    return list;
  }

  /// İl → bölge eşlemesi (§4.3a: il seçilince Bölge otomatik dolar).
  Future<int?> regionOfProvince(int provinceId) async {
    final all = await provinces();
    for (final p in all) {
      if (p.id == provinceId) return p.regionId;
    }
    return null;
  }

  /// Tanımlar modülünde değişiklik olunca çağrılır.
  void invalidate([String? category]) {
    if (category == null) {
      _items.clear();
      _missingCategories.clear();
    } else {
      _items.removeWhere((k, _) => k == category || k.startsWith('$category|'));
      _missingCategories.remove(category);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _missingCategories.clear();
    _regions = null;
    _provinces.clear();
    _districts.clear();
  }
}
