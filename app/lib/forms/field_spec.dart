/// Dinamik form alan tanımı — docs/UX-V2.md §4.1.
library;

enum FieldType {
  text,
  multiline,
  number,
  decimal,
  date,
  dateRange,
  lookup,
  picker,
  orgPicker,
  personPicker,
  segment,
  matrix,
  attachment,
  switchField,
  readOnly,
  password,
  email,
}

extension FieldTypeX on FieldType {
  /// §4.7 — otomatik hata mesajı kalıbı.
  ///
  /// Seçim alanları `{Etiket} seçin.`, yazılan alanlar `{Etiket} girin.`
  bool get isChoice {
    switch (this) {
      case FieldType.lookup:
      case FieldType.picker:
      case FieldType.segment:
      case FieldType.matrix:
      case FieldType.orgPicker:
      case FieldType.personPicker:
      case FieldType.date:
      case FieldType.dateRange:
        return true;
      default:
        return false;
    }
  }

  /// Seçenek listesi gerektiren alanlar.
  bool get needsOptions =>
      this == FieldType.lookup ||
      this == FieldType.picker ||
      this == FieldType.segment;
}

/// Koşullu görünürlük — §4.2 R2.
class VisibleWhen {
  const VisibleWhen({
    required this.key,
    this.equalsCode,
    this.inCodes,
    this.equalsValue,
    this.isNotNull = false,
  });

  /// Alanın `code` değeri belirtilene eşitse görünür.
  const VisibleWhen.code(String key, String code)
      : this(key: key, equalsCode: code);

  /// Alanın ham değeri belirtilene eşitse görünür (metin alanları için).
  const VisibleWhen.value(String key, Object value)
      : this(key: key, equalsValue: value);

  /// Alan doluysa görünür.
  const VisibleWhen.filled(String key) : this(key: key, isNotNull: true);

  final String key;
  final String? equalsCode;
  final List<String>? inCodes;
  final Object? equalsValue;
  final bool isNotNull;
}

/// Bir seçim alanının tek seçeneği.
class FormOption {
  const FormOption({
    required this.value,
    required this.label,
    this.code,
    this.parentId,
    this.subtitle,
  });

  factory FormOption.fromLookup(dynamic item) {
    // LookupItem alanlarını yapısal okur (paket bağımlılığı olmadan test edilebilir).
    return FormOption(
      value: item.id,
      label: item.name,
      code: item.code,
      parentId: item.parentId,
    );
  }

  final Object value;
  final String label;
  final String? code;
  final int? parentId;
  final String? subtitle;

  /// Koşullu görünürlükte (§4.2 R2) karşılaştırılan kod.
  ///
  /// `lookup_items.code` sunucuda **boş bırakılabilir** (tohumlanan 143
  /// kalemin tamamı `null` döner). Bu durumda kod, addan Türkçe-duyarlı
  /// olarak türetilir: `Yüz Yüze` → `yuz_yuze`, `Çevrim İçi` → `cevrim_ici`,
  /// `Diğer` → `diger`. Böylece §4.3(c) dal değişimi, yönetici Tanımlar'dan
  /// kod girmemiş olsa bile çalışır.
  String get effectiveCode =>
      (code != null && code!.isNotEmpty) ? code! : slugifyTr(label);

  /// Türkçe karakterleri koruyarak kod üretir (ç→c, ğ→g, ı/İ→i, ö→o, ş→s, ü→u).
  static String slugifyTr(String input) {
    const map = {
      'ç': 'c', 'Ç': 'c',
      'ğ': 'g', 'Ğ': 'g',
      'ı': 'i', 'I': 'i', 'İ': 'i', 'i': 'i',
      'ö': 'o', 'Ö': 'o',
      'ş': 's', 'Ş': 's',
      'ü': 'u', 'Ü': 'u',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final mapped = map[ch] ?? ch.toLowerCase();
      if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
        buffer.write(mapped);
      } else if (mapped == ' ' || mapped == '-' || mapped == '_') {
        buffer.write('_');
      }
    }
    return buffer.toString().replaceAll(RegExp('_+'), '_').replaceAll(
        RegExp(r'^_|_$'), '');
  }

  @override
  bool operator ==(Object other) =>
      other is FormOption && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Alan tanımı — §4.1.
class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.lookupCategory,
    this.parentKey,
    this.visibleWhen,
    this.requiredMessage,
    this.helper,
    this.hint,
    this.maxLength,
    this.minLength,
    this.section,
    this.omitWhenHidden = false,
    this.locked = false,
    this.emptyOptionLabel,
    this.optionsBuilder,
    this.attachmentKind,
    this.attachmentMultiple = true,
    this.defaultValue,
    this.noFutureDates = false,
    this.maxValue,
    this.minValue,
    this.emptyListHelper,
    this.autocompleteKey,
  });

  /// API alan adı, ör. `district_id`.
  final String key;

  /// Ekranda görünen Türkçe etiket (UX-V2'den aynen).
  final String label;
  final FieldType type;

  /// Görünürken zorunlu mu (§4.2 R3).
  final bool required;

  /// `type == lookup/picker/segment` → tanım kategorisi kodu.
  final String? lookupCategory;

  /// Kademeli seçim (§4.2 R1): üst alanın key'i.
  ///
  /// Matris alanlarında (§4.2 R7) iki bağımsız boyut virgülle verilir:
  /// `'category_id,method_id'` — boyutlardan biri değişince çocuk temizlenir.
  final String? parentKey;

  /// Koşullu görünürlük (§4.2 R2).
  final VisibleWhen? visibleWhen;

  /// Boş bırakılırsa §4.7 kalıbı üretilir.
  final String? requiredMessage;
  final String? helper;
  final String? hint;
  final int? maxLength;
  final int? minLength;

  /// §4.2 R12 — bölüm başlığı.
  final String? section;

  /// §4.2 R2.2 istisnası: gizliyken gövdeye **hiç konmaz** (yalnız
  /// `/meetings` `location` ve `platform` alanlarında kullanılır).
  final bool omitWhenHidden;

  /// §4.2 R11 — bağlamdan ön dolu ve değiştirilemez.
  final bool locked;

  /// Boş seçenek etiketi (ör. İlçe → `İl geneli`).
  final String? emptyOptionLabel;

  /// Lookup dışı kaynaklardan seçenek üretir (bölge, il, ilçe, talep…).
  final Future<List<FormOption>> Function(Map<String, Object?> values)?
      optionsBuilder;

  /// Ek türü (§7.1) — `type == attachment`.
  final String? attachmentKind;
  final bool attachmentMultiple;

  final Object? defaultValue;

  /// §4.5 — faaliyet kayıtlarında ileri tarih yasak.
  final bool noFutureDates;

  final num? maxValue;
  final num? minValue;

  /// Liste boş dönünce gösterilecek özel yardımcı metin
  /// (ör. `Bu görev türü için tanımlı alt görev bulunmuyor.`).
  final String? emptyListHelper;

  /// Serbest metin + otomatik tamamlama anahtarı (E-42 `Şube`).
  final String? autocompleteKey;

  /// Kademeli seçimde üst alan(lar)ın key listesi.
  List<String> get parentKeys {
    final p = parentKey;
    if (p == null || p.isEmpty) return const [];
    return p.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  bool get isCascaded => parentKeys.isNotEmpty;

  /// §4.7 — otomatik hata mesajı kalıbı.
  ///
  /// Etiketteki ` (isteğe bağlı)` eki mesaja taşınmaz.
  String get autoRequiredMessage {
    if (requiredMessage != null) return requiredMessage!;
    final clean = label.replaceAll(' (isteğe bağlı)', '').trim();
    return type.isChoice ? '$clean seçin.' : '$clean girin.';
  }

  FieldSpec copyWith({
    bool? required,
    bool? locked,
    String? helper,
    Object? defaultValue,
  }) =>
      FieldSpec(
        key: key,
        label: label,
        type: type,
        required: required ?? this.required,
        lookupCategory: lookupCategory,
        parentKey: parentKey,
        visibleWhen: visibleWhen,
        requiredMessage: requiredMessage,
        helper: helper ?? this.helper,
        hint: hint,
        maxLength: maxLength,
        minLength: minLength,
        section: section,
        omitWhenHidden: omitWhenHidden,
        locked: locked ?? this.locked,
        emptyOptionLabel: emptyOptionLabel,
        optionsBuilder: optionsBuilder,
        attachmentKind: attachmentKind,
        attachmentMultiple: attachmentMultiple,
        defaultValue: defaultValue ?? this.defaultValue,
        noFutureDates: noFutureDates,
        maxValue: maxValue,
        minValue: minValue,
        emptyListHelper: emptyListHelper,
        autocompleteKey: autocompleteKey,
      );
}

/// §4.2 R12 — standart bölüm adları. Bu adların dışına çıkılmaz.
class FormSection {
  const FormSection._();

  static const konum = 'Konum Bilgileri';
  static const faaliyet = 'Faaliyet Bilgileri';
  static const sayisal = 'Sayısal Bilgiler';
  static const aciklama = 'Açıklama';
  static const ekler = 'Ekler';

  // Modüle özgü ek başlıklar (§6'da adı geçenler).
  static const egitim = 'Eğitim Bilgileri';
  static const gonderi = 'Gönderi Bilgileri';
  static const teslim = 'Teslim';
  static const katilim = 'Katılım';
  static const kimlik = 'Kimlik Bilgileri';
  static const iletisim = 'İletişim';
  static const gorev = 'Görev Bilgileri';
}
