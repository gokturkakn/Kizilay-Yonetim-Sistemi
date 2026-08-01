import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/strings.dart';
import '../models/models.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Kişi kartı — UX §4.1: tüm kişi listelerinde tek desen.
class PersonListTile extends StatelessWidget {
  const PersonListTile({
    super.key,
    required this.person,
    required this.locationLabel,
    this.onTap,
    this.trailing,
    this.subtitleExtra,
    this.disabled = false,
    this.showRepresentationBadge = false,
    this.activeOverride,
  });

  final Person person;
  final String locationLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Ad altına eklenecek ek satır (ör. üye görev unvanı).
  final String? subtitleExtra;

  /// Zaten üye olanlar için soluk gösterim (Üye Ekle ekranı).
  final bool disabled;

  /// İl detayında `temsilcilik` için konum yerine rozet — UX §3.7.
  final bool showRepresentationBadge;

  /// Rozet için kişi durumu yerine kullanılacak durum (ör. üyelik durumu).
  final bool? activeOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = activeOverride ?? person.isActive;
    final nameColor = disabled
        ? kTextDisabled
        : (isActive ? kTextPrimary : kTextSecondary);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(r12),
        onTap: disabled ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding:
              const EdgeInsets.symmetric(horizontal: s16, vertical: s12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kInactiveContainer,
                child: Text(
                  Formats.initials(person.firstName, person.lastName),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: nameColor),
                    ),
                    const SizedBox(height: 2),
                    if (showRepresentationBadge &&
                        person.unitType == 'temsilcilik')
                      const StatusBadge(
                        label: Str.birimTemsilcilik,
                        foreground: kInfo,
                        background: kInfoContainer,
                      )
                    else
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: kTextSecondary),
                      ),
                    if (subtitleExtra != null && subtitleExtra!.isNotEmpty)
                      Text(
                        subtitleExtra!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kTextSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: s8),
              if (disabled)
                Text(
                  'Üye',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kTextDisabled),
                )
              else
                StatusBadge.activity(isActive),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
