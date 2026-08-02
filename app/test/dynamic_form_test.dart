import 'package:flutter_test/flutter_test.dart';
import 'package:teskilat_yonetim/forms/field_spec.dart';
import 'package:teskilat_yonetim/forms/form_controller.dart';

/// Sahte tanım kaynağı — docs/UX-V2.md §4.2 R4 (kodda sabit liste yasak;
/// testte kaynak enjekte edilir).
class _FakeLookups {
  _FakeLookups(this.data);

  final Map<String, List<FormOption>> data;
  final List<String> calls = [];

  Future<List<FormOption>> resolve(String category, Object? parentValue) async {
    calls.add(parentValue == null ? category : '$category?parent_id=$parentValue');
    if (parentValue != null) {
      return (data[category] ?? const [])
          .where((o) => o.parentId == parentValue)
          .toList();
    }
    return data[category] ?? const [];
  }
}

FormController _meetingForm(_FakeLookups lookups) => FormController(
      fields: const [
        FieldSpec(
          key: 'meeting_type_id',
          label: 'Toplantı Türü',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_turu',
          required: true,
        ),
        FieldSpec(
          key: 'method_id',
          label: 'Toplantı Yöntemi',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_yontemi',
          required: true,
          requiredMessage: 'Toplantı yöntemi seçin.',
        ),
        // §4.3(c) — yalnız Yüz Yüze; gizliyken anahtar gövdeye konmaz.
        FieldSpec(
          key: 'location',
          label: 'Toplantı Yeri',
          type: FieldType.text,
          required: true,
          maxLength: 120,
          minLength: 3,
          requiredMessage: 'Toplantı yerini girin.',
          visibleWhen: VisibleWhen.code('method_id', 'yuz_yuze'),
          omitWhenHidden: true,
        ),
        FieldSpec(
          key: 'platform',
          label: 'Platform',
          type: FieldType.lookup,
          lookupCategory: 'toplanti_platformu',
          required: true,
          requiredMessage: 'Platform seçin.',
          visibleWhen: VisibleWhen.code('method_id', 'cevrim_ici'),
          omitWhenHidden: true,
        ),
        // Zincirli koşul (R2.6): gizli alana bağlı alan da gizlidir.
        FieldSpec(
          key: 'platform_name',
          label: 'Platform Adı',
          type: FieldType.text,
          required: true,
          requiredMessage: 'Platform adını girin.',
          visibleWhen: VisibleWhen.code('platform', 'diger'),
        ),
      ],
      lookupResolver: lookups.resolve,
    );

void main() {
  _codeFallbackTests();
  final meetingLookups = _FakeLookups({
    'toplanti_turu': const [
      FormOption(value: 100, label: 'Koordinasyon Kurulu Toplantısı', code: 'kurul'),
      FormOption(value: 101, label: 'Komisyon Toplantısı', code: 'komisyon'),
    ],
    'toplanti_yontemi': const [
      FormOption(value: 108, label: 'Yüz Yüze', code: 'yuz_yuze'),
      FormOption(value: 109, label: 'Çevrim İçi', code: 'cevrim_ici'),
    ],
    'toplanti_platformu': const [
      FormOption(value: 200, label: 'Zoom', code: 'zoom'),
      FormOption(value: 204, label: 'Diğer', code: 'diger'),
    ],
  });

  group('R2 — koşullu alan (Toplantı Yöntemi → Yer / Platform, §4.3c)', () {
    test('yöntem boşken Yer ve Platform gizlidir; anahtarlar gövdeye konmaz',
        () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();

      expect(c.isVisibleKey('location'), isFalse);
      expect(c.isVisibleKey('platform'), isFalse);

      final body = c.buildBody();
      expect(body.containsKey('location'), isFalse);
      expect(body.containsKey('platform'), isFalse);
    });

    test('Yüz Yüze seçilince Yer görünür ve zorunlu, Platform gizli kalır',
        () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();
      c.setValue('method_id', 108); // yuz_yuze

      expect(c.isVisibleKey('location'), isTrue);
      expect(c.isVisibleKey('platform'), isFalse);

      final locationSpec = c.specFor('location')!;
      expect(c.validateField(locationSpec), 'Toplantı yerini girin.');

      c.setValue('location', 'Genel Merkez Toplantı Salonu');
      final body = c.buildBody();
      expect(body['location'], 'Genel Merkez Toplantı Salonu');
      expect(body.containsKey('platform'), isFalse,
          reason: 'R2.2 istisnası: uymayan alan gövdeye hiç konmaz');
    });

    test('Çevrim İçi seçilince Platform görünür, Yer gizlenir ve atlanır',
        () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();
      c.setValue('method_id', 109); // cevrim_ici
      await c.loadOptions(c.specFor('platform')!);

      expect(c.isVisibleKey('platform'), isTrue);
      expect(c.isVisibleKey('location'), isFalse);

      c.setValue('platform', 200); // Zoom
      final body = c.buildBody();
      expect(body['platform'], 200);
      expect(body.containsKey('location'), isFalse);
    });

    test('R2.3 — gizlenen alanın girdisi oturum belleğinde korunur', () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();

      c.setValue('method_id', 108);
      c.setValue('location', 'Ankara Şube Salonu');

      // Kullanıcı yanlışlıkla Çevrim İçi'ne geçiyor → Yer gizlenir.
      c.setValue('method_id', 109);
      expect(c.value('location'), isNull);

      // Geri dönünce yazdığı geri gelir.
      c.setValue('method_id', 108);
      expect(c.value('location'), 'Ankara Şube Salonu');
    });

    test('R2.6 — zincirli koşul: Platform gizliyken Platform Adı da gizlidir',
        () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();

      c.setValue('method_id', 109);
      await c.loadOptions(c.specFor('platform')!);
      c.setValue('platform', 204); // Diğer
      expect(c.isVisibleKey('platform_name'), isTrue);

      // Yöntem Yüz Yüze'ye dönünce Platform gizlenir → torun da gizlenir.
      c.setValue('method_id', 108);
      expect(c.isVisibleKey('platform'), isFalse);
      expect(c.isVisibleKey('platform_name'), isFalse);
    });

    test('R3 — gizli zorunlu alan Kaydet\'i bloklamaz', () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();
      c.setValue('meeting_type_id', 100);
      c.setValue('method_id', 109);
      await c.loadOptions(c.specFor('platform')!);
      c.setValue('platform', 200); // Zoom (Diğer değil → Platform Adı gizli)

      // Gizli 'location' ve 'platform_name' zorunlu ama doğrulanmaz.
      expect(c.validateAll(), isNull);
      expect(c.isValid, isTrue);
    });

    test('gizli alan hatası temizlenir (R2.5)', () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();
      c.setValue('method_id', 108);
      c.validateAll();
      expect(c.validateField(c.specFor('location')!), isNotNull);

      c.setValue('method_id', 109);
      expect(c.validateField(c.specFor('location')!), isNull);
    });

    test('Toplantı Yeri en az 3 karakter kuralı', () async {
      final c = _meetingForm(meetingLookups);
      await c.loadAllOptions();
      c.setValue('method_id', 108);
      c.setValue('location', 'AB');
      expect(c.validateField(c.specFor('location')!),
          'Toplantı yeri en az 3 karakter olmalıdır.');
    });
  });

  group('R1 — kademeli seçim (Bölge → İl → İlçe)', () {
    FormController buildGeo(_FakeLookups lookups) => FormController(
          fields: const [
            FieldSpec(
                key: 'region_id',
                label: 'Bölge',
                type: FieldType.lookup,
                lookupCategory: 'bolge',
                required: true),
            FieldSpec(
                key: 'province_id',
                label: 'İl',
                type: FieldType.picker,
                lookupCategory: 'il',
                parentKey: 'region_id',
                required: true),
            FieldSpec(
                key: 'district_id',
                label: 'İlçe',
                type: FieldType.picker,
                lookupCategory: 'ilce',
                parentKey: 'province_id',
                emptyOptionLabel: 'İl geneli'),
          ],
          lookupResolver: lookups.resolve,
        );

    final geo = _FakeLookups({
      'bolge': const [
        FormOption(value: 1, label: 'Marmara', code: 'marmara'),
        FormOption(value: 4, label: 'İç Anadolu', code: 'ic_anadolu'),
      ],
      'il': const [
        FormOption(value: 34, label: 'İstanbul', parentId: 1),
        FormOption(value: 6, label: 'Ankara', parentId: 4),
      ],
      'ilce': const [
        FormOption(value: 25, label: 'Çankaya', parentId: 6),
        FormOption(value: 26, label: 'Keçiören', parentId: 6),
      ],
    });

    test('R1.1 — üst alan boşken çocuk devre dışı ve ipucu gösterir', () {
      final c = buildGeo(geo);
      final province = c.specFor('province_id')!;
      expect(c.isEnabled(province), isFalse);
      expect(c.disabledHint(province), 'Önce Bölge seçin.');
    });

    test('R1.2 — üst seçilince çocuk listesi parent_id ile yeniden yüklenir',
        () async {
      final lookups = _FakeLookups(geo.data);
      final c = buildGeo(lookups);
      c.setValue('region_id', 4);
      await c.loadOptions(c.specFor('province_id')!);

      expect(lookups.calls, contains('il?parent_id=4'));
      expect(c.optionsFor('province_id').options.single.label, 'Ankara');
    });

    test('R1.3 — üst değişince çocuk ve torun koşulsuz temizlenir', () async {
      final c = buildGeo(geo);
      c.setValue('region_id', 4);
      await c.loadOptions(c.specFor('province_id')!);
      c.setValue('province_id', 6);
      await c.loadOptions(c.specFor('district_id')!);
      c.setValue('district_id', 25);

      expect(c.value('district_id'), 25);

      c.setValue('region_id', 1); // bölge değişti
      expect(c.value('province_id'), isNull);
      expect(c.value('district_id'), isNull);
    });

    test('R1.4 — üst temizlenince çocuk temizlenir ve tekrar devre dışı olur',
        () async {
      final c = buildGeo(geo);
      c.setValue('region_id', 4);
      await c.loadOptions(c.specFor('province_id')!);
      c.setValue('province_id', 6);

      c.setValue('region_id', null);
      expect(c.value('province_id'), isNull);
      expect(c.isEnabled(c.specFor('province_id')!), isFalse);
    });

    test('R1.5 — üst alan formda her zaman çocuğun üstündedir', () {
      final c = buildGeo(geo);
      for (final f in c.fields) {
        for (final pk in f.parentKeys) {
          final parentIndex = c.fields.indexWhere((e) => e.key == pk);
          final childIndex = c.fields.indexOf(f);
          expect(parentIndex, lessThan(childIndex),
              reason: '${f.key} üstü $pk daha sonra geliyor');
        }
      }
    });

    test('seçili değer yeni listede yoksa temizlenir', () async {
      final c = buildGeo(geo);
      c.setValue('region_id', 4);
      await c.loadOptions(c.specFor('province_id')!);
      c.setValue('province_id', 6);
      // Liste bölge 1 için yeniden yüklenirse Ankara kalmaz.
      c.setValues({'region_id': 1});
      await c.loadOptions(c.specFor('province_id')!, force: true);
      expect(c.value('province_id'), isNull);
    });
  });

  group('R7 — matris (Eğitim: Kategori × Yöntem → Konu)', () {
    final trainingLookups = _FakeLookups({
      'egitim_kategorisi': const [
        FormOption(value: 78, label: 'Gönüllü', code: 'gonullu'),
        FormOption(value: 79, label: 'Halka Açık', code: 'halka_acik'),
      ],
      'egitim_yontemi': const [
        FormOption(value: 80, label: 'Yüz Yüze', code: 'yuz_yuze'),
        FormOption(value: 81, label: 'Çevrim İçi', code: 'cevrim_ici'),
      ],
    });

    FormController build() => FormController(
          fields: [
            const FieldSpec(
                key: 'category_id',
                label: 'Kategori',
                type: FieldType.segment,
                lookupCategory: 'egitim_kategorisi',
                required: true,
                requiredMessage: 'Eğitim kategorisi seçin.'),
            const FieldSpec(
                key: 'method_id',
                label: 'Yöntem',
                type: FieldType.segment,
                lookupCategory: 'egitim_yontemi',
                required: true,
                requiredMessage: 'Eğitim yöntemi seçin.'),
            FieldSpec(
              key: 'topic_id',
              label: 'Konu',
              type: FieldType.picker,
              parentKey: 'category_id,method_id',
              required: true,
              requiredMessage: 'Eğitim konusu seçin.',
              emptyListHelper: 'Bu kategori ve yöntem için tanımlı konu bulunmuyor.',
              optionsBuilder: (values) async {
                if (values['category_id'] == 78 && values['method_id'] == 80) {
                  return const [FormOption(value: 60, label: 'İlk Yardım')];
                }
                return const [];
              },
            ),
          ],
          lookupResolver: trainingLookups.resolve,
        );

    test('iki boyut da seçilene kadar Konu devre dışıdır', () {
      final c = build();
      final topic = c.specFor('topic_id')!;
      expect(c.isEnabled(topic), isFalse);
      c.setValue('category_id', 78);
      expect(c.isEnabled(topic), isFalse);
      c.setValue('method_id', 80);
      expect(c.isEnabled(topic), isTrue);
    });

    test('boyut değişince Konu değeri temizlenir (R1.3 davranışı)', () async {
      final c = build();
      c.setValue('category_id', 78);
      c.setValue('method_id', 80);
      await c.loadOptions(c.specFor('topic_id')!);
      c.setValue('topic_id', 60);
      expect(c.value('topic_id'), 60);

      c.setValue('method_id', 81);
      expect(c.value('topic_id'), isNull);
    });

    test('kombinasyon için konu yoksa özel yardımcı metin gösterilir',
        () async {
      final c = build();
      c.setValue('category_id', 79);
      c.setValue('method_id', 81);
      await c.loadOptions(c.specFor('topic_id')!);
      expect(c.optionsFor('topic_id').isEmptyList, isTrue);
      expect(c.helperFor(c.specFor('topic_id')!),
          'Bu kategori ve yöntem için tanımlı konu bulunmuyor.');
    });
  });

  group('R4/R5 — tanım kaynağı ve 15 kuralı', () {
    test('boş liste yardımcı metni role göre değişir', () async {
      final empty = _FakeLookups({'gorev_unvani': const []});
      for (final saha in [false, true]) {
        final c = FormController(
          fields: const [
            FieldSpec(
                key: 'role_id',
                label: 'Görev',
                type: FieldType.lookup,
                lookupCategory: 'gorev_unvani',
                required: true),
          ],
          lookupResolver: empty.resolve,
          roleIsSaha: saha,
        );
        await c.loadAllOptions();
        final helper = c.helperFor(c.specFor('role_id')!)!;
        expect(helper.startsWith('Bu liste henüz tanımlanmamış.'), isTrue);
        expect(helper.contains('Genel merkez ile iletişime geçin.'), saha);
      }
    });

    test('15 ve altı → dropdown, 15 üstü → aranabilir seçici', () async {
      List<FormOption> gen(int n) => List.generate(
          n, (i) => FormOption(value: i, label: 'Seçenek $i'));
      final small = _FakeLookups({'k': gen(15)});
      final large = _FakeLookups({'k': gen(16)});

      Future<bool> usesPicker(_FakeLookups l) async {
        final c = FormController(
          fields: const [
            FieldSpec(
                key: 'k', label: 'K', type: FieldType.lookup, lookupCategory: 'k'),
          ],
          lookupResolver: l.resolve,
        );
        await c.loadAllOptions();
        return c.optionsFor('k').useSearchPicker;
      }

      expect(await usesPicker(small), isFalse);
      expect(await usesPicker(large), isTrue);
    });
  });

  group('R8/R12 — doğrulama ve gövde üretimi', () {
    test('§4.7 otomatik mesaj kalıbı: seçim "seçin.", yazı "girin."', () {
      const choice =
          FieldSpec(key: 'a', label: 'Bölge', type: FieldType.lookup, required: true);
      const input =
          FieldSpec(key: 'b', label: 'Eğitmen', type: FieldType.text, required: true);
      const optional = FieldSpec(
          key: 'c',
          label: 'Açıklama (isteğe bağlı)',
          type: FieldType.multiline,
          required: true);

      expect(choice.autoRequiredMessage, 'Bölge seçin.');
      expect(input.autoRequiredMessage, 'Eğitmen girin.');
      expect(optional.autoRequiredMessage, 'Açıklama girin.',
          reason: '" (isteğe bağlı)" eki mesaja taşınmaz');
    });

    test('validateAll ilk hatalı alanın key değerini döndürür', () {
      final c = FormController(fields: const [
        FieldSpec(key: 'a', label: 'A', type: FieldType.text),
        FieldSpec(key: 'b', label: 'B', type: FieldType.text, required: true),
        FieldSpec(key: 'c', label: 'C', type: FieldType.text, required: true),
      ]);
      expect(c.validateAll(), 'b');
      c.setValue('b', 'dolu');
      expect(c.validateAll(), 'c');
    });

    test('sayı alanı 0–999.999 aralığında doğrulanır', () {
      final c = FormController(fields: const [
        FieldSpec(
            key: 'volunteer_count',
            label: 'Gönüllü Sayısı',
            type: FieldType.number,
            required: true),
      ]);
      final spec = c.specFor('volunteer_count')!;
      expect(c.validateField(spec), 'Gönüllü Sayısı girin.');
      c.setValue('volunteer_count', '0');
      expect(c.validateField(spec), isNull);
      c.setValue('volunteer_count', '1000000');
      expect(c.validateField(spec), '0 ile 999.999 arasında bir değer girin.');
    });

    test('§4.4 — Süre virgüllü girilir, gövdeye ondalık nokta ile gider', () {
      final c = FormController(fields: const [
        FieldSpec(
            key: 'duration_hours',
            label: 'Süre (saat)',
            type: FieldType.decimal,
            required: true),
      ]);
      c.setValue('duration_hours', '2,5');
      expect(c.validateField(c.specFor('duration_hours')!), isNull);
      expect(c.buildBody()['duration_hours'], 2.5);
      expect(FormController.formatDecimal(2.5), '2,5');
      expect(FormController.formatDecimal(3), '3');
    });

    test('§4.5 — ileri tarihli faaliyet kaydı reddedilir', () {
      final c = FormController(fields: const [
        FieldSpec(
            key: 'task_date',
            label: 'Tarih',
            type: FieldType.date,
            required: true,
            noFutureDates: true),
      ]);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      c.setValue('task_date',
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}');
      expect(c.validateField(c.specFor('task_date')!),
          'İleri tarihli kayıt girilemez.');
    });

    test('gizli alan gövdeye açıkça null gider (omitWhenHidden hariç)', () {
      final c = FormController(fields: const [
        FieldSpec(key: 'method_id', label: 'Yöntem', type: FieldType.lookup),
        FieldSpec(
            key: 'tracking_no',
            label: 'Kargo Takip No',
            type: FieldType.text,
            visibleWhen: VisibleWhen.filled('method_id')),
      ]);
      final body = c.buildBody();
      expect(body.containsKey('tracking_no'), isTrue);
      expect(body['tracking_no'], isNull);
    });

    test('R9 — kirli form tespiti', () {
      final c = FormController(
        fields: const [FieldSpec(key: 'a', label: 'A', type: FieldType.text)],
        initialValues: const {'a': 'x'},
      );
      expect(c.isDirty, isFalse);
      c.setValue('a', 'y');
      expect(c.isDirty, isTrue);
      c.markPristine();
      expect(c.isDirty, isFalse);
    });

    test('R11 — kilitli alan devre dışıdır', () {
      final c = FormController(fields: const [
        FieldSpec(
            key: 'org_unit_id',
            label: 'Teşkilat Birimi',
            type: FieldType.orgPicker,
            locked: true),
      ]);
      expect(c.isEnabled(c.specFor('org_unit_id')!), isFalse);
    });

    test('sunucu hatası alan altında gösterilir', () {
      final c = FormController(fields: const [
        FieldSpec(key: 'person_id', label: 'Kişi', type: FieldType.personPicker),
      ]);
      c.setServerError('person_id', 'Bu kişi bu birimde zaten görevli.');
      expect(c.displayError(c.specFor('person_id')!),
          'Bu kişi bu birimde zaten görevli.');
      c.setValue('person_id', 5);
      expect(c.displayError(c.specFor('person_id')!), isNull);
    });
  });
}

/// Sunucu `lookup_items.code` alanını boş bırakır (tohumlanan 143 kalemin
/// tamamı `null` döner) — koşullu görünürlük yine de çalışmalıdır.
void _codeFallbackTests() {
  group('kod geri düşüşü — API code alanı boşken §4.3(c) dalı çalışır', () {
    test('Türkçe ad → kod türetimi UX-V2 kodlarıyla eşleşir', () {
      expect(FormOption.slugifyTr('Yüz Yüze'), 'yuz_yuze');
      expect(FormOption.slugifyTr('Çevrim İçi'), 'cevrim_ici');
      expect(FormOption.slugifyTr('Diğer'), 'diger');
      expect(FormOption.slugifyTr('Kargo'), 'kargo');
      expect(FormOption.slugifyTr('Gönüllü'), 'gonullu');
      expect(FormOption.slugifyTr('Halka Açık'), 'halka_acik');
      expect(FormOption.slugifyTr('Elden Teslim'), 'elden_teslim');
    });

    test('code doluysa ada bakılmaz', () {
      const withCode =
          FormOption(value: 1, label: 'Yüz Yüze', code: 'ozel_kod');
      expect(withCode.effectiveCode, 'ozel_kod');
    });

    test('code null iken Yüz Yüze / Çevrim İçi dalı doğru alanı gösterir',
        () async {
      // Sunucunun gerçekte döndürdüğü biçim: code == null.
      final lookups = _FakeLookups({
        'toplanti_turu': const [
          FormOption(value: 100, label: 'Koordinasyon Kurulu Toplantısı'),
        ],
        'toplanti_yontemi': const [
          FormOption(value: 65, label: 'Yüz Yüze'),
          FormOption(value: 66, label: 'Çevrim İçi'),
        ],
        'toplanti_platformu': const [
          FormOption(value: 200, label: 'Zoom'),
          FormOption(value: 204, label: 'Diğer'),
        ],
      });
      final c = _meetingForm(lookups);
      await c.loadAllOptions();

      c.setValue('method_id', 65); // Yüz Yüze
      expect(c.isVisibleKey('location'), isTrue);
      expect(c.isVisibleKey('platform'), isFalse);

      c.setValue('method_id', 66); // Çevrim İçi
      await c.loadOptions(c.specFor('platform')!);
      expect(c.isVisibleKey('platform'), isTrue);
      expect(c.isVisibleKey('location'), isFalse);

      c.setValue('platform', 204); // Diğer → Platform Adı görünür
      expect(c.isVisibleKey('platform_name'), isTrue);
    });
  });
}
