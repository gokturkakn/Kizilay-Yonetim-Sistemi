import 'package:flutter/material.dart';

// Renk paleti (docs/UX.md §1.1)
const Color kPrimary = Color(0xFFE30613);
const Color kPrimaryDark = Color(0xFFB10510);
const Color kPrimaryContainer = Color(0xFFFDE7E9);
const Color kOnPrimary = Color(0xFFFFFFFF);
const Color kSurface = Color(0xFFFFFFFF);
const Color kBackground = Color(0xFFF7F7F8);
const Color kBorder = Color(0xFFE2E4E8);
const Color kTextPrimary = Color(0xFF1A1C1E);
const Color kTextSecondary = Color(0xFF5F6368);
const Color kTextDisabled = Color(0xFF9AA0A6);
const Color kSuccess = Color(0xFF1E8E3E);
const Color kSuccessContainer = Color(0xFFE6F4EA);
const Color kWarning = Color(0xFFB26A00);
const Color kWarningContainer = Color(0xFFFDF3E0);
const Color kError = Color(0xFFC5221F);
const Color kErrorContainer = Color(0xFFFCE8E6);
const Color kInactive = Color(0xFF5F6368);
const Color kInactiveContainer = Color(0xFFEEF0F2);
const Color kInfo = Color(0xFF1A73E8);
const Color kInfoContainer = Color(0xFFE8F0FE);

// Boşluk ölçeği (4 pt tabanı) — §1.3
const double s4 = 4;
const double s8 = 8;
const double s12 = 12;
const double s16 = 16;
const double s24 = 24;
const double s32 = 32;

// Köşe yarıçapları — §1.4
const double r8 = 8;
const double r12 = 12;
const double rFull = 999;

// ---------------------------------------------------------------------------
// v2 eklemeleri — docs/UX-V2.md §1. v1 sabitlerinin hiçbiri değiştirilmedi.
// ---------------------------------------------------------------------------

// Kırılma noktaları — §1.1
const double kBpMedium = 600; // mobil → tablet
const double kBpLarge = 840; // iki panelli düzenin açıldığı eşik
const double kBpExpanded = 1240; // tablet → masaüstü (genişletilmiş yan panel)

// Yeni boşluk / ölçü sabitleri — §1.2
const double s48 = 48;
const double kRailWidth = 80;
const double kSidebarWidth = 256;
const double kContentMaxWidth = 1200;
const double kListPaneWidth = 360;
const double kChartMinHeight = 220;
const double kThumbSize = 72;

// Grafik kategorik paleti — §1.3 (doğrulanmış sıra, değiştirilmez)
const Color kChart1 = Color(0xFF2A78D6); // mavi — birincil seri
const Color kChart2 = Color(0xFFEB6834); // turuncu
const Color kChart3 = Color(0xFF1BAF7A); // deniz yeşili
const Color kChart4 = Color(0xFFEDA100); // sarı
const Color kChart5 = Color(0xFFE87BA4); // magenta
const Color kChart6 = Color(0xFF008300); // yeşil
const Color kChart7 = Color(0xFF4A3AA7); // mor
const Color kChartOther = Color(0xFF9AA0A6); // "Diğer" ve vurgusuz seriler

// Grafik kroması
const Color kGridLine = Color(0xFFE2E4E8); // 1 px, DÜZ çizgi
const Color kAxisLine = Color(0xFFC9CCD1);

/// Kategorik seri renkleri, sabit sırayla. 8. seriden sonrası [kChartOther].
const List<Color> kChartSeries = [
  kChart1,
  kChart2,
  kChart3,
  kChart4,
  kChart5,
  kChart6,
  kChart7,
];
