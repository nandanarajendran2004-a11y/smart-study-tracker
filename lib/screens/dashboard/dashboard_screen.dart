import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/study_provider.dart';
import '../../models/study_session_model.dart';
import '../timer/study_timer_screen.dart';
import '../analytics/analytics_screen.dart';
import '../goals/goals_screen.dart';
import '../profile/profile_screen.dart';
import '../ai/ai_hub_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeTab(),
    StudyTimerScreen(),
    AnalyticsScreen(),
    GoalsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        elevation: 8,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer_rounded),
              label: 'Study'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: 'Goals'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─── HOME TAB ────────────────────────────────────────────────────────────────

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(_greeting(),
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 14)),
                      Text('Ready to Study? 📚',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${study.studyStreak} day streak  •  '
                          '${(study.totalStudyMinutesToday / 60).toStringAsFixed(1)}h today',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Productivity Score ──
                _ProductivityScoreCard(score: study.productivityScore),
                const SizedBox(height: 16),

                // ── Quick Stats Row ──
                Row(children: [
                  _QuickStatCard(
                    emoji: '🔥',
                    value: '${study.studyStreak}',
                    label: 'Day Streak',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  _QuickStatCard(
                    emoji: '⏱️',
                    value:
                        '${(study.totalStudyMinutesToday / 60).toStringAsFixed(1)}h',
                    label: 'Today',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _QuickStatCard(
                    emoji: '📅',
                    value:
                        '${(study.totalStudyMinutesThisWeek / 60).toStringAsFixed(1)}h',
                    label: 'This Week',
                    color: Colors.green,
                  ),
                ]),
                const SizedBox(height: 16),

                // ── AI Recommendation ──
                _AICard(study: study),
                const SizedBox(height: 20),

                // ── Recent Sessions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Sessions',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${study.sessions.length} total',
                        style: GoogleFonts.poppins(
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),

                if (study.sessions.isEmpty)
                  _EmptySessionsCard()
                else
                  ...study.sessions.reversed
                      .take(5)
                      .map((s) => _SessionCard(session: s)),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Productivity Score Card ──
class _ProductivityScoreCard extends StatelessWidget {
  final double score;
  const _ProductivityScoreCard({required this.score});

  Color get _scoreColor {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String get _scoreEmoji {
    if (score >= 70) return '🔥';
    if (score >= 40) return '📈';
    return '💪';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Productivity Score',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_scoreEmoji, style: const TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: _scoreColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: _scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score >= 70
                          ? 'Excellent work!'
                          : score >= 40
                              ? 'Keep going!'
                              : 'Start studying!',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Stat Card ──
class _QuickStatCard extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _QuickStatCard(
      {required this.emoji,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── AI Card ──
class _AICard extends StatelessWidget {
  final StudyProvider study;
  const _AICard({required this.study});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIHubScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.teal.shade50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('🤖', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('AI Smart Insights & Hub',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.teal),
              ],
            ),
          const SizedBox(height: 10),
          _insightRow('⏰', 'Best study time: ${study.recommendedStudyTime}'),
          const SizedBox(height: 6),
          _insightRow(
              '📚', 'Needs attention: ${study.subjectNeedingAttention}'),
          const SizedBox(height: 6),
          _insightRow('🎯',
              'Weekly progress: ${(study.totalStudyMinutesThisWeek / 60).toStringAsFixed(1)} / 20h'),
        ],
      ),
    ),
  );
}

  Widget _insightRow(String emoji, String text) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.green.shade800))),
    ]);
  }
}

// ── Empty State ──
class _EmptySessionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        const Text('📖', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('No sessions yet',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text('Tap Study tab to start tracking!',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }
}

// ── Session Card ──
class _SessionCard extends StatelessWidget {
  final StudySessionModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book_rounded,
              color: Color(0xFF6C63FF), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.subjectName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Text(
                  '${session.durationMinutes} min  •  '
                  '${_formatDate(session.startTime)}',
                  style:
                      GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${session.focusScore}%',
              style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}  $hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}