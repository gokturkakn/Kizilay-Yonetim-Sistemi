import 'package:flutter/foundation.dart';

import '../core/strings_v2.dart';
import 'field_spec.dart';

/// Bir seçim alanının seçenek durumu.
class OptionsState {
  const OptionsState({
    this.options = const [],
    this.loading = false,
    this.loaded = false,
    this.failed = false,
  });

  final List<FormOption> options;
  final bool loading;
  final bool loaded;
  final bool failed;

  /// §4.2 R5 — 15 kuralı: 15'ten fazla seçenek aranabilir seçici ile açılır.
  bool get useSearchPicker => options.length > 15;

  bool get isEmptyList => loaded && options.isEmpty;
}

/// Lookup kategorisi için seçenek çözücü. Kademeli alanlarda [parentValue]
/// dolu gelir (`?parent_id=`).
typedef LookupResolver = Future<List<FormOption>> Function(
  String category,
  Object? parentValue,
);

/// `DynamicForm` motorunun durum ve kural çekirdeği — docs/UX-V2.md §4.
///
/// Widget'tan bağımsızdır: 12 kuralın tamamı burada uygulanır ve doğrudan
/// birim testi ile sınanır.
class FormController extends ChangeNotifier {
  FormController({
    required this.fields,
    Map<String, Object?>? initialValues,
    this.lookupResolver,
    this.roleIsSaha = false,
  }) {
    for (final f in fields) {
      if (f.defaultValue != null) _values[f.key] = f.defaultValue;
    }
    if (initialValues != null) {
      initialValues.forEach((k, v) {
        if (v != null) _values[k] = v;
      });
    }
    _initialSnapshot = Map<String, Object?>.from(_values);
  }

  final List<FieldSpec> fields;
  final LookupResolver? lookupResolver;

  /// `saha` rolünde boş liste yardımcı metni farklıdır (§4.2 R4).
  final bool roleIsSaha;

  final Map<String, Object?> _values = {};
  final Map<String, OptionsState> _options = {};

  /// §4.2 R2.3 — gizlenen alanın girdisi oturum belleğinde tutulur.
  final Map<String, Object?> _hiddenMemory = {};

  /// Sunucudan gelen alan bazlı hatalar (409/400 eşlemesi).
  final Map<String, String> _serverErrors = {};

  late Map<String, Object?> _initialSnapshot;

  /// §4.2 R8 — ilk doğrulama `Kaydet`e basınca.
  bool _submitted = false;
  bool _saving = false;

  bool get submitted => _submitted;
  bool get saving => _saving;

  Map<String, Object?> get values => Map.unmodifiable(_values);

  /// §4.2 R9 — kirli form çıkışı.
  bool get isDirty {
    if (_values.length != _initialSnapshot.length) return true;
    for (final e in _values.entries) {
      if (_initialSnapshot[e.key] != e.value) return true;
    }
    return false;
  }

  FieldSpec? specFor(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  Object? value(String key) => _values[key];

  String? stringValue(String key) {
    final v = _values[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int? intValue(String key) {
    final v = _values[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  OptionsState optionsFor(String key) => _options[key] ?? const OptionsState();

  /// Seçili seçeneğin kodu — koşullu görünürlük bunu okur.
  ///
  /// Sunucu `code` alanını boş bırakırsa addan türetilen kod kullanılır
  /// ([FormOption.effectiveCode]).
  String? codeOf(String key) {
    final v = _values[key];
    if (v == null) return null;
    for (final o in optionsFor(key).options) {
      if (o.value == v) return o.effectiveCode;
    }
    return null;
  }

  FormOption? selectedOption(String key) {
    final v = _values[key];
    if (v == null) return null;
    for (final o in optionsFor(key).options) {
      if (o.value == v) return o;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // R2 — koşullu görünürlük (özyinelemeli)
  // -------------------------------------------------------------------------

  /// §4.2 R2.6 — `visibleWhen` zincirlenebilir; gizli alana bağlı alan da
  /// gizlidir.
  bool isVisible(FieldSpec spec, [Set<String>? seen]) {
    final cond = spec.visibleWhen;
    if (cond == null) return true;
    final guard = seen ?? <String>{};
    if (!guard.add(spec.key)) return true; // döngü koruması
    final parent = specFor(cond.key);
    if (parent != null && !isVisible(parent, guard)) return false;

    final raw = _values[cond.key];
    if (cond.isNotNull) return raw != null && raw.toString().isNotEmpty;
    if (cond.equalsValue != null) return raw == cond.equalsValue;
    final rawList = cond.inValues;
    if (rawList != null) return raw != null && rawList.contains(raw);
    final code = codeOf(cond.key);
    if (cond.equalsCode != null) return code == cond.equalsCode;
    final list = cond.inCodes;
    if (list != null) return code != null && list.contains(code);
    return true;
  }

  bool isVisibleKey(String key) {
    final spec = specFor(key);
    return spec == null ? false : isVisible(spec);
  }

  List<FieldSpec> get visibleFields =>
      fields.where(isVisible).toList(growable: false);

  // -------------------------------------------------------------------------
  // R1 — kademeli seçim
  // -------------------------------------------------------------------------

  /// §4.2 R1.1 — üst alan boşken alan devre dışıdır.
  bool isEnabled(FieldSpec spec) {
    if (spec.locked) return false;
    if (_saving) return false;
    for (final pk in spec.parentKeys) {
      if (_values[pk] == null) return false;
    }
    return true;
  }

  /// §4.2 R1.1 — devre dışıyken gösterilecek ipucu: `Önce {üst alan} seçin.`
  String? disabledHint(FieldSpec spec) {
    for (final pk in spec.parentKeys) {
      if (_values[pk] == null) {
        final parent = specFor(pk);
        return S2.onceSecin(parent?.label ?? pk);
      }
    }
    return null;
  }

  /// Yardımcı metin: boş liste durumu (§4.2 R4) veya alanın kendi helper'ı.
  String? helperFor(FieldSpec spec) {
    final state = optionsFor(spec.key);
    if (spec.type.needsOptions && state.isEmptyList && isEnabled(spec)) {
      if (spec.emptyListHelper != null) return spec.emptyListHelper;
      return roleIsSaha ? S2.listeYokSaha : S2.listeYok;
    }
    return spec.helper;
  }

  /// Alan değeri atar; kademeli çocukları koşulsuz temizler (§4.2 R1.3),
  /// gizlenen alanların girdisini belleğe alır (§4.2 R2.3).
  void setValue(String key, Object? value, {bool silent = false}) {
    final before = _visibilityMap();
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _serverErrors.remove(key);
    _clearDescendants(key);
    _syncHiddenMemory(before);
    if (!silent) notifyListeners();
  }

  /// Birden çok alanı tek turda atar (bağlamdan ön dolu form açılışı).
  void setValues(Map<String, Object?> patch, {bool markPristine = false}) {
    final before = _visibilityMap();
    patch.forEach((k, v) {
      if (v == null) {
        _values.remove(k);
      } else {
        _values[k] = v;
      }
      _clearDescendants(k);
    });
    _syncHiddenMemory(before);
    if (markPristine) _initialSnapshot = Map<String, Object?>.from(_values);
    notifyListeners();
  }

  /// §4.2 R1.3/R1.4 — çocuk (ve torun) değerleri koşulsuz temizlenir.
  void _clearDescendants(String key) {
    for (final f in fields) {
      if (f.parentKeys.contains(key)) {
        final had = _values.containsKey(f.key);
        _values.remove(f.key);
        _options.remove(f.key); // liste yeniden yüklenecek
        _serverErrors.remove(f.key);
        if (had) _clearDescendants(f.key);
      }
    }
  }

  Map<String, bool> _visibilityMap() => {
        for (final f in fields)
          if (f.visibleWhen != null) f.key: isVisible(f),
      };

  /// §4.2 R2.3 — gizlenirken değer belleğe alınır, tekrar görünürken geri gelir.
  /// §4.2 R2.5 — gizlenirken alan hatası temizlenir.
  void _syncHiddenMemory(Map<String, bool> before) {
    for (final f in fields) {
      if (f.visibleWhen == null) continue;
      final wasVisible = before[f.key] ?? true;
      final nowVisible = isVisible(f);
      if (wasVisible && !nowVisible) {
        final v = _values.remove(f.key);
        if (v != null) _hiddenMemory[f.key] = v;
        _serverErrors.remove(f.key);
      } else if (!wasVisible && nowVisible) {
        final remembered = _hiddenMemory.remove(f.key);
        if (remembered != null && _values[f.key] == null) {
          _values[f.key] = remembered;
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Seçenek yükleme (R4, R5)
  // -------------------------------------------------------------------------

  /// Alanın seçeneklerini (yeniden) yükler. Kademeli alanlarda üst değer
  /// boşsa hiçbir şey yapılmaz (§4.2 R1.1).
  Future<void> loadOptions(FieldSpec spec, {bool force = false}) async {
    if (!spec.type.needsOptions && spec.optionsBuilder == null) return;
    final existing = _options[spec.key];
    if (!force && existing != null && (existing.loaded || existing.loading)) {
      return;
    }
    for (final pk in spec.parentKeys) {
      if (_values[pk] == null) {
        _options[spec.key] = const OptionsState();
        return;
      }
    }
    _options[spec.key] = OptionsState(
      options: existing?.options ?? const [],
      loading: true,
    );
    notifyListeners();
    try {
      List<FormOption> list;
      if (spec.optionsBuilder != null) {
        list = await spec.optionsBuilder!(Map<String, Object?>.from(_values));
      } else if (spec.lookupCategory != null && lookupResolver != null) {
        final parentValue = spec.parentKeys.isEmpty
            ? null
            : _values[spec.parentKeys.first];
        list = await lookupResolver!(spec.lookupCategory!, parentValue);
      } else {
        list = const [];
      }
      _options[spec.key] = OptionsState(options: list, loaded: true);
      // Seçili değer artık listede yoksa temizlenir.
      final current = _values[spec.key];
      if (current != null && !list.any((o) => o.value == current)) {
        _values.remove(spec.key);
        _clearDescendants(spec.key);
      }
    } catch (_) {
      _options[spec.key] =
          const OptionsState(options: [], loaded: true, failed: true);
    }
    notifyListeners();
  }

  /// Görünür ve yüklenebilir tüm alanların seçeneklerini yükler.
  Future<void> loadAllOptions() async {
    for (final f in fields) {
      if (!isVisible(f)) continue;
      await loadOptions(f);
    }
  }

  /// Test ve ön dolu bağlam için seçenekleri doğrudan yerleştirir.
  void seedOptions(String key, List<FormOption> options) {
    _options[key] = OptionsState(options: options, loaded: true);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // R3, R8 — doğrulama
  // -------------------------------------------------------------------------

  /// Tek alan doğrulaması. Gizli alan **doğrulanmaz** (§4.2 R3).
  String? validateField(FieldSpec spec) {
    if (!isVisible(spec)) return null;
    final server = _serverErrors[spec.key];
    if (server != null) return server;

    final raw = _values[spec.key];
    final text = raw?.toString().trim() ?? '';

    if (spec.required && text.isEmpty) return spec.autoRequiredMessage;
    if (text.isEmpty) return null;

    switch (spec.type) {
      case FieldType.number:
        final n = int.tryParse(text);
        if (n == null) return S2.vSayi;
        final max = spec.maxValue ?? 999999;
        final min = spec.minValue ?? 0;
        if (n < min || n > max) {
          if (spec.minValue != null && spec.minValue! >= 1 && n < spec.minValue!) {
            return spec.autoRequiredMessage;
          }
          return S2.vSayiAralik;
        }
      case FieldType.decimal:
        final n = parseDecimal(text);
        if (n == null) return spec.invalidMessage ?? S2.vSureBicim;
        if (n < 0) return spec.invalidMessage ?? S2.vSureBicim;
      case FieldType.text:
      case FieldType.multiline:
        if (spec.minLength != null && text.length < spec.minLength!) {
          return spec.key == 'location'
              ? S2.vToplantiYeriKisa
              : '${spec.label} en az ${spec.minLength} karakter olmalıdır.';
        }
      case FieldType.date:
        if (spec.noFutureDates) {
          final d = DateTime.tryParse(text);
          if (d != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            if (d.isAfter(today)) return S2.vIleriTarih;
          }
        }
      default:
        break;
    }
    return null;
  }

  /// Tüm görünür alanları doğrular; hata varsa ilk hatalı alanın key'ini
  /// döndürür (§4.2 R8 — o alana kaydırılır ve odaklanılır).
  String? validateAll() {
    _submitted = true;
    String? first;
    for (final f in fields) {
      final err = validateField(f);
      if (err != null && first == null) first = f.key;
    }
    notifyListeners();
    return first;
  }

  bool get isValid {
    for (final f in fields) {
      if (validateField(f) != null) return false;
    }
    return true;
  }

  /// Kullanıcıya gösterilecek hata (R8: ilk `Kaydet`ten önce gösterilmez).
  String? displayError(FieldSpec spec) {
    if (!_submitted && !_touched.contains(spec.key)) {
      return _serverErrors[spec.key];
    }
    return validateField(spec);
  }

  final Set<String> _touched = {};

  void markTouched(String key) {
    if (_touched.add(key)) notifyListeners();
  }

  /// Sunucudan gelen alan bazlı hata (§11.2 CONFLICT vb.).
  void setServerError(String key, String message) {
    _serverErrors[key] = message;
    _submitted = true;
    notifyListeners();
  }

  void clearServerErrors() {
    if (_serverErrors.isEmpty) return;
    _serverErrors.clear();
    notifyListeners();
  }

  void setSaving(bool v) {
    _saving = v;
    notifyListeners();
  }

  void markPristine() {
    _initialSnapshot = Map<String, Object?>.from(_values);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Gövde üretimi
  // -------------------------------------------------------------------------

  /// API gövdesi — §4.2 R2.2.
  ///
  /// * Görünür alan → değeri (tip dönüşümü uygulanmış).
  /// * Gizli alan → açıkça `null` (sunucu eski değeri temizleyebilsin diye).
  /// * `omitWhenHidden` gizli alan → anahtar **hiç konmaz** (meetings 400).
  /// * `attachment` / `readOnly` alanları gövdeye girmez.
  Map<String, dynamic> buildBody() {
    final body = <String, dynamic>{};
    for (final f in fields) {
      if (f.type == FieldType.attachment || f.type == FieldType.readOnly) {
        continue;
      }
      final visible = isVisible(f);
      if (!visible) {
        if (f.omitWhenHidden) continue;
        body[f.key] = null;
        continue;
      }
      body[f.key] = _encode(f, _values[f.key]);
    }
    return body;
  }

  Object? _encode(FieldSpec spec, Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    switch (spec.type) {
      case FieldType.number:
        return int.tryParse(text);
      case FieldType.decimal:
        return parseDecimal(text);
      case FieldType.switchField:
        return raw is bool ? raw : text == 'true';
      default:
        return raw is String ? text : raw;
    }
  }

  /// §4.4 — Türkçe virgüllü ondalık (`2,5`) → API ondalık saat (`2.5`).
  static double? parseDecimal(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  /// API ondalık → ekran biçimi (`2.5` → `2,5`).
  static String formatDecimal(num? value) {
    if (value == null) return '';
    final s = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return s.replaceAll('.', ',');
  }
}
