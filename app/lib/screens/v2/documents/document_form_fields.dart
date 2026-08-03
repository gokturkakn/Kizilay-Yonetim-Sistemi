/// E-63 doküman formunun alan tanımı — SPEC-V2-M6 §5.2/4.
///
/// Ekrandan ayrı tutulur: `Kapsam` seçimine bağlı **koşullu görünürlük**
/// (§4.2 R2) `BuildContext` olmadan doğrulanabilsin diye.
library;

import '../../../core/strings_v2.dart';
import '../../../forms/field_spec.dart';
import '../../../models/models_v2.dart';

/// Kapsam seçenekleri — sözleşme sabiti (API-V2 §19.3), Tanımlar'dan gelmez.
///
/// Değerin kendisi zaten koddur; bu yüzden koşullu görünürlük [VisibleWhen
/// .anyValue] ile **ham değer** üzerinden kurulur — seçenek listesinin
/// yüklenmiş olmasına bağlı değildir. `code` yine de açıkça verilir ki
/// etiketten türetme (`İlçe` → `ilce`) tesadüfe kalmasın.
const List<FormOption> kDocumentScopeOptions = [
  FormOption(
      value: DocumentScope.genel,
      label: S2.dokKapsamGenel,
      code: DocumentScope.genel),
  FormOption(
      value: DocumentScope.bolge,
      label: S2.dokKapsamBolge,
      code: DocumentScope.bolge),
  FormOption(
      value: DocumentScope.il, label: S2.dokKapsamIl, code: DocumentScope.il),
  FormOption(
      value: DocumentScope.ilce,
      label: S2.dokKapsamIlce,
      code: DocumentScope.ilce),
];

typedef OptionsFor = Future<List<FormOption>> Function(Map<String, Object?>);

/// Alan listesi. Coğrafya kaynakları dışarıdan verilir (§4.2 R4 — kodda sabit
/// liste yok); testte sahte kaynak enjekte edilir.
///
/// Koşullu görünürlük (§5.2/4, R2):
/// * `bolge` → **Bölge**
/// * `il`    → **İl**
/// * `ilce`  → **İl** + **İlçe** (ilçe listesi ile kademelidir, R1)
/// * `genel` → hiçbiri; gizli alanlar gövdeye `null` gider ve sunucudaki
///   eski coğrafya değerleri temizlenir (API-V2 §19.3).
List<FieldSpec> documentFormFields({
  required OptionsFor regions,
  required OptionsFor provinces,
  required OptionsFor districts,
}) =>
    [
      const FieldSpec(
        key: 'title',
        label: S2.dokBaslik,
        type: FieldType.text,
        required: true,
        requiredMessage: S2.vDokBaslik,
        maxLength: 200,
        section: S2.dokBilgileri,
      ),
      const FieldSpec(
        key: 'category_id',
        label: S2.dokKategori,
        type: FieldType.lookup,
        lookupCategory: 'dokuman_kategorisi',
        required: true,
        requiredMessage: S2.vDokKategori,
        section: S2.dokBilgileri,
      ),
      const FieldSpec(
        key: 'version',
        label: S2.dokSurum,
        type: FieldType.text,
        maxLength: 50,
        hint: 'v2.1 / 2026 Revizyon',
        section: S2.dokBilgileri,
      ),
      const FieldSpec(
        key: 'published_at',
        label: S2.dokYayinTarihi,
        type: FieldType.date,
        section: S2.dokBilgileri,
      ),
      const FieldSpec(
        key: 'valid_until',
        label: S2.dokSonGecerlilik,
        type: FieldType.date,
        helper: 'Süresi geçen belgeler listede "Süresi doldu" ile işaretlenir.',
        section: S2.dokBilgileri,
      ),
      FieldSpec(
        key: 'scope',
        label: S2.dokKapsam,
        type: FieldType.segment,
        required: true,
        requiredMessage: S2.vDokKapsam,
        defaultValue: DocumentScope.genel,
        section: S2.dokKapsamBilgileri,
        optionsBuilder: (_) async => kDocumentScopeOptions,
      ),
      FieldSpec(
        key: 'region_id',
        label: S2.dokKapsamBolge,
        type: FieldType.picker,
        required: true,
        requiredMessage: S2.vDokBolge,
        visibleWhen:
            const VisibleWhen.anyValue('scope', [DocumentScope.bolge]),
        section: S2.dokKapsamBilgileri,
        optionsBuilder: regions,
      ),
      FieldSpec(
        key: 'province_id',
        label: S2.dokKapsamIl,
        type: FieldType.picker,
        required: true,
        requiredMessage: S2.vDokIl,
        visibleWhen: const VisibleWhen.anyValue(
          'scope',
          [DocumentScope.il, DocumentScope.ilce],
        ),
        section: S2.dokKapsamBilgileri,
        optionsBuilder: provinces,
      ),
      FieldSpec(
        key: 'district_id',
        label: S2.dokKapsamIlce,
        type: FieldType.picker,
        required: true,
        requiredMessage: S2.vDokIlce,
        parentKey: 'province_id',
        visibleWhen:
            const VisibleWhen.anyValue('scope', [DocumentScope.ilce]),
        section: S2.dokKapsamBilgileri,
        optionsBuilder: districts,
      ),
      const FieldSpec(
        key: 'description',
        label: S2.dokAciklama,
        type: FieldType.multiline,
        maxLength: 1000,
        section: FormSection.aciklama,
      ),
      const FieldSpec(
        key: 'ek_dokuman',
        label: S2.ekDokuman,
        type: FieldType.attachment,
        attachmentKind: 'dokuman',
        section: FormSection.ekler,
      ),
    ];
