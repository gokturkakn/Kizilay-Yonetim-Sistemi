import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'assignment_list_screen.dart';
import 'field_activity_list_screen.dart';
import 'meetings_screen.dart';

/// Saha Çalışmaları (home) — UX §3.11.
class FieldHomeScreen extends StatelessWidget {
  const FieldHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saha Çalışmaları')),
      body: ListView(
        padding: const EdgeInsets.all(s16),
        children: [
          NavCard(
            title: 'Saha Faaliyetleri',
            subtitle: 'Görev formu ile etkinlik kaydı',
            icon: Icons.volunteer_activism_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FieldActivityListScreen(),
            )),
          ),
          const SizedBox(height: s12),
          NavCard(
            title: 'Yönetsel Faaliyetler',
            subtitle: 'Kurul ve komisyon toplantıları',
            icon: Icons.meeting_room_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MeetingsScreen(),
            )),
          ),
          const SizedBox(height: s12),
          NavCard(
            title: 'Görev Atamaları',
            subtitle: 'Genel merkez tarafından atanan görevler',
            icon: Icons.assignment_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AssignmentListScreen(),
            )),
          ),
        ],
      ),
    );
  }
}
