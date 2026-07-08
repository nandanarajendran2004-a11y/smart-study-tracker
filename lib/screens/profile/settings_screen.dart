import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_provider.dart';
import '../../services/reminder_service.dart';
import '../../utils/constants.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeyObscured = true;

  // Reminder state
  bool _reminderEnabled = false;
  int _reminderHour = 20;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadReminderPrefs();
    _loadApiKey();
  }

  Future<void> _loadReminderPrefs() async {
    final prefs = await ReminderService().getReminderPreferences();
    if (mounted) {
      setState(() {
        _reminderEnabled = prefs['enabled'] ?? false;
        _reminderHour = prefs['hour'] ?? 20;
        _reminderMinute = prefs['minute'] ?? 0;
      });
    }
  }

  void _loadApiKey() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final settings = auth.currentUserModel?.settings ?? {};
    final savedKey = settings['openAiApiKey'] ?? '';
    _apiKeyController.text = savedKey;
  }

  Future<void> _saveApiKey() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final settings = Map<String, dynamic>.from(
      auth.currentUserModel?.settings ?? {},
    );
    settings['openAiApiKey'] = _apiKeyController.text.trim();
    await auth.updateSettings(settings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API Key saved! 🔑'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked != null) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
      await ReminderService().setReminderPreferences(
        enabled: _reminderEnabled,
        hour: _reminderHour,
        minute: _reminderMinute,
      );
    }
  }

  void _exportUserData(StudyProvider study, AuthProvider auth) {
    // Generate JSON package of user data
    final userData = {
      "profile": auth.currentUserModel?.toJson(),
      "subjects": study.subjects.map((s) => s.toJson()).toList(),
      "sessions": study.sessions.map((s) => s.toJson()).toList(),
      "goals": study.goals.map((g) => g.toJson()).toList(),
      "exams": study.exams.map((e) => e.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent("  ").convert(userData);

    // Show dynamic share/copy dialog for exporting data
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exported Data (JSON)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Your study data has been successfully compiled. Copy it below:',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          'Warning: This action is permanent. All your subjects, sessions, goals, and settings will be permanently erased.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await auth.deleteUserAccount();
              if (success && mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(auth.errorMessage ?? 'Failed to delete account'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text('Delete Permanently', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final study = context.watch<StudyProvider>();
    final user = auth.currentUserModel;

    // Load defaults if settings map is empty
    final settings = user?.settings ?? {};
    final isDarkMode = settings['darkMode'] == true;
    final isNotifEnabled = settings['notificationsEnabled'] != false;
    final language = settings['language'] ?? 'English';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          children: [
            // ── Appearance Section ──
            _buildSectionHeader('Appearance'),
            SwitchListTile(
              title: Text('Dark Mode', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text('Instantly switch app theme to dark mode', style: GoogleFonts.poppins(fontSize: 11)),
              value: isDarkMode,
              activeThumbColor: AppColors.primary,
              onChanged: (val) {
                final newSettings = Map<String, dynamic>.from(settings);
                newSettings['darkMode'] = val;
                auth.updateSettings(newSettings);
              },
            ),
            const Divider(),

            // ── AI Configuration Section ──
            _buildSectionHeader('AI Configuration'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy_outlined, color: Colors.teal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OpenAI API Key',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              'Required for AI Timetable, Quiz, and Study Assistant',
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _isApiKeyObscured,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isApiKeyObscured ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isApiKeyObscured = !_isApiKeyObscured;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _saveApiKey,
                      child: Text('Save API Key', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // ── Notifications & Reminders Section ──
            _buildSectionHeader('Reminders & Alerts'),
            SwitchListTile(
              title: Text('Push Notifications', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text('Receive reminders about timers, streaks, and exams', style: GoogleFonts.poppins(fontSize: 11)),
              value: isNotifEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (val) {
                final newSettings = Map<String, dynamic>.from(settings);
                newSettings['notificationsEnabled'] = val;
                auth.updateSettings(newSettings);
              },
            ),
            SwitchListTile(
              title: Text('Daily Study Reminder', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _reminderEnabled
                    ? 'Reminder at ${ReminderService.formatTime(_reminderHour, _reminderMinute)}'
                    : 'Get a daily push to start studying',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
              value: _reminderEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (val) async {
                setState(() => _reminderEnabled = val);
                await ReminderService().setReminderPreferences(
                  enabled: val,
                  hour: _reminderHour,
                  minute: _reminderMinute,
                );
              },
            ),
            if (_reminderEnabled)
              ListTile(
                leading: const Icon(Icons.access_time, color: AppColors.primary),
                title: Text('Reminder Time', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  ReminderService.formatTime(_reminderHour, _reminderMinute),
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                onTap: _pickReminderTime,
              ),
            const Divider(),

            // ── Preferences Section ──
            _buildSectionHeader('Preferences'),
            ListTile(
              title: Text('Language', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text('Change application display language', style: GoogleFonts.poppins(fontSize: 11)),
              trailing: DropdownButton<String>(
                value: language,
                onChanged: (String? newVal) {
                  if (newVal != null) {
                    final newSettings = Map<String, dynamic>.from(settings);
                    newSettings['language'] = newVal;
                    auth.updateSettings(newSettings);
                  }
                },
                items: <String>['English', 'Spanish', 'French', 'German']
                    .map<DropdownMenuItem<String>>((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val, style: GoogleFonts.poppins(fontSize: 13)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),

            // ── Privacy & Data Section ──
            _buildSectionHeader('Privacy & Data'),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.success),
              title: Text('Export My Study Data', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text('Download subjects, sessions, and goals history', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () => _exportUserData(study, auth),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Delete My Account', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red)),
              subtitle: Text('Permanently erase account information and records', style: GoogleFonts.poppins(fontSize: 11)),
              onTap: () => _confirmDeleteAccount(auth),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
