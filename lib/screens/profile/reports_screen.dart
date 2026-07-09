import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/study_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _exportPdfReport(
      BuildContext context, AuthProvider auth, StudyProvider study) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();

      final user = auth.currentUserModel;
      final totalHours = (study.totalStudyMinutesAllTime / 60.0).toStringAsFixed(1);
      final sessionsCount = study.sessions.length;
      final streak = study.studyStreak;
      final weeklyHours = (study.totalStudyMinutesThisWeek / 60.0).toStringAsFixed(1);

      // Add a page to the PDF document
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('StudyTracker Performance Report',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Profile info
            pw.Text('Academic profile',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text('Name: ${user?.name ?? 'Student'}'),
            pw.Text('Course: ${user?.course ?? 'N/A'}'),
            pw.Text('Semester: ${user?.semester ?? 'N/A'}'),
            pw.Text('Department: ${user?.department ?? 'N/A'}'),
            pw.SizedBox(height: 20),

            // Overall statistics
            pw.Text('Productivity Metrics',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Hours Studied: ${totalHours}h'),
                pw.Text('Total Study Sessions: $sessionsCount'),
                pw.Text('Current Streak: $streak days'),
              ],
            ),
            pw.Text('This Week Hours: ${weeklyHours}h'),
            pw.SizedBox(height: 20),

            // Subject wise details
            pw.Text('Subject-wise Analysis',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.TableHelper.fromTextArray(
              headers: ['Subject', 'Study Time (Minutes)', 'Hours Studied', 'Goal Target (Hours/Wk)'],
              data: study.subjects.map((sub) {
                final mins = study.subjectWiseMinutes[sub.name] ?? 0;
                final hrs = (mins / 60.0).toStringAsFixed(1);
                return [sub.name, '$mins min', '$hrs hr', '${sub.targetHoursPerWeek} hrs'];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // AI Insights
            pw.Text('AI Suggestions & Insights',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Bullet(text: 'Focus Score: ${study.productivityScore.toStringAsFixed(0)}%'),
            pw.Bullet(
                text: 'Consistency Indicator: studying on average ${study.studyStreak} consecutive days.'),
            pw.Bullet(
                text: 'Subject Attention needed: The subject "${study.subjectNeedingAttention}" has the lowest study time ratios. We recommend allocating additional revision slots to this area.'),
            pw.Bullet(
                text: 'Best study time slot: AI analysis shows you are most active between ${study.recommendedStudyTime}. Arrange high-priority tasks in this period.'),
          ],
        ),
      );

      // Open sharing/printing dial
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'StudyTracker_Report_${user?.name ?? 'Student'}.pdf',
      );
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final auth = context.watch<AuthProvider>();

    final weeklyHours = (study.totalStudyMinutesThisWeek / 60.0).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Productivity Reports',
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
              // Export button card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Performance PDF Report',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Export a complete study progress sheet to PDF.',
                                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                          _isGeneratingPdf ? 'Generating PDF...' : 'Download & Export Report',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isGeneratingPdf
                            ? null
                            : () => _exportPdfReport(context, auth, study),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'AI Smart Insights',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Insights Cards
              _buildInsightCard(
                icon: '⚡',
                title: 'Productivity Level',
                content: 'Your productivity score is currently ${study.productivityScore.toStringAsFixed(0)}%. ${study.productivityScore >= 70 ? 'Excellent study consistency!' : 'Try setting more daily goals to boost focus.'}',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                icon: '📚',
                title: 'Subject Breakdown',
                content: 'Your weekly study focus is $weeklyHours hours out of the 20h target. ' 'The subject requiring the most attention is currently ${study.subjectNeedingAttention}.',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                icon: '⏰',
                title: 'Peak Activity Hours',
                content: 'AI analysis suggests your best concentration window is between ${study.recommendedStudyTime}. ' 'We recommend scheduling difficult revisions in this period.',
                color: Colors.green,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
