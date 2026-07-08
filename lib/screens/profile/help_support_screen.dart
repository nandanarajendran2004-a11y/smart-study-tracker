import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "question": "How is the productivity score calculated?",
        "answer": "Your score combines your daily study duration (weighted up to 70%), your active study streak bonus (up to 20%), and consistency incentives (10%). Studying daily maintains a peak score."
      },
      {
        "question": "How do I earn badges?",
        "answer": "Badges unlock automatically when you achieve milestones: study daily for 7 days, accumulate 100 study hours, or complete 10 daily targets. You can track progress in the Badges screen."
      },
      {
        "question": "How do I generate an AI timetable?",
        "answer": "Go to the AI Hub from your Home tab, tap 'AI Timetable Generator', input your subjects, upcoming exams, difficulty, and available hours, then tap generate. It will create a balanced schedule for you."
      },
      {
        "question": "Can I upload materials on the web?",
        "answer": "Yes, PDF and TXT file uploads are supported on both mobile and web. AI Study Assistant will automatically extract key text, definitions, and flashcards."
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            ...faqs.map((faq) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faq["question"]!,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        faq["answer"]!,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            Text(
              'Contact Support',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email, color: AppColors.primary),
                      const SizedBox(width: 14),
                      Text(
                        'support@studytracker.com',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Feel free to email us directly for feature requests, bug reports, or database queries. We usually reply within 24 hours.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
