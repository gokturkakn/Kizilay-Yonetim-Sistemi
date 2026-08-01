import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/ref_data.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/person_list_tile.dart';
import 'add_member_screen.dart';

/// Kurul / Komisyon Üye Listesi — UX §3.4.
class BodyMembersScreen extends StatefulWidget {
  const BodyMembersScreen(
      {super.key, required this.bodyId, required this.title});

  final int bodyId;
  final String title;

  @override
  State<BodyMembersScreen> createState() => _BodyMembersScreenState();
}

class _BodyMembersScreenState extends State<BodyMembersScreen> {
  bool? _isActive = true; // varsayılan Aktif

  Future<List<Membership>> _load() async {
    final api = context.read<Api>();
    final refData = context.read<RefData>();
    final members =
        await api.bodyMembers(widget.bodyId, isActive: _isActive);
    await refData.primeForPersons(members.map((m) => m.person));
    return members;
  }

  Future<void> _toggleActive(
      Membership m, Future<void> Function() reload) async {
    final api = context.read<Api>();
    try {
      await api.setMembershipActive(m.membershipId, !m.isActive);
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  Future<void> _removeMember(
      Membership m, Future<void> Function() reload) async {
    final api = context.read<Api>();
    final ok = await showConfirmDialog(
      context,
      title: 'Üyelikten çıkar',
      body: 'Bu kişi listeden kaldırılacak. Devam edilsin mi?',
      confirmText: Str.cikar,
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.deleteMembership(m.membershipId);
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, errorMessage(e));
    }
  }

  Future<void> _addMember() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AddMemberScreen(bodyId: widget.bodyId),
    ));
    if (added == true && mounted) {
      setState(() {}); // AsyncView key değişmese de yeniden kur
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    final refData = context.read<RefData>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add),
              label: const Text('Üye Ekle'),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: s12),
          Align(
            alignment: Alignment.centerLeft,
            child: ActiveFilterChips(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ),
          const SizedBox(height: s4),
          Expanded(
            child: AsyncView<List<Membership>>(
              key: ValueKey('members-${widget.bodyId}-$_isActive'),
              load: _load,
              builder: (context, members, reload) {
                if (members.isEmpty) {
                  return EmptyState(
                    icon: Icons.group_off_outlined,
                    message: 'Bu listede üye bulunmuyor.',
                    actionLabel: isAdmin ? 'Üye Ekle' : null,
                    onAction: isAdmin ? _addMember : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(s16, s4, s16, 88),
                    itemCount: members.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: s8),
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return PersonListTile(
                        person: m.person,
                        locationLabel:
                            refData.personLocationLabel(m.person),
                        subtitleExtra: m.roleTitle,
                        activeOverride: m.isActive,
                        trailing: isAdmin
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: kTextSecondary),
                                onSelected: (v) {
                                  if (v == 'toggle') {
                                    _toggleActive(m, reload);
                                  } else if (v == 'remove') {
                                    _removeMember(m, reload);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(m.isActive
                                        ? 'Pasif Yap'
                                        : 'Aktif Yap'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Üyelikten Çıkar',
                                        style:
                                            TextStyle(color: kError)),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
