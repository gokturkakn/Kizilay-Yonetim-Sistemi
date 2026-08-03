import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/strings_v2.dart';
import '../models/models_v2.dart';
import '../theme/tokens.dart';

/// Bir profil fotoğrafını baytlarıyla getiren yükleyici.
///
/// Ekranlar `(url) => api.avatarBytes(url)` geçer; önbellek `ApiV2`
/// tarafındadır, bu yüzden aynı fotoğraf listede bir kez indirilir.
typedef AvatarLoader = Future<Uint8List?> Function(String url);

/// Profil fotoğrafı dairesi — fotoğraf varsa görsel, yoksa baş harfler.
///
/// docs/UX-V2.md §6.6 (E-80): "Avatar yerine kullanıcının fotoğrafı (varsa);
/// yoksa v1'deki baş harf dairesi." Aynı bileşen Kullanıcı Yönetimi
/// satırlarında ve kullanıcı formu başlığında da kullanılır.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.loader,
    this.bytes,
    this.radius = 20,
  });

  final String name;
  final Avatar? avatar;
  final AvatarLoader? loader;

  /// Yükleme öncesi yerel önizleme (seçilen dosya) — verilirse [avatar] yerine
  /// bu gösterilir.
  final Uint8List? bytes;

  final double radius;

  /// `Ayşe Nur Yılmaz` → `AY` · boş ad → `?` (v1 davranışı korunur).
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((w) => w.characters.first).take(2).join().toUpperCase();
  }

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<Uint8List?>? _future;
  String? _requestedUrl;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant UserAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Adres değişmedikçe `Future` yeniden kurulmaz (her build'de yeni istek
  /// açan `FutureBuilder` tuzağı).
  void _sync() {
    final url = widget.avatar?.url;
    final loader = widget.loader;
    if (url == null || loader == null) {
      _requestedUrl = null;
      _future = null;
      return;
    }
    if (url == _requestedUrl) return;
    _requestedUrl = url;
    _future = loader(url);
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.bytes;
    if (local != null && local.isNotEmpty) return _circle(image: local);
    final future = _future;
    if (future == null) return _circle();
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        // Yüklenirken de baş harfler durur: listede daire boş yanıp sönmez.
        if (data == null || data.isEmpty) return _circle();
        return _circle(image: data);
      },
    );
  }

  Widget _circle({Uint8List? image}) {
    final initials = UserAvatar.initialsOf(widget.name);
    return Semantics(
      image: image != null,
      label: image != null
          ? '${S2.avatarBaslik}: ${widget.name}'
          : '${S2.avatarYok} ${widget.name}',
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: kPrimaryContainer,
        foregroundImage: image == null ? null : MemoryImage(image),
        child: image != null
            ? null
            : Text(
                initials,
                style: TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: widget.radius * 0.7,
                ),
              ),
      ),
    );
  }
}
