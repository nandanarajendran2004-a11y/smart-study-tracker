import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/study_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/exam_model.dart';
import '../../utils/constants.dart';
import '../../services/openai_service.dart';

class ExamManagerScreen extends StatefulWidget {
  const ExamManagerScreen({super.key});

  @override
  State<ExamManagerScreen> createState() => _ExamManagerScreenState();
}

class _ExamManagerScreenState extends State<ExamManagerScreen> {
  final _openaiService = OpenAIService();
  bool _isLoadingPlan = false;
  String? _loadingExamId;

  int _calculateDaysLeft(DateTime examDate) {
    final now = DateTime.now();
    final difference = examDate.difference(now).inDays;
    return difference < 0 ? 0 : difference;
  }

  void _generateStudyPlan(ExamModel exam, String apiKey) async {
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your OpenAI API Key in Settings first.')),
      );
      return;
    }

    setState(() {
      _isLoadingPlan = true;
      _loadingExamId = exam.id;
    });

    try {
      final study = Provider.of<StudyProvider>(context, listen: false);
      
      // Request OpenAI completion for revision tips
      final response = await _openaiService.callChatCompletion(
        apiKey: apiKey,
        messages: [
          {
            'role': 'system',
            'content': 'You are an academic coach. Provide a short 3-step revision strategy (max 100 words) for the exam described.'
          },
          {
            'role': 'user',
            'content': 'Subject: ${exam.subject}. Date: ${exam.date}. Location: ${exam.location}. Time left: ${_calculateDaysLeft(exam.date)} days.'
          }
        ],
      );

      final String plan = response['choices'][0]['message']['content'];

      final updatedExam = ExamModel(
        id: exam.id,
        subject: exam.subject,
        date: exam.date,
        time: exam.time,
        location: exam.location,
        studyPlan: plan,
      );

      await study.updateExam(updatedExam);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Study Plan generated! 📚🤖'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate plan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingPlan = false;
        _loadingExamId = null;
      });
    }
  }

  void _showAddExamDialog(StudyProvider study) {
    final subjectController = TextEditingController();
    final timeController = TextEditingController(text: '10:00 AM');
    final locationController = TextEditingController(text: 'Exam Hall A');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Exam Schedule',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject Name',
                      prefixIcon: const Icon(Icons.book_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Time (e.g., 09:30 AM)',
                      prefixIcon: const Icon(Icons.access_time_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location / Hall',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Exam Date',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (subjectController.text.isNotEmpty) {
                          study.addExam(
                            subject: subjectController.text.trim(),
                            date: selectedDate,
                            time: timeController.text.trim(),
                            location: locationController.text.trim(),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text('Add Exam', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final auth = context.watch<AuthProvider>();
    
    // Fetch OpenAI API Key from settings (or let user type it)
    final userSettings = auth.currentUserModel?.settings ?? {};
    final apiKey = userSettings['openAiApiKey'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Exam Manager',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExamDialog(study),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Exam', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: study.exams.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              itemCount: study.exams.length,
              itemBuilder: (context, index) {
                final exam = study.exams[index];
                final daysLeft = _calculateDaysLeft(exam.date);

                Color countdownColor = AppColors.success;
                if (daysLeft <= 3) {
                  countdownColor = AppColors.error;
                } else if (daysLeft <= 7) {
                  countdownColor = AppColors.warning;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                exam.subject,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: countdownColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$daysLeft days left',
                                style: GoogleFonts.poppins(
                                  color: countdownColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '${exam.date.day}/${exam.date.month}/${exam.date.year}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              exam.time,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              exam.location,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // AI study plan suggestions
                        if (exam.studyPlan != null && exam.studyPlan!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🤖', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Suggested Study Plan',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.teal.shade900,
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  exam.studyPlan!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.teal.shade800,
                                    height: 1.4,
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              label: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                              onPressed: () => study.deleteExam(exam.id),
                            ),
                            ElevatedButton.icon(
                              icon: (_isLoadingPlan && _loadingExamId == exam.id)
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 14),
                              label: Text(
                                exam.studyPlan != null ? 'Regenerate Plan' : 'Generate Revision Plan',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: (_isLoadingPlan)
                                  ? null
                                  : () => _generateStudyPlan(exam, apiKey),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No exams scheduled',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            Text(
              'Add exam schedules to track count-downs and request personalized study plans!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
