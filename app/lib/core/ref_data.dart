import '../models/models.dart';
import 'api.dart';
import 'strings.dart';

/// Referans veri önbelleği: iller, ilçeler, görev alanları, kurul/komisyonlar.
///
/// API kişi listelerinde ad alanları dönmezse konum etiketleri buradan
/// çözülür.
class RefData {
  RefData(this.api);

  final Api api;

  final Map<int, String> _personNames = {};
  List<Province>? _provinces;
  final Map<int, List<District>> _districtsByProvince = {};
  final Map<int, District> _districtById = {};
  List<TaskArea>? _taskAreas;
  List<Body>? _bodies;

  void clear() {
    _personNames.clear();
    _provinces = null;
    _districtsByProvince.clear();
    _districtById.clear();
    _taskAreas = null;
    _bodies = null;
  }

  Future<List<Province>> provinces() async {
    return _provinces ??= await api.provinces();
  }

  Future<List<District>> districtsOf(int provinceId) async {
    final cached = _districtsByProvince[provinceId];
    if (cached != null) return cached;
    final list = await api.districts(provinceId);
    _districtsByProvince[provinceId] = list;
    for (final d in list) {
      _districtById[d.id] = d;
    }
    return list;
  }

  Future<List<TaskArea>> taskAreas() async {
    return _taskAreas ??= await api.taskAreas();
  }

  Future<List<Body>> bodies() async {
    return _bodies ??= await api.bodies();
  }

  Future<Body?> kurulBody() async {
    final list = await bodies();
    for (final b in list) {
      if (b.isKurul) return b;
    }
    return null;
  }

  String? provinceNameSync(int id) {
    final list = _provinces;
    if (list == null) return null;
    for (final p in list) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  String? districtNameSync(int id) => _districtById[id]?.name;

  String? taskAreaNameSync(int id) {
    final list = _taskAreas;
    if (list == null) return null;
    for (final t in list) {
      if (t.id == id) return t.name;
    }
    return null;
  }

  String? bodyNameSync(int id) {
    final list = _bodies;
    if (list == null) return null;
    for (final b in list) {
      if (b.id == id) return b.name;
    }
    return null;
  }

  /// Verilen kişiler için gerekli il/ilçe adlarını önbelleğe alır.
  Future<void> primeForPersons(Iterable<Person> persons) async {
    await provinces();
    final needed = <int>{};
    for (final p in persons) {
      final did = p.districtId;
      if (did != null &&
          p.districtName == null &&
          !_districtById.containsKey(did)) {
        needed.add(p.provinceId);
      }
    }
    for (final pid in needed) {
      try {
        await districtsOf(pid);
      } catch (_) {
        // ad çözülemezse yalnız il gösterilir
      }
    }
  }

  /// Atama listesindeki kişi adlarını önbelleğe alır (API atama
  /// cevabında ad dönmezse kişi kaydından çözülür).
  Future<void> primeForAssignments(Iterable<Assignment> assignments) async {
    final needed = <int>{};
    for (final a in assignments) {
      if (a.personName == null && !_personNames.containsKey(a.personId)) {
        needed.add(a.personId);
      }
    }
    for (final id in needed) {
      try {
        final p = await api.personById(id);
        _personNames[id] = p.fullName;
      } catch (_) {
        // ad çözülemezse — gösterilir
      }
    }
  }

  String assignmentPersonName(Assignment a) =>
      a.personName ?? _personNames[a.personId] ?? Str.bos;

  /// Kişi kartı 2. satırı — UX §4.1.
  String personLocationLabel(Person p) {
    final province =
        p.provinceName ?? provinceNameSync(p.provinceId) ?? '';
    switch (p.unitType) {
      case 'ilce_teskilati':
        final district = p.districtName ??
            (p.districtId != null ? districtNameSync(p.districtId!) : null);
        if (district != null && district.isNotEmpty) {
          return '$province / $district';
        }
        return province;
      case 'temsilcilik':
        return '$province — ${Str.birimTemsilcilik}';
      case 'il_teskilati':
      default:
        return '$province — ${Str.birimIl}';
    }
  }
}
