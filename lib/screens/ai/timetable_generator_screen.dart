import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/study_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../services/openai_service.dart';
import '../../services/firestore_service.dart';

class TimetableGeneratorScreen extends StatefulWidget {
  const TimetableGeneratorScreen({super.key});

  @override
  State<TimetableGeneratorScreen> createState() => _TimetableGeneratorScreenState();
}

class _TimetableGeneratorScreenState extends State<TimetableGeneratorScreen> {
  final _openaiService = OpenAIService();
  final _firestoreService = FirestoreService();

  double _dailyHours = 4.0;
  bool _isLoading = false;
  Map<String, dynamic>? _generatedTimetable;

  @override
  void initState() {
    super.initState();
    _loadSavedTimetable();
  }

  void _loadSavedTimetable() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await _firestoreService.getTimetable(uid);
      if (doc.exists && doc.data() != null) {
        setState(() {
          _generatedTimetable = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint("Error loading saved timetable: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generateTimetable() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final study = Provider.of<StudyProvider>(context, listen: false);
    final uid = auth.user?.uid;
    final userSettings = auth.currentUserModel?.settings ?? {};
    final apiKey = userSettings['openAiApiKey'] ?? '';

    if (uid == null) return;
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your OpenAI API Key in Settings first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Map current active exams to a simple JSON format
      final examsList = study.exams.map((e) => {
        'subject': e.subject,
        'date': e.date.toIso8601String(),
      }).toList();

      final subjectsList = study.subjects.map((s) => s.name).toList();

      final result = await _openaiService.generateTimetable(
        apiKey: apiKey,
        exams: examsList,
        dailyHours: _dailyHours,
        subjectsList: subjectsList,
      );

      // Save to Firestore
      await _firestoreService.saveTimetable(uid, result);

      setState(() {
        _generatedTimetable = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Timetable generated successfully! 📅🤖'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate timetable: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final auth = context.watch<AuthProvider>();
    final userSettings = auth.currentUserModel?.settings ?? {};
    final hasApiKey = (userSettings['openAiApiKey'] ?? '').toString().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'AI Timetable Generator',
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
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI is balancing your workload...', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Config Panel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferences',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Available Study Hours:',
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                              ),
                              Text(
                                '${_dailyHours.toStringAsFixed(1)} hrs/day',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          Slider(
                            value: _dailyHours,
                            min: 1.0,
                            max: 10.0,
                            divisions: 18,
                            activeColor: AppColors.primary,
                            label: '${_dailyHours.toStringAsFixed(1)} hours',
                            onChanged: (val) {
                              setState(() => _dailyHours = val);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Exams Registered: ${study.exams.length}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(
                                _generatedTimetable != null ? 'Regenerate Weekly Planner' : 'Generate Personal Planner',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _generateTimetable,
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (!hasApiKey) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          '⚠️ OpenAI API Key is missing. Go to settings in your Profile and configure your API key to use AI generation.',
                          style: GoogleFonts.poppins(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Timetable Schedule Display
                    if (_generatedTimetable != null) ...[
                      Text(
                        'Your Weekly Schedule',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 12),
                      _buildScheduleView(_generatedTimetable!['weeklySchedule'] ?? {}),
                      const SizedBox(height: 24),
                      if (_generatedTimetable!['dailyTips'] != null) ...[
                        Text(
                          'AI Daily Tips',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        ...(_generatedTimetable!['dailyTips'] as List).map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💡 ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                      child: Text(tip.toString(), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700))),
                                ],
                              ),
                            )),
                      ]
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              const Text('📅', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text(
                                'No timetable generated yet',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildScheduleView(Map<String, dynamic> schedule) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    return Column(
      children: weekdays.map((day) {
        final List slots = schedule[day] ?? [];
        return ExpansionTile(
          title: Text(day, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('${slots.length} session${slots.length == 1 ? "" : "s"} scheduled', style: GoogleFonts.poppins(fontSize: 11)),
          initiallyExpanded: slots.isNotEmpty,
          children: slots.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text('Free Day! Rest and recharge. ☕', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  )
                ]
              : slots.map<Widget>((slot) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot['subject'] ?? 'Study',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                              ),
                              Text(
                                slot['focusArea'] ?? 'Revision',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              slot['timeSlot'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                            Text(
                              '${slot['durationHours'] ?? 2} hrs',
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                }).toList(),
        );
      }).toList(),
    );
  }
}
