import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/api_v2.dart';
import '../../../core/formatters.dart';
import '../../../core/layout.dart';
import '../../../core/strings.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';
import 'user_form_screen.dart';

/// E-61 · Kullanıcı Yönetimi — docs/UX-V2.md §6.5 (denetim Y-2'nin çözümü).
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _loading = true;
  Object? _error;
  List<UserAccount> _items = const [];
  String _query = '';
  int _roleChip = 0; // 0 Tümü · 1 Genel Merkez · 2 Saha
  int _statusChip = 0; // 0 Tümü · 1 Aktif · 2 Pasif

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.api2.users();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<UserAccount> get _visible => _items.where((u) {
        if (_roleChip == 1 && !u.isAdmin) return false;
        if (_roleChip == 2 && u.isAdmin) return false;
        if (_statusChip == 1 && !u.isActive) return false;
        if (_statusChip == 2 && u.isActive) return false;
        if (_query.trim().isEmpty) return true;
        return Formats.trContains(u.name, _query) ||
            Formats.trContains(u.email, _query);
      }).toList();

  Future<void> _openForm([UserAccount? user]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => UserFormScreen(existing: user),
    ));
    if (saved == true) _load();
  }

  Future<void> _setPassword(UserAccount user) async {
    final pass1 = TextEditingController();
    final pass2 = TextEditingController();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(S2.dlgSifreBelirle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S2.dlgSifreBelirleGovde(user.name)),
              const SizedBox(height: s12),
              TextField(
                controller: pass1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Yeni Şifre'),
              ),
              const SizedBox(height: s8),
              TextField(
                controller: pass2,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Yeni Şifre (Tekrar)'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: s8),
                  child: Text(error!, style: const TextStyle(color: kError)),
                ),
              const SizedBox(height: s8),
              const Text(S2.sifreGuvenliKanal,
                  style: TextStyle(fontSize: 12, color: kTextSecondary)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(Str.vazgec)),
            TextButton(
              onPressed: () {
                if (pass1.text.length < 8) {
                  setLocal(() => error = S2.vSifreKisa);
                  return;
                }
                if (pass1.text != pass2.text) {
                  setLocal(() => error = S2.vSifreEslesmiyor);
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text(Str.kaydet),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (!mounted) return;
    try {
      await context.api2.setUserPassword(user.id, pass1.text);
      if (!mounted) return;
      showAppSnackBar(context, S2.basariSifreBelirle);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    } finally {
      pass1.dispose();
      pass2.dispose();
    }
  }

  Future<void> _toggleActive(UserAccount user) async {
    try {
      await context.api2.setUserActive(user.id, !user.isActive);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 LAST_ADMIN — son genel merkez hesabı pasif yapılamaz.
      if (e.code == 'LAST_ADMIN' || e.isConflict) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(S2.dlgSonYonetici),
            content: const Text(S2.dlgSonYoneticiGovde),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(Str.tamam)),
            ],
          ),
        );
        return;
      }
      if (!context.mounted) return;
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Yönetimi')),
      body: Column(
        children: [
          SearchField(
            hint: 'Kullanıcı ara...',
            onChanged: (v) => setState(() => _query = v),
          ),
          _chipRow(const ['Tümü', 'Genel Merkez', 'Saha'], _roleChip,
              (i) => setState(() => _roleChip = i)),
          const SizedBox(height: s8),
          _chipRow(const ['Tümü', 'Aktif', 'Pasif'], _statusChip,
              (i) => setState(() => _statusChip = i)),
          const SizedBox(height: s8),
          Expanded(
            child: AsyncListBody<UserAccount>(
              loading: _loading,
              error: _error,
              items: _visible,
              onRetry: _load,
              emptyIcon: Icons.manage_accounts_outlined,
              emptyMessage: _query.trim().isEmpty
                  ? S2.bosKullanici
                  : S2.bosKullaniciArama,
              itemBuilder: (context, u) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrimaryContainer,
                    child: Text(
                      u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                      style: const TextStyle(color: kPrimary),
                    ),
                  ),
                  title: Text(u.name, style: theme.textTheme.titleMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.email),
                      if (u.regionName != null || u.provinceName != null)
                        Text(
                          'Kapsam: ${[
                            u.regionName,
                            u.provinceName
                          ].whereType<String>().join(' / ')}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kTextSecondary),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(u.roleLabel),
                        backgroundColor: kPrimaryContainer,
                        labelStyle:
                            const TextStyle(fontSize: 11, color: kPrimary),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: s4),
                      Chip(
                        label: Text(u.isActive ? S2.aktif : S2.pasif),
                        backgroundColor: u.isActive
                            ? kSuccessContainer
                            : kInactiveContainer,
                        labelStyle: TextStyle(
                            fontSize: 11,
                            color: u.isActive ? kSuccess : kInactive),
                        visualDensity: VisualDensity.compact,
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: kTextSecondary),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text(S2.duzenle)),
                          const PopupMenuItem(
                              value: 'password', child: Text('Şifre Belirle')),
                          PopupMenuItem(
                            value: 'toggle',
                            child:
                                Text(u.isActive ? 'Pasif Yap' : 'Aktif Yap'),
                          ),
                        ],
                        onSelected: (v) {
                          switch (v) {
                            case 'edit':
                              _openForm(u);
                            case 'password':
                              _setPassword(u);
                            case 'toggle':
                              _toggleActive(u);
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () => _openForm(u),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: layoutOf(context).usesBottomBar
          ? FloatingActionButton(
              tooltip: 'Yeni Kullanıcı',
              onPressed: _openForm,
              child: const Icon(Icons.add))
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Kullanıcı')),
    );
  }

  Widget _chipRow(List<String> labels, int selected, ValueChanged<int> onTap) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: s16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              onSelected: (_) => onTap(i),
            ),
            const SizedBox(width: s8),
          ],
        ],
      ),
    );
  }
}
