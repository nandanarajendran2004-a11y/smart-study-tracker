import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/study_provider.dart';
import '../../models/goal_model.dart';
import '../../utils/constants.dart';
import '../../models/subject_model.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _selectedType = 'daily';
  String? _selectedSubjectId;
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 1));

  String _getGoalEmoji(String type) {
    switch (type) {
      case 'daily':
        return '📅';
      case 'weekly':
        return '📆';
      case 'subject':
        return '📐';
      default:
        return '🎯';
    }
  }

  @override
  Widget build(BuildContext context) {
    final studyProvider = context.watch<StudyProvider>();
    final goals = studyProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: Text('Goals', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGoalDialog(studyProvider),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Goal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: goals.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: goals.length,
              itemBuilder: (context, i) {
                final g = goals[i];
                final progress = g.progress.clamp(0.0, 1.0);
                final isDone = g.isCompleted;

                // Find subject name if subject-specific goal
                String titleExtra = '';
                if (g.type == 'subject' && g.subjectId != null) {
                  final sub = studyProvider.subjects.firstWhere(
                    (s) => s.id == g.subjectId,
                    orElse: () => mockSubject,
                  );
                  if (sub.name.isNotEmpty) {
                    titleExtra = ' (${sub.name})';
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.green.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: isDone ? Colors.green.shade200 : Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_getGoalEmoji(g.type), style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${g.title}$titleExtra',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.grey.shade800),
                            ),
                          ),
                          if (isDone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Done ✓',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                g.type.toUpperCase(),
                                style: GoogleFonts.poppins(
                                    color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade100,
                          color: isDone ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${g.completedMinutes} / ${g.targetMinutes} min',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(color: Colors.grey.shade100, height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Deadline: ${_formatDate(g.deadline)}',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
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
              'No goals set yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            Text(
              'Create daily, weekly, or subject goals to keep yourself on track!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(StudyProvider studyProvider) {
    final titleController = TextEditingController();
    final targetController = TextEditingController();

    // Default values
    _selectedType = 'daily';
    _selectedDeadline = DateTime.now().add(const Duration(days: 1));
    if (studyProvider.subjects.isNotEmpty) {
      _selectedSubjectId = studyProvider.subjects.first.id;
    }

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
                    'Create New Goal',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target (minutes)',
                      prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Goal Type',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeRadio('daily', 'Daily', setModalState),
                      const SizedBox(width: 10),
                      _buildTypeRadio('weekly', 'Weekly', setModalState),
                      const SizedBox(width: 10),
                      _buildTypeRadio('subject', 'Subject', setModalState),
                    ],
                  ),
                  if (_selectedType == 'subject' && studyProvider.subjects.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Select Subject',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSubjectId,
                          isExpanded: true,
                          items: studyProvider.subjects.map((sub) {
                            return DropdownMenuItem<String>(
                              value: sub.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: Color(sub.colorValue)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(sub.name, style: GoogleFonts.poppins(fontSize: 14)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              _selectedSubjectId = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Deadline',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDeadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          _selectedDeadline = picked;
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
                            _formatDate(_selectedDeadline),
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.grey),
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
                        if (titleController.text.isNotEmpty && targetController.text.isNotEmpty) {
                          final target = int.tryParse(targetController.text) ?? 0;
                          if (target > 0) {
                            studyProvider.addGoal(
                              title: titleController.text.trim(),
                              targetMinutes: target,
                              deadline: _selectedDeadline,
                              type: _selectedType,
                              subjectId: _selectedType == 'subject' ? _selectedSubjectId : null,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Goal created successfully! 🎯'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Add Goal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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

  Widget _buildTypeRadio(String value, String label, StateSetter setModalState) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setModalState(() {
            _selectedType = value;
            // Set reasonable default deadlines based on type
            if (value == 'daily') {
              _selectedDeadline = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59);
            } else if (value == 'weekly') {
              _selectedDeadline = DateTime.now().add(const Duration(days: 7));
            } else {
              _selectedDeadline = DateTime.now().add(const Duration(days: 30));
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  final mockSubject = SubjectModel(id: '', name: '', colorValue: 0xFF6C63FF);
}