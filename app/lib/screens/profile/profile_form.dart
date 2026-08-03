import '../../core/filepick/file_pick.dart';
import '../../core/strings_v2.dart';
import '../../core/validators.dart';
import '../../forms/field_spec.dart';
import '../../forms/form_controller.dart';
import '../../models/models_v2.dart';

/// Profil formunun alan anahtarları.
///
/// `Rol` bilinçli olarak `role` **değil** `role_label` anahtarıyla taşınır:
/// yalnız gösterim içindir ve hiçbir gövdeye sızamaz (§API-V2 `PATCH /auth/me`
/// `role` gönderimini 400 ile reddeder).
class ProfileFields {
  const ProfileFields._();

  static const name = 'name';
  static const email = 'email';
  static const phone = 'phone';
  static const roleLabel = 'role_label';
  static const regionId = 'region_id';
  static const provinceId = 'province_id';
  static const districtId = 'district_id';

  /// `PATCH /auth/me` gövdesine giren alanlar — tamamı budur.
  static const bodyKeys = [
    name,
    email,
    phone,
    regionId,
    provinceId,
    districtId,
  ];
}

/// Profil formunun alan tanımları — docs/UX-V2.md §4.2 R1 (kademeli seçim).
///
/// Bölge → İl → İlçe zinciri motorun kendi kuralıyla kurulur: üst alan boşken
/// alt alan devre dışıdır, üst alan değişince alt alanların değeri ve seçenek
/// listesi **koşulsuz** temizlenir.
List<FieldSpec> profileFieldSpecs({
  required OptionsBuilder regions,
  required OptionsBuilder provinces,
  required OptionsBuilder districts,
}) =>
    [
      const FieldSpec(
        key: ProfileFields.name,
        label: S2.profilAdSoyad,
        type: FieldType.text,
        required: true,
        requiredMessage: S2.vAdSoyad,
        section: S2.profilBilgileri,
      ),
      const FieldSpec(
        key: ProfileFields.email,
        label: S2.profilEposta,
        type: FieldType.email,
        required: true,
        requiredMessage: S2.vEpostaZorunlu,
        section: S2.profilBilgileri,
      ),
      const FieldSpec(
        key: ProfileFields.phone,
        label: '${S2.profilTelefon} (isteğe bağlı)',
        type: FieldType.text,
        hint: '05XX XXX XX XX',
        section: S2.profilBilgileri,
      ),
      const FieldSpec(
        key: ProfileFields.roleLabel,
        label: S2.profilRol,
        type: FieldType.readOnly,
        helper: S2.profilRolNotu,
        section: S2.profilBilgileri,
      ),
      FieldSpec(
        key: ProfileFields.regionId,
        label: S2.profilBolge,
        type: FieldType.lookup,
        emptyOptionLabel: S2.profilTumBolgeler,
        section: S2.profilTeskilat,
        optionsBuilder: regions,
      ),
      FieldSpec(
        key: ProfileFields.provinceId,
        label: S2.profilIl,
        type: FieldType.picker,
        parentKey: ProfileFields.regionId,
        emptyOptionLabel: S2.profilTumIller,
        section: S2.profilTeskilat,
        optionsBuilder: provinces,
      ),
      FieldSpec(
        key: ProfileFields.districtId,
        label: S2.profilIlce,
        type: FieldType.picker,
        parentKey: ProfileFields.provinceId,
        emptyOptionLabel: S2.profilTumIlceler,
        section: S2.profilTeskilat,
        optionsBuilder: districts,
      ),
    ];

/// `optionsBuilder` imzasının okunur adı.
typedef OptionsBuilder = Future<List<FormOption>> Function(
    Map<String, Object?> values);

/// `PATCH /auth/me` gövdesi.
///
/// Yalnız [ProfileFields.bodyKeys] üretilir: `role`, `is_active` ve
/// `must_change_password` **hiçbir koşulda** eklenmez.
Map<String, dynamic> profileUpdateBody(FormController controller) {
  final phone = controller.stringValue(ProfileFields.phone)?.trim();
  return <String, dynamic>{
    ProfileFields.name: controller.stringValue(ProfileFields.name)?.trim(),
    ProfileFields.email:
        controller.stringValue(ProfileFields.email)?.trim().toLowerCase(),
    ProfileFields.phone: (phone == null || phone.isEmpty) ? null : phone,
    ProfileFields.regionId: controller.intValue(ProfileFields.regionId),
    ProfileFields.provinceId: controller.intValue(ProfileFields.provinceId),
    ProfileFields.districtId: controller.intValue(ProfileFields.districtId),
  };
}

/// Gövdeye giremeyecek bir alan sızmış mı? (Testlerin ve `ApiV2.updateMe`'nin
/// ortak güvencesi.)
bool profileBodyIsSafe(Map<String, dynamic> body) =>
    !body.keys.any(const {'role', 'is_active', 'must_change_password'}.contains);

/// Sunucuya gitmeden önce yerelde yakalanan alan hataları.
Map<String, String> profileLocalErrors(FormController controller) {
  final errors = <String, String>{};
  final email = controller.stringValue(ProfileFields.email)?.trim() ?? '';
  if (email.isNotEmpty && !Validators.isValidEmail(email)) {
    errors[ProfileFields.email] = S2.vEposta;
  }
  final phone = controller.stringValue(ProfileFields.phone)?.trim() ?? '';
  if (phone.isNotEmpty && Validators.phone(phone) != null) {
    errors[ProfileFields.phone] = S2.vTelefonGecersiz;
  }
  return errors;
}

/// Seçilen profil fotoğrafının yerel doğrulaması (sunucu kuralının aynası).
String? avatarPickError(PickedFile file) {
  if (file.size == 0) return S2.avatarHataBos;
  if (file.size > Avatar.maxBytes) return S2.avatarHataBoyut;
  if (!Avatar.allowedExtensions.contains(file.extension)) {
    return S2.avatarHataTur;
  }
  return null;
}
