import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';
import 'timetable_generator_screen.dart';
import 'study_assistant_screen.dart';
import 'quiz_generator_screen.dart';
import '../exams/exam_manager_screen.dart';

class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'AI Study Hub 🤖',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Study Tools',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'Leverage OpenAI intelligence to boost study productivity.',
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // AI tools grid/list
              _buildAIHubCard(
                context,
                title: 'AI Timetable Generator',
                description: 'Generate weekly study planners prioritizing difficult subjects and balancing breaks based on exam schedules.',
                icon: '📅',
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimetableGeneratorScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _buildAIHubCard(
                context,
                title: 'AI Study Assistant',
                description: 'Upload PDF, DOCX, or TXT notes. Extract study sheets, flashcards, summaries, and key formula lists instantly.',
                icon: '📚',
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyAssistantScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _buildAIHubCard(
                context,
                title: 'AI Quiz & Evaluation',
                description: 'Generate custom practice tests (MCQs, True/False, Short answers). Submit text answers for AI grading and feedback.',
                icon: '📝',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizGeneratorScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _buildAIHubCard(
                context,
                title: 'Exam Manager',
                description: 'Add exam timetables, track automated countdowns, and get detailed AI suggested revision plans leading up to tests.',
                icon: '🎯',
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExamManagerScreen()),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIHubCard(
    BuildContext context, {
    required String title,
    required String description,
    required String icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
