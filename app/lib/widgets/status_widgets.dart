import 'package:flutter/material.dart';

import '../core/status.dart';
import '../core/strings.dart';
import '../theme/tokens.dart';

/// Üç durumlu statü rozeti — docs/UX-V2.md §3.1.
///
/// **Zorunlu kural (§1.4):** durum hiçbir yerde yalnız renkle anlatılmaz —
/// her zaman ikon + metin birlikte gösterilir.
class OrgStatusBadge extends StatelessWidget {
  const OrgStatusBadge({super.key, required this.status});

  OrgStatusBadge.fromApi(String? value, {super.key})
      : status = orgStatusFromApi(value);

  final OrgStatus status;

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: status.label,
      icon: status.icon,
      foreground: status.foreground,
      background: status.background,
    );
  }
}

/// Malzeme talebi durum rozeti — §6.3 E-51.
class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => _Badge(
        label: RequestStatus.label(status),
        foreground: RequestStatus.foreground(status),
        background: RequestStatus.background(status),
      );
}

/// Gönderi durum rozeti — `received_date`ten **türetilir** (§10/24).
class ShipmentStatusBadge extends StatelessWidget {
  const ShipmentStatusBadge({super.key, required this.receivedDate});

  final String? receivedDate;

  @override
  Widget build(BuildContext context) => _Badge(
        label: ShipmentStatus.label(receivedDate),
        icon: ShipmentStatus.isDelivered(receivedDate)
            ? Icons.check_circle_outline
            : Icons.local_shipping_outlined,
        foreground: ShipmentStatus.foreground(receivedDate),
        background: ShipmentStatus.background(receivedDate),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Biçim v1 §4.1 ile aynı: bodySmall w600, 8/4 padding, rFull.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: s8, vertical: s4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(rFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: s4),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Üç durumlu filtre çipleri — §3.3c.
///
/// Sıra sabit: `Tümü` · `Aktif` · `Pasif` · `Teşkilat Yok`.
/// Çipler **daima** yatay kaydırmalı satırda (§1.5).
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({
    super.key,
    required this.filter,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: s16),
  });

  final StatusFilter filter;
  final ValueChanged<OrgStatus?> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final s in filter.chips) ...[
            ChoiceChip(
              label: Text(StatusFilter.chipLabel(s)),
              selected: filter.value == s,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight:
                    filter.value == s ? FontWeight.w600 : FontWeight.w400,
                color: filter.value == s ? kPrimary : kTextPrimary,
              ),
              onSelected: (_) => onChanged(s),
            ),
            const SizedBox(width: s8),
          ],
        ],
      ),
    );
  }
}

/// Genel amaçlı yatay kaydırmalı çip satırı (talep durumları vb.).
class LabelFilterChips extends StatelessWidget {
  const LabelFilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: s16),
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            ChoiceChip(
              label: Text(labels[i]),
              selected: selectedIndex == i,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight:
                    selectedIndex == i ? FontWeight.w600 : FontWeight.w400,
                color: selectedIndex == i ? kPrimary : kTextPrimary,
              ),
              onSelected: (_) => onChanged(i),
            ),
            const SizedBox(width: s8),
          ],
        ],
      ),
    );
  }
}

/// Durum özet şeridi: `Aktif {n}` · `Pasif {n}` · `Teşkilat Yok {n}`
/// (ikonlu, durum renkleriyle) — E-20, E-24.
class StatusSummaryStrip extends StatelessWidget {
  const StatusSummaryStrip({
    super.key,
    required this.aktif,
    required this.pasif,
    required this.teskilatYok,
    this.loading = false,
  });

  final int aktif;
  final int pasif;
  final int teskilatYok;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(OrgStatus s, int n) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 16, color: s.foreground),
            const SizedBox(width: s4),
            Text('${s.label} ${loading ? Str.bos : n}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: kTextSecondary)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: s16, vertical: s8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            item(OrgStatus.aktif, aktif),
            const SizedBox(width: s16),
            item(OrgStatus.pasif, pasif),
            const SizedBox(width: s16),
            item(OrgStatus.teskilatYok, teskilatYok),
          ],
        ),
      ),
    );
  }
}
