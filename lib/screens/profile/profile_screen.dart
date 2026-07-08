import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_provider.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'academic_details_screen.dart';
import 'reports_screen.dart';
import 'badges_screen.dart';
import 'help_support_screen.dart';
import 'settings_screen.dart';
import '../subjects/subjects_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final study = context.watch<StudyProvider>();
    final user = auth.currentUserModel;

    final totalHours = (study.totalStudyMinutesAllTime / 60.0).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // Dynamic Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.15),
              backgroundImage: user != null && user.profileImage.isNotEmpty
                  ? NetworkImage(user.profileImage)
                  : null,
              child: user == null || user.profileImage.isEmpty
                  ? const Text('👨‍🎓', style: TextStyle(fontSize: 48))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user?.name ?? 'Student',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? 'student@email.com',
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),

            // Course & Department Chips
            if (user != null && (user.course.isNotEmpty || user.department.isNotEmpty)) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (user.course.isNotEmpty)
                    Chip(
                      label: Text('${user.course} • ${user.semester}'),
                      labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  if (user.department.isNotEmpty)
                    Chip(
                      label: Text(user.department),
                      labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Study Statistics Row
            Row(
              children: [
                _buildStatTile('🔥 Streak', '${study.studyStreak}d', Colors.orange),
                const SizedBox(width: 10),
                _buildStatTile('⏱️ Time', '${totalHours}h', Colors.blue),
                const SizedBox(width: 10),
                _buildStatTile('🎓 Level', '${study.level}', Colors.purple),
              ],
            ),
            const SizedBox(height: 28),

            // Settings options list
            _SettingTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.school_outlined,
              label: 'Academic Details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AcademicDetailsScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.menu_book_outlined,
              label: 'Manage Subjects',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubjectsScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.bar_chart_outlined,
              label: 'My Reports',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.emoji_events_outlined,
              label: 'Badges & Achievements',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BadgesScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            _SettingTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF6C63FF)),
        title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}