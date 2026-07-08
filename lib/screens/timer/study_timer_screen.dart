import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/study_provider.dart';
import '../../providers/timer_provider.dart';
import '../../models/subject_model.dart';
import '../../utils/constants.dart';
import '../subjects/subjects_screen.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studyProvider = Provider.of<StudyProvider>(context, listen: false);
      if (studyProvider.subjects.isNotEmpty) {
        setState(() {
          _selectedSubjectId = studyProvider.subjects.first.id;
        });
      }
    });
  }

  Future<void> _handleStop(BuildContext context, TimerProvider timer, StudyProvider study) async {
    final subjectId = timer.currentSubjectId;
    final subjectName = timer.currentSubjectName;
    final startTime = timer.sessionStartTime;
    final isPomodoro = timer.mode == TimerMode.pomodoro;

    final minutes = timer.stopAndGetDuration();

    if (minutes > 0 && subjectId != null && subjectName != null && startTime != null) {
      await study.addSession(
        subjectId: subjectId,
        subjectName: subjectName,
        startTime: startTime,
        endTime: DateTime.now(),
        durationMinutes: minutes,
        isPomodoroSession: isPomodoro,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved session: $minutes min of $subjectName! 🎉'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session discarded (less than 1 minute). Keep studying! 💪'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerProvider>();
    final study = context.watch<StudyProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Study Timer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Manage Subjects',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubjectsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Mode Selector
                _buildModeSelector(timer),
                const SizedBox(height: 40),

                // Large Timer Dial
                _buildTimerDial(timer, study),
                const SizedBox(height: 12),

                if (timer.mode == TimerMode.countdown && timer.state == TimerState.idle) ...[
                  Text('Set Countdown Duration', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [5, 10, 15, 25, 45, 60].map((mins) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text('$mins min'),
                            selected: (timer.countdownSecondsLeft ~/ 60) == mins,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: (timer.countdownSecondsLeft ~/ 60) == mins
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onSelected: (val) {
                              if (val) timer.setCountdownDuration(mins);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 40),
                ],

                // Subject Selection
                _buildSubjectSelection(timer, study),
                const SizedBox(height: 50),

                // Action Buttons
                _buildActionButtons(timer, study),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(TimerProvider timer) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab('Stopwatch ⏱️', timer.mode == TimerMode.stopwatch, () {
            if (!timer.isRunning) {
              timer.setMode(TimerMode.stopwatch);
            }
          }),
          _buildModeTab('Countdown ⏰', timer.mode == TimerMode.countdown, () {
            if (!timer.isRunning) {
              timer.setMode(TimerMode.countdown);
            }
          }),
          _buildModeTab('Pomodoro 🍅', timer.mode == TimerMode.pomodoro, () {
            if (!timer.isRunning) {
              timer.setMode(TimerMode.pomodoro);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
            color: isActive ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDial(TimerProvider timer, StudyProvider study) {
    final progress = timer.timerProgress;

    Color ringColor = AppColors.primary;
    if (timer.state == TimerState.onBreak) {
      ringColor = AppColors.success;
    } else if (timer.state == TimerState.paused) {
      ringColor = AppColors.warning;
    }

    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ring
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 10,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade100),
            ),
          ),
          // Progress Ring
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Time Display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timer.formattedTime,
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timer.state == TimerState.studying
                    ? 'STUDYING'
                    : timer.state == TimerState.paused
                        ? 'PAUSED'
                        : timer.state == TimerState.onBreak
                            ? 'BREAK ☕'
                            : 'READY',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ringColor,
                  letterSpacing: 2.0,
                ),
              ),
              if (timer.mode == TimerMode.pomodoro && timer.pomodoroRound > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Round: ${timer.pomodoroRound}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelection(TimerProvider timer, StudyProvider study) {
    if (timer.isRunning) {
      final activeSubjectColor = study.subjects
          .firstWhere((s) => s.id == timer.currentSubjectId,
              orElse: () => SubjectModel(id: '', name: '', colorValue: 0xFF6C63FF))
          .colorValue;

      return Column(
        children: [
          Text(
            'CURRENT SUBJECT',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(activeSubjectColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  timer.currentSubjectName ?? 'Studying',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'SELECT SUBJECT',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (study.subjects.isEmpty)
          _buildAddSubjectPrompt()
        else
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: study.subjects.length,
              itemBuilder: (context, index) {
                final subject = study.subjects[index];
                final isSelected = subject.id == _selectedSubjectId;
                return _buildSubjectCard(subject, isSelected);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAddSubjectPrompt() {
    return Builder(
      builder: (context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubjectsScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No subjects yet — tap to add your first subject',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectModel subject, bool isSelected) {
    final themeColor = Color(subject.colorValue);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubjectId = subject.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              subject.name,
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                color: isSelected ? themeColor : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(TimerProvider timer, StudyProvider study) {
    if (timer.state == TimerState.idle) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          onPressed: () {
            if (study.subjects.isNotEmpty) {
              final selectedSubject = study.subjects.firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => study.subjects.first,
              );
              timer.startStudying(selectedSubject.id, selectedSubject.name);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please add a subject first!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Text(
            'Start Studying',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    final isStudying = timer.state == TimerState.studying;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _handleStop(context, timer, study),
                  child: Text(
                    'Stop',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStudying ? AppColors.warning : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () => timer.pauseResume(),
                  child: Text(
                    isStudying ? 'Pause' : 'Resume',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (timer.state == TimerState.onBreak) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => timer.skipBreak(),
              child: Text(
                'Skip Break',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}