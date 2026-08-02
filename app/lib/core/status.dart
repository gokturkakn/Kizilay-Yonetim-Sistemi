import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'strings_v2.dart';

/// Üç durumlu statü — docs/UX-V2.md §3, API-V2 §1.1.
///
/// `teskilat_yok` **yalnız** `org_units` kayıtlarına aittir; kişi ve kullanıcı
/// yalnız `aktif`/`pasif` alır (§3.3b, §10/9).
enum OrgStatus { aktif, pasif, teskilatYok }

extension OrgStatusX on OrgStatus {
  /// API değeri.
  String get apiValue {
    switch (this) {
      case OrgStatus.aktif:
        return 'aktif';
      case OrgStatus.pasif:
        return 'pasif';
      case OrgStatus.teskilatYok:
        return 'teskilat_yok';
    }
  }

  /// Rozet metni — §3.1. Kısaltma yasaktır.
  String get label {
    switch (this) {
      case OrgStatus.aktif:
        return S2.aktif;
      case OrgStatus.pasif:
        return S2.pasif;
      case OrgStatus.teskilatYok:
        return S2.teskilatYok;
    }
  }

  Color get foreground {
    switch (this) {
      case OrgStatus.aktif:
        return kSuccess;
      case OrgStatus.pasif:
        return kInactive;
      case OrgStatus.teskilatYok:
        return kWarning;
    }
  }

  Color get background {
    switch (this) {
      case OrgStatus.aktif:
        return kSuccessContainer;
      case OrgStatus.pasif:
        return kInactiveContainer;
      case OrgStatus.teskilatYok:
        return kWarningContainer;
    }
  }

  /// §1.4 — durum hiçbir yerde yalnız renkle anlatılmaz; ikon zorunludur.
  IconData get icon {
    switch (this) {
      case OrgStatus.aktif:
        return Icons.check_circle_outline;
      case OrgStatus.pasif:
        return Icons.pause_circle_outline;
      case OrgStatus.teskilatYok:
        return Icons.location_off_outlined;
    }
  }

  /// Kişi kayıtlarına uygulanabilir mi (§3.3b).
  bool get allowedForPerson => this != OrgStatus.teskilatYok;
}

/// API değerinden durum; bilinmeyen değer `pasif` sayılır (sessiz düşüş).
OrgStatus orgStatusFromApi(String? value) {
  switch (value) {
    case 'aktif':
      return OrgStatus.aktif;
    case 'teskilat_yok':
      return OrgStatus.teskilatYok;
    case 'pasif':
    default:
      return OrgStatus.pasif;
  }
}

/// Üç durumlu filtre — `null` = `Tümü` (§3.3c).
///
/// [includeTeskilatYok] false ise (kişi listeleri) `Teşkilat Yok` çipi hiç
/// render edilmez.
class StatusFilter {
  const StatusFilter({this.value, this.includeTeskilatYok = true});

  final OrgStatus? value;
  final bool includeTeskilatYok;

  /// Çip sırası sabittir: `Tümü` · `Aktif` · `Pasif` · `Teşkilat Yok`.
  List<OrgStatus?> get chips => [
        null,
        OrgStatus.aktif,
        OrgStatus.pasif,
        if (includeTeskilatYok) OrgStatus.teskilatYok,
      ];

  static String chipLabel(OrgStatus? s) => s?.label ?? 'Tümü';

  /// Varsayılan: birim listelerinde `Tümü`, kişi listelerinde `Aktif`.
  static StatusFilter forOrgUnits() => const StatusFilter();
  static StatusFilter forPersons() =>
      const StatusFilter(value: OrgStatus.aktif, includeTeskilatYok: false);

  StatusFilter select(OrgStatus? s) {
    if (s == OrgStatus.teskilatYok && !includeTeskilatYok) return this;
    return StatusFilter(value: s, includeTeskilatYok: includeTeskilatYok);
  }

  /// Sorgu parametresi (`null` ise gönderilmez).
  String? get queryValue => value?.apiValue;

  /// İstemci tarafı süzme.
  bool matches(String? apiStatus) {
    if (value == null) return true;
    return orgStatusFromApi(apiStatus) == value;
  }

  Iterable<T> apply<T>(Iterable<T> items, String? Function(T) statusOf) =>
      items.where((e) => matches(statusOf(e)));
}

/// Malzeme talebi durumu — §6.3 E-51 tablosu (API-V2 §7.1 ile birebir).
class RequestStatus {
  const RequestStatus._();

  static const values = [
    'talep',
    'onaylandi',
    'gonderildi',
    'teslim_edildi',
    'iptal',
  ];

  static String label(String? status) {
    switch (status) {
      case 'talep':
        return S2.talepTalep;
      case 'onaylandi':
        return S2.talepOnaylandi;
      case 'gonderildi':
        return S2.talepGonderildi;
      case 'teslim_edildi':
        return S2.talepTeslimEdildi;
      case 'iptal':
        return S2.talepIptal;
      default:
        return status ?? '—';
    }
  }

  static Color foreground(String? status) {
    switch (status) {
      case 'talep':
        return kWarning;
      case 'onaylandi':
        return kInfo;
      case 'gonderildi':
        return kPrimary;
      case 'teslim_edildi':
        return kSuccess;
      case 'iptal':
      default:
        return kInactive;
    }
  }

  static Color background(String? status) {
    switch (status) {
      case 'talep':
        return kWarningContainer;
      case 'onaylandi':
        return kInfoContainer;
      case 'gonderildi':
        return kPrimaryContainer;
      case 'teslim_edildi':
        return kSuccessContainer;
      case 'iptal':
      default:
        return kInactiveContainer;
    }
  }

  /// Açık talep = gönderi oluşturulabilir olan (§5.4 Bölüm 5).
  static bool isOpen(String? status) =>
      status == 'talep' || status == 'onaylandi';
}

/// Gönderi durumu **türetilir** — API'de sütun yoktur (§10/24).
/// `received_date` boşsa `Yolda`, doluysa `Teslim Edildi`.
class ShipmentStatus {
  const ShipmentStatus._();

  static bool isDelivered(String? receivedDate) =>
      receivedDate != null && receivedDate.isNotEmpty;

  static String label(String? receivedDate) =>
      isDelivered(receivedDate) ? S2.gonderiTeslimEdildi : S2.gonderiYolda;

  static Color foreground(String? receivedDate) =>
      isDelivered(receivedDate) ? kSuccess : kInfo;

  static Color background(String? receivedDate) =>
      isDelivered(receivedDate) ? kSuccessContainer : kInfoContainer;
}
