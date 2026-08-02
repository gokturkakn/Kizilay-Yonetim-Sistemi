import 'package:flutter/material.dart';

import '../../../core/strings_v2.dart';
import '../../../widgets/info_block.dart';
import '../shared.dart';
import 'authorization_screen.dart';
import 'content_block_list_screen.dart';
import 'form_settings_screen.dart';
import 'lookup_category_list_screen.dart';
import 'notification_settings_screen.dart';
import 'system_settings_screen.dart';
import 'user_list_screen.dart';

/// E-60 · Yönetim Paneli Ana Ekranı — docs/UX-V2.md §6.5.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S2.modulYonetim)),
      body: ListView(
        children: [
          InfoBlockHeader(blockKey: 'yonetim.genel', api: context.api2),
          const SizedBox(height: s8_),
          NavRow(
            icon: Icons.manage_accounts_outlined,
            title: 'Kullanıcı Yönetimi',
            subtitle: 'Sistem kullanıcıları ve şifreleri',
            onTap: () => _open(context, const UserListScreen()),
          ),
          NavRow(
            icon: Icons.list_alt_outlined,
            title: 'Tanımlar',
            subtitle: 'Açılır liste ve kod tanımları',
            onTap: () => _open(context, const LookupCategoryListScreen()),
          ),
          NavRow(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Yetkilendirme',
            subtitle: 'Rol ve kapsam ayarları',
            onTap: () => _open(context, const AuthorizationScreen()),
          ),
          NavRow(
            icon: Icons.notifications_outlined,
            title: 'Bildirimler',
            subtitle: 'Bildirim tanımları ve gönderim',
            onTap: () => _open(context, const NotificationSettingsScreen()),
          ),
          NavRow(
            icon: Icons.tune_outlined,
            title: 'Sistem Ayarları',
            subtitle: 'Genel sistem parametreleri',
            onTap: () => _open(context, const SystemSettingsScreen()),
          ),
          NavRow(
            icon: Icons.dynamic_form_outlined,
            title: 'Form Yönetimi',
            subtitle: 'Form alanlarının görünürlüğü',
            onTap: () => _open(context, const FormSettingsScreen()),
          ),
          NavRow(
            icon: Icons.article_outlined,
            title: 'İçerik Yönetimi',
            subtitle: 'Modül bilgilendirme metinleri',
            onTap: () => _open(context, const ContentBlockListScreen()),
          ),
        ],
      ),
    );
  }
}

const double s8_ = 8;
