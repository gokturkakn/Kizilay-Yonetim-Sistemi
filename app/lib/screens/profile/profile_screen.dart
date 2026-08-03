import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_v2.dart';
import '../../core/config.dart';
import '../../core/filepick/file_pick.dart';
import '../../core/lookup_cache.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../core/strings_v2.dart';
import '../../forms/dynamic_form.dart';
import '../../forms/form_controller.dart';
import '../../models/models.dart';
import '../../models/models_v2.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/info_block.dart';
import '../../widgets/user_avatar.dart';
import '../v2/shared.dart';
import 'password_change_screen.dart';
import 'profile_form.dart';

/// E-80 · Profil — docs/UX-V2.md §6.6.
///
/// Her rol kendi hesabını buradan düzenler: fotoğraf, ad soyad, e-posta,
/// telefon ve teşkilat kırılımı (Bölge → İl → İlçe). Rol **salt okunur**dur;
/// yalnız genel merkez değiştirebilir (`PATCH /auth/me` `role` gönderimini
/// 400 ile reddeder, istemci de hiç göndermez).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<DynamicFormState> _formKey = GlobalKey<DynamicFormState>();

  FormController? _controller;
  UserAccount? _account;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  /// Profil düzenleme ucu sunucuda yoksa (404) form salt okunur kalır.
  bool _selfEditUnavailable = false;

  Avatar? _avatar;
  Uint8List? _avatarPreview;
  bool _avatarBusy = false;
  String? _avatarError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  LookupCache get _cache => context.lookups;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<Session>();
    final account = await _fetchAccount(session);
    if (!mounted) return;
    if (account == null) {
      setState(() => _loading = false);
      return;
    }

    // İl doluyken bölge boşsa zincir üstten tamamlanır; aksi hâlde İl alanı
    // "Önce Bölge seçin." diyerek kilitli görünürdü (§4.2 R1.1).
    var regionId = account.regionId;
    if (regionId == null && account.provinceId != null) {
      try {
        regionId = await _cache.regionOfProvince(account.provinceId!);
      } catch (_) {
        regionId = null;
      }
    }
    if (!mounted) return;

    _controller?.dispose();
    final controller = FormController(
      roleIsSaha: !account.isAdmin,
      fields: profileFieldSpecs(
        regions: (_) => regionOptions(_cache),
        provinces: (values) => provinceOptions(_cache, values),
        districts: (values) => districtOptions(_cache, values),
      ),
      initialValues: {
        ProfileFields.name: account.name,
        ProfileFields.email: account.email,
        ProfileFields.phone: account.phone,
        ProfileFields.roleLabel: account.roleLabel,
        ProfileFields.regionId: regionId,
        ProfileFields.provinceId: account.provinceId,
        ProfileFields.districtId: account.districtId,
      },
    );

    setState(() {
      _account = account;
      _avatar = account.avatar;
      _avatarPreview = null;
      _controller = controller;
      _loading = false;
    });
  }

  /// `GET /auth/me`; uç ulaşılamazsa oturumdaki kullanıcıya düşer, o da yoksa
  /// hata durumu gösterilir.
  Future<UserAccount?> _fetchAccount(Session session) async {
    try {
      return await context.api2.me();
    } catch (e) {
      final u = session.user;
      if (u == null) {
        _error = e;
        return null;
      }
      return UserAccount(
        id: u.id,
        name: u.name,
        email: u.email,
        role: u.role,
        isActive: true,
        phone: u.phone,
        regionId: u.regionId,
        provinceId: u.provinceId,
        districtId: u.districtId,
        mustChangePassword: u.mustChangePassword,
      );
    }
  }

  // ---- Kaydetme -----------------------------------------------------------

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null) return;
    final firstError = controller.validateAll();
    if (firstError != null) {
      _formKey.currentState?.scrollToField(firstError);
      return;
    }
    final local = profileLocalErrors(controller);
    if (local.isNotEmpty) {
      local.forEach(controller.setServerError);
      _formKey.currentState?.scrollToField(local.keys.first);
      return;
    }

    setState(() => _saving = true);
    controller.setSaving(true);
    try {
      final updated = await context.api2.updateMe(profileUpdateBody(controller));
      if (!mounted) return;
      _applyToSession(updated);
      setState(() {
        _account = updated;
        _avatar = updated.avatar ?? _avatar;
        _saving = false;
      });
      controller.setSaving(false);
      controller.markPristine();
      showAppSnackBar(context, S2.profilKaydedildi);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _selfEditUnavailable = e.isNotFound;
      });
      controller.setSaving(false);
      if (e.isConflict) {
        controller.setServerError(ProfileFields.email, S2.epostaCakisma);
        _formKey.currentState?.scrollToField(ProfileFields.email);
        return;
      }
      showAppSnackBar(
          context, e.isNotFound ? S2.profilUcYok : v2ErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      controller.setSaving(false);
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  /// Oturumdaki kullanıcı tazelenir: iskeletteki ad, kapsam ve doküman
  /// süzgeçleri hemen yeni değeri görür.
  void _applyToSession(UserAccount account) {
    final session = context.read<Session>();
    final current = session.user;
    session.applyUser(AppUser(
      id: account.id,
      name: account.name,
      email: account.email,
      role: account.role,
      phone: account.phone,
      regionId: account.regionId,
      provinceId: account.provinceId,
      districtId: account.districtId,
      mustChangePassword:
          current?.mustChangePassword ?? account.mustChangePassword,
    ));
  }

  // ---- Profil fotoğrafı ---------------------------------------------------

  Future<void> _pickAvatar() async {
    final files = await pickFiles(accept: Avatar.accept, multiple: false);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final error = avatarPickError(file);
    if (error != null) {
      setState(() => _avatarError = error);
      return;
    }
    setState(() {
      _avatarPreview = file.bytes;
      _avatarBusy = true;
      _avatarError = null;
    });
    final api = context.api2;
    try {
      final uploaded = await api.uploadMyAvatar(
        fileName: file.name,
        bytes: file.bytes,
        mime: file.mime,
      );
      api.clearAvatarCache();
      if (!mounted) return;
      setState(() {
        _avatar = uploaded ?? _avatar;
        _avatarBusy = false;
      });
      showAppSnackBar(context, S2.avatarYuklendi);
      // Uç `avatar` döndürmediyse kaydı tazeleyip adresi oradan alırız.
      if (uploaded == null) await _refreshAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
        _avatarPreview = null;
        _avatarError = avatarErrorMessage(e);
      });
    }
  }

  Future<void> _removeAvatar() async {
    final ok = await showConfirmDialog(
      context,
      title: S2.avatarKaldirBaslik,
      body: S2.avatarKaldirGovde,
      confirmText: Str.sil,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _avatarBusy = true;
      _avatarError = null;
    });
    final api = context.api2;
    try {
      await api.deleteMyAvatar();
      api.clearAvatarCache();
      if (!mounted) return;
      setState(() {
        _avatar = null;
        _avatarPreview = null;
        _avatarBusy = false;
      });
      showAppSnackBar(context, S2.avatarSilindi);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _avatarBusy = false;
        _avatarError = avatarErrorMessage(e);
      });
    }
  }

  /// Formu bozmadan yalnız hesabı (ve fotoğrafı) tazeler.
  Future<void> _refreshAccount() async {
    try {
      final account = await context.api2.me();
      if (!mounted) return;
      setState(() {
        _account = account;
        _avatar = account.avatar;
        _avatarPreview = null;
      });
    } catch (_) {
      // tazeleme başarısızsa ekrandaki değerler korunur
    }
  }

  // ---- Diğer eylemler -----------------------------------------------------

  Future<void> _openPasswordForm() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PasswordChangeScreen(),
    ));
  }

  Future<void> _logout() async {
    final session = context.read<Session>();
    final refData = context.read<RefData>();
    final api = context.api2;
    final ok = await showConfirmDialog(
      context,
      title: 'Çıkış yap',
      body: 'Oturumunuz kapatılacak. Devam edilsin mi?',
      confirmText: Str.cikisYap,
    );
    if (!ok) return;
    refData.clear();
    api.clearAvatarCache();
    await session.logout();
  }

  Future<bool> _confirmExit() async {
    if (!(_controller?.isDirty ?? false)) return true;
    return showConfirmDialog(
      context,
      title: S2.kirliBaslik,
      body: S2.kirliGovde,
      confirmText: S2.cik,
    );
  }

  // ---- Çizim --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) {
          if (!context.mounted) return;
          final nav = Navigator.of(context);
          if (nav.canPop()) nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text(S2.modulProfil)),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final account = _account;
    final controller = _controller;
    if (account == null || controller == null) {
      return ErrorState(
        onRetry: _load,
        message: _error == null
            ? S2.profilYuklenemedi
            : v2ErrorMessage(_error!, fallback: S2.profilYuklenemedi),
      );
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(account),
                  DynamicForm(key: _formKey, controller: controller),
                  const NoticeCard(text: S2.profilTeskilatNotu),
                  if (_selfEditUnavailable)
                    const NoticeCard(
                      text: S2.profilUcYok,
                      icon: Icons.cloud_off_outlined,
                    ),
                  const SizedBox(height: s8),
                  _actions(),
                ],
              ),
            ),
          ),
        ),
        FormActionBar(onSave: _save, saving: _saving),
      ],
    );
  }

  Widget _header(UserAccount account) {
    final theme = Theme.of(context);
    final scope = account.scopeLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(s16, s16, s16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(s24),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  UserAvatar(
                    name: account.name,
                    avatar: _avatar,
                    bytes: _avatarPreview,
                    loader: context.api2.avatarBytes,
                    radius: 40,
                  ),
                  if (_avatarBusy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Material(
                      color: kPrimary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickAvatar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.photo_camera_outlined,
                              size: 16, color: kOnPrimary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: s12),
              Text(account.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: s4),
              Text(account.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kTextSecondary)),
              const SizedBox(height: s12),
              StatusBadge(
                label: account.roleLabel,
                foreground: account.isAdmin ? kPrimary : kInactive,
                background:
                    account.isAdmin ? kPrimaryContainer : kInactiveContainer,
              ),
              const SizedBox(height: s8),
              Text(
                scope.isEmpty ? S2.profilKapsamYok : S2.profilKapsam(scope),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              if (_avatarBusy) ...[
                const SizedBox(height: s8),
                Text(S2.avatarYukleniyor,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary)),
              ],
              if (_avatarError != null) ...[
                const SizedBox(height: s8),
                Text(_avatarError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: kError)),
              ],
              const SizedBox(height: s8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: s8,
                children: [
                  TextButton.icon(
                    onPressed: _avatarBusy ? null : _pickAvatar,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(
                        _avatar == null ? S2.avatarSec : S2.avatarDegistir),
                  ),
                  if (_avatar != null || _avatarPreview != null)
                    TextButton.icon(
                      onPressed: _avatarBusy ? null : _removeAvatar,
                      style: TextButton.styleFrom(foregroundColor: kError),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text(S2.avatarKaldir),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(s16, 0, s16, s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: kPrimary),
              title: const Text(S2.sifreDegistir),
              subtitle: const Text(S2.sifreKurali),
              trailing: const Icon(Icons.chevron_right, color: kTextSecondary),
              onTap: _openPasswordForm,
            ),
          ),
          const SizedBox(height: s16),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: kError,
              side: const BorderSide(color: kError),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(Str.cikisYap),
          ),
          const SizedBox(height: s16),
          Text(
            'Sürüm ${AppConfig.appVersion}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}
