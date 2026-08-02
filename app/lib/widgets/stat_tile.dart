import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/layout.dart';
import '../theme/tokens.dart';

/// KPI kutucuğu — docs/UX-V2.md §5.2 `StatTile` sözleşmesi.
///
/// Üstte etiket `bodySmall`/`kTextSecondary`, ortada büyük sayı
/// `headlineSmall` w600 (orantılı rakam), altında alt yazı `bodySmall`.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
    this.icon,
    this.onTap,
    this.deltaPercent,
    this.warningNote,
  });

  final String label;
  final num? value;
  final String? subtitle;
  final Color? accentColor;
  final IconData? icon;
  final VoidCallback? onTap;

  /// İsteğe bağlı değişim satırı: `▲ %12` / `▼ %4` (§5.4).
  /// Artış `kSuccess`, azalış `kInactive` — **kırmızı değil**.
  final int? deltaPercent;

  final String? warningNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r12),
        child: Container(
          decoration: accent == null
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: accent, width: 3)),
                  borderRadius: BorderRadius.circular(r12),
                ),
          padding: const EdgeInsets.all(s12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: accent ?? kTextSecondary),
                        const SizedBox(width: s4),
                      ],
                      Flexible(
                        child: Text(label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kTextSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Text(
                    value == null ? '—' : Formats.number(value),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (deltaPercent != null)
                    Row(
                      children: [
                        Icon(
                          deltaPercent! >= 0
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          size: 16,
                          color: deltaPercent! >= 0 ? kSuccess : kInactive,
                        ),
                        Text('%${deltaPercent!.abs()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: deltaPercent! >= 0
                                    ? kSuccess
                                    : kInactive)),
                      ],
                    )
                  else if (warningNote != null)
                    Text(warningNote!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWarning))
                  else if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kTextSecondary)),
                ],
              ),
              if (onTap != null)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.chevron_right,
                      size: 16, color: kTextSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// KPI ızgarası — §5.1 sütun/yükseklik tablosu.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final layout = layoutOf(context);
    return GridView.count(
      crossAxisCount: layout.kpiColumns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: s12,
      mainAxisSpacing: s12,
      childAspectRatio: _aspect(context, layout),
      children: tiles,
    );
  }

  double _aspect(BuildContext context, LayoutClass layout) {
    final width = MediaQuery.sizeOf(context).width - s16 * 2;
    final columns = layout.kpiColumns;
    final tileWidth =
        (width - s12 * (columns - 1)) / columns;
    return tileWidth / layout.kpiTileHeight;
  }
}

/// Bölüm başlığı — `titleSmall`, üstünde `s24` boşluk (§5.1).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: s24, bottom: s8),
      child: Row(
        children: [
          Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          ?trailing,
        ],
      ),
    );
  }
}
