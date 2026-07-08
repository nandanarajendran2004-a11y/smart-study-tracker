import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../services/openai_service.dart';
import '../../services/firestore_service.dart';

class QuizGeneratorScreen extends StatefulWidget {
  const QuizGeneratorScreen({super.key});

  @override
  State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  final _openaiService = OpenAIService();
  final _firestoreService = FirestoreService();

  String _difficulty = 'medium';
  bool _isLoading = false;
  bool _isPlaying = false;
  
  List<Map<String, dynamic>> _quizzesList = [];
  Map<String, dynamic>? _selectedMaterial;
  Map<String, dynamic>? _activeQuiz;
  
  // Interactive player states
  int _currentQuestionIndex = 0;
  final Map<int, String> _userAnswers = {};
  
  // AI evaluation states
  bool _isEvaluating = false;
  Map<String, dynamic>? _evaluationResult;

  @override
  void initState() {
    super.initState();
    _loadMaterialsAndQuizzes();
  }

  void _loadMaterialsAndQuizzes() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final materials = await _firestoreService.getStudyMaterialsStream(uid).first;
      final quizzes = await _firestoreService.getQuizzesStream(uid).first;
      setState(() {
        _quizzesList = quizzes;
        if (materials.isNotEmpty) {
          _selectedMaterial = materials.first;
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz resources: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _generateQuiz() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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

    if (_selectedMaterial == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a study material from the history first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quizResult = await _openaiService.generateQuiz(
        apiKey: apiKey,
        title: _selectedMaterial!['title'] ?? 'Study material',
        materialText: _selectedMaterial!['rawText'] ?? '',
        difficulty: _difficulty,
      );

      final quizData = {
        'id': UniqueKey().hashCode.toString(),
        'title': quizResult['quizTitle'] ?? 'AI Practice Quiz',
        'difficulty': _difficulty,
        'questions': quizResult['questions'] ?? [],
      };

      // Save to Firestore
      await _firestoreService.saveQuiz(uid, quizData);

      setState(() {
        _activeQuiz = quizData;
        _isPlaying = true;
        _currentQuestionIndex = 0;
        _userAnswers.clear();
        _evaluationResult = null;
      });

      _loadMaterialsAndQuizzes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate quiz: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _evaluateShortAnswer(String question, String modelAnswer, String userAnswer) async {
    if (userAnswer.trim().isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userSettings = auth.currentUserModel?.settings ?? {};
    final apiKey = userSettings['openAiApiKey'] ?? '';

    if (apiKey.isEmpty) return;

    setState(() {
      _isEvaluating = true;
      _evaluationResult = null;
    });

    try {
      final result = await _openaiService.evaluateAnswer(
        apiKey: apiKey,
        question: question,
        modelAnswer: modelAnswer,
        userAnswer: userAnswer,
      );

      setState(() {
        _evaluationResult = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluation error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isEvaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userSettings = auth.currentUserModel?.settings ?? {};
    final hasApiKey = (userSettings['openAiApiKey'] ?? '').toString().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isPlaying ? 'Interactive Quiz' : 'AI Quiz Generator',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isPlaying ? Icons.close : Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () {
            if (_isPlaying) {
              setState(() {
                _isPlaying = false;
                _evaluationResult = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
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
                    Text('AI is formulating test questions... 📝🤖', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            : _isPlaying
                ? _buildQuizPlayer()
                : _buildQuizSetup(hasApiKey),
      ),
    );
  }

  Widget _buildQuizSetup(bool hasApiKey) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasApiKey) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                '⚠️ OpenAI API Key is missing. Please configure it in Settings to enable quiz generation.',
                style: GoogleFonts.poppins(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Step 1: Select Material',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),

          // Dropdown for material selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                hint: const Text('Select Study Material'),
                value: _selectedMaterial,
                isExpanded: true,
                onChanged: (val) {
                  setState(() => _selectedMaterial = val);
                },
                items: _quizzesList.isEmpty
                    ? []
                    : _quizzesList.map((q) => DropdownMenuItem<Map<String, dynamic>>(
                          value: q,
                          child: Text(q['title'] ?? 'Material', style: GoogleFonts.poppins(fontSize: 13)),
                        )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Step 2: Select Difficulty',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              _buildDifficultyRadio('easy', 'Easy'),
              const SizedBox(width: 8),
              _buildDifficultyRadio('medium', 'Medium'),
              const SizedBox(width: 8),
              _buildDifficultyRadio('hard', 'Hard'),
            ],
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: Text('Generate Practice Quiz', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _generateQuiz,
            ),
          ),
          const SizedBox(height: 40),

          // Past quizzes list
          Text(
            'Past Practice Quizzes',
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          if (_quizzesList.isEmpty)
            Text('No past quizzes saved.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey))
          else
            ..._quizzesList.map((quiz) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(quiz['title'] ?? 'Practice Quiz', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Difficulty: ${(quiz['difficulty'] ?? 'medium').toString().toUpperCase()}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.play_arrow, color: AppColors.primary),
                    onTap: () {
                      setState(() {
                        _activeQuiz = quiz;
                        _isPlaying = true;
                        _currentQuestionIndex = 0;
                        _userAnswers.clear();
                        _evaluationResult = null;
                      });
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildDifficultyRadio(String value, String label) {
    final isSelected = _difficulty == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _difficulty = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primary : Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizPlayer() {
    final List questions = _activeQuiz?['questions'] ?? [];
    if (questions.isEmpty) {
      return const Center(child: Text('Error: Empty Quiz loaded.'));
    }

    final question = questions[_currentQuestionIndex];
    final String type = question['type'] ?? 'mcq';
    final String qText = question['question'] ?? '';
    final List options = question['options'] ?? [];
    final String correctAns = question['correctAnswer'] ?? '';
    final String explanation = question['explanation'] ?? '';

    final currentAnswer = _userAnswers[_currentQuestionIndex] ?? '';
    final isLast = _currentQuestionIndex == questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Text(
                'Type: ${type.replaceAll('_', ' ').toUpperCase()}',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / questions.length,
            color: AppColors.primary,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 24),

          // Question Text
          Text(
            qText,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 24),

          // Question Input options based on type
          Expanded(
            child: SingleChildScrollView(
              child: _buildQuestionInput(type, options, currentAnswer),
            ),
          ),

          // Evaluation details for written answers
          if (_evaluationResult != null && (type == 'short_answer' || type == 'long_answer')) ...[
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AI Answer Score:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                      Text('${_evaluationResult!['score']} / 10', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_evaluationResult!['feedback'] ?? '', style: GoogleFonts.poppins(fontSize: 11, color: Colors.teal.shade800)),
                  if (_evaluationResult!['missingConcepts'] != null && (_evaluationResult!['missingConcepts'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Missing Concepts:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.teal.shade900)),
                    ...(_evaluationResult!['missingConcepts'] as List).map((c) => Text('• $c', style: GoogleFonts.poppins(fontSize: 10, color: Colors.red.shade800))),
                  ]
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Footer Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentQuestionIndex--;
                      _evaluationResult = null;
                    });
                  },
                  child: const Text('Back'),
                )
              else
                const SizedBox(),

              // Short Answer Evaluation Button
              if ((type == 'short_answer' || type == 'long_answer') && _evaluationResult == null)
                ElevatedButton.icon(
                  icon: _isEvaluating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                      : const Icon(Icons.auto_awesome, size: 14),
                  label: Text('AI Grade Answer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: _isEvaluating ? null : () => _evaluateShortAnswer(qText, correctAns, currentAnswer),
                ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  if (isLast) {
                    // Show final report / score
                    setState(() {
                      _isPlaying = false;
                      _evaluationResult = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quiz completed! Practice makes perfect. 💪')),
                    );
                  } else {
                    setState(() {
                      _currentQuestionIndex++;
                      _evaluationResult = null;
                    });
                  }
                },
                child: Text(isLast ? 'Finish Quiz' : 'Next'),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuestionInput(String type, List options, String currentAnswer) {
    if (type == 'mcq' || type == 'true_false') {
      return Column(
        children: options.map((opt) {
          final isSelected = currentAnswer == opt;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200),
            ),
            child: RadioListTile<String>(
              title: Text(opt.toString(), style: GoogleFonts.poppins(fontSize: 13)),
              value: opt.toString(),
              activeColor: AppColors.primary,
              groupValue: currentAnswer.isEmpty ? null : currentAnswer,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _userAnswers[_currentQuestionIndex] = val;
                  });
                }
              },
            ),
          );
        }).toList(),
      );
    }

    // Written / Short Answer inputs
    final controller = TextEditingController(text: currentAnswer);
    return Column(
      children: [
        TextField(
          controller: controller,
          maxLines: type == 'long_answer' ? 6 : 2,
          decoration: InputDecoration(
            hintText: type == 'fill_in_the_blank' ? 'Type the blank answer' : 'Write your detailed answer here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) {
            _userAnswers[_currentQuestionIndex] = val;
          },
        ),
      ],
    );
  }
}
