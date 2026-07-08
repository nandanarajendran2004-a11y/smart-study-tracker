import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/study_provider.dart';
import '../../models/study_session_model.dart';
import '../../utils/constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedRange = 'weekly'; // 'daily', 'weekly', 'monthly', 'yearly'

  static const _colors = [
    Color(0xFF6C63FF), Color(0xFFFF9800), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFFF44336), Color(0xFF009688),
  ];

  List<StudySessionModel> _filterSessions(List<StudySessionModel> sessions) {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'daily':
        return sessions
            .where((s) => s.startTime.year == now.year && s.startTime.month == now.month && s.startTime.day == now.day)
            .toList();
      case 'weekly':
        final weekAgo = now.subtract(const Duration(days: 7));
        return sessions.where((s) => s.startTime.isAfter(weekAgo)).toList();
      case 'monthly':
        final monthAgo = now.subtract(const Duration(days: 30));
        return sessions.where((s) => s.startTime.isAfter(monthAgo)).toList();
      case 'yearly':
        final yearAgo = now.subtract(const Duration(days: 365));
        return sessions.where((s) => s.startTime.isAfter(yearAgo)).toList();
      default:
        return sessions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    final allSessions = study.sessions;
    final filteredSessions = _filterSessions(allSessions);

    // Calculate aggregated stats
    final totalMinutes = filteredSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalHours = totalMinutes / 60.0;
    
    final averageMinutes = filteredSessions.isEmpty ? 0.0 : totalMinutes / filteredSessions.length;
    
    final avgFocusScore = filteredSessions.isEmpty
        ? 0.0
        : filteredSessions.fold<int>(0, (sum, s) => sum + s.focusScore) / filteredSessions.length;

    final pomodoroCount = filteredSessions.where((s) => s.isPomodoroSession).length;
    final completedGoalsCount = study.goals.where((g) => g.isCompleted).length;

    // Subject wise breakdown for filtered sessions
    final subjectData = <String, int>{};
    for (final s in filteredSessions) {
      subjectData[s.subjectName] = (subjectData[s.subjectName] ?? 0) + s.durationMinutes;
    }

    // Chart Y max values
    final weekData = study.last7DaysMinutes;
    final maxBar = weekData.isEmpty ? 1 : weekData.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Range Selector / Segmented Buttons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildRangeTab('Daily', 'daily'),
                  _buildRangeTab('Weekly', 'weekly'),
                  _buildRangeTab('Monthly', 'monthly'),
                  _buildRangeTab('Yearly', 'yearly'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary Stats Row 1
            Row(
              children: [
                _SummaryTile(
                  label: 'Study Hours',
                  value: '${totalHours.toStringAsFixed(1)}h',
                  icon: Icons.access_time_rounded,
                  color: Colors.blue,
                ),
                const SizedBox(width: 10),
                _SummaryTile(
                  label: 'Sessions',
                  value: '${filteredSessions.length}',
                  icon: Icons.event_note_rounded,
                  color: Colors.purple,
                ),
                const SizedBox(width: 10),
                _SummaryTile(
                  label: 'Streak',
                  value: '${study.studyStreak}d',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary Stats Row 2
            Row(
              children: [
                _SummaryTile(
                  label: 'Avg Focus',
                  value: '${avgFocusScore.toStringAsFixed(0)}%',
                  icon: Icons.center_focus_strong_outlined,
                  color: Colors.teal,
                ),
                const SizedBox(width: 10),
                _SummaryTile(
                  label: 'Pomodoros',
                  value: '$pomodoroCount',
                  icon: Icons.timer_outlined,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                _SummaryTile(
                  label: 'Goals Met',
                  value: '$completedGoalsCount',
                  icon: Icons.playlist_add_check_rounded,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bar Chart Section (Last 7 Days)
            Text(
              'Weekly Study History',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: weekData.every((m) => m == 0)
                  ? Center(
                      child: Text('No data yet — start studying!',
                          style: GoogleFonts.poppins(color: Colors.grey)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxBar.toDouble() + 30,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                return Text(days[value.toInt() % 7], style: GoogleFonts.poppins(fontSize: 12));
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(
                          7,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weekData[i].toDouble(),
                                color: const Color(0xFF6C63FF),
                                width: 22,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Pie Chart Section (Subject Distribution)
            if (subjectData.isNotEmpty) ...[
              Text(
                'Subject Distribution',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _buildSections(subjectData),
                          centerSpaceRadius: 50,
                          sectionsSpace: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...subjectData.entries.toList().asMap().entries.map(
                          (entry) => _LegendRow(
                            color: _colors[entry.key % _colors.length],
                            name: entry.value.key,
                            minutes: entry.value.value,
                          ),
                        ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeTab(String label, String value) {
    final isActive = _selectedRange == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRange = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b);
    int colorIndex = 0;
    return data.entries.map((e) {
      final pct = e.value / total * 100;
      final color = _colors[colorIndex++ % _colors.length];
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        color: color,
        radius: 75,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }).toList();
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final int minutes;
  const _LegendRow({required this.color, required this.name, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 13))),
          Text(
            '${(minutes / 60).toStringAsFixed(1)}h',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}