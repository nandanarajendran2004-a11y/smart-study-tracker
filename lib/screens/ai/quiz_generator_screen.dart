import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../services/openai_service.dart';
import '../../services/firestore_service.dart';
import '../../services/file_text_extractor.dart';
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
  
  // File upload states
  String _uploadStatus = '';
  String _uploadedRawText = '';
  String _uploadedTitle = '';
  
  List<Map<String, dynamic>> _quizzesList = [];
  List<Map<String, dynamic>> _materialsList = [];
  Map<String, dynamic>? _selectedMaterial;
  Map<String, dynamic>? _activeQuiz;
  
  // Interactive player states
  int _currentQuestionIndex = 0;
  final Map<int, String> _userAnswers = {};
  // Track which questions have been "submitted" (answer locked in)
  final Set<int> _answeredQuestions = {};
  
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
        _materialsList = materials;
        if (_materialsList.isNotEmpty && _selectedMaterial == null) {
          _selectedMaterial = _materialsList.first;
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz resources: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _uploadStatus = 'Reading: ${file.name}...';
        });

        // Read file bytes: on web use file.bytes, on mobile/desktop read from path
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }
        if (bytes == null) {
          throw Exception('Could not read file. Please try again.');
        }

        // Extract text content
        final extractedText = FileTextExtractor.extractText(
          bytes: bytes,
          extension: file.extension ?? '',
        );

        final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

        setState(() {
          _uploadedRawText = extractedText;
          _uploadedTitle = title;
          _selectedMaterial = null; // Deselect dropdown — use uploaded file instead
          _uploadStatus = 'Ready: ${file.name} ✓';
        });
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Failed: $e';
      });
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

    // Determine the material source: uploaded file or selected from dropdown
    String materialTitle;
    String materialText;

    if (_uploadedRawText.isNotEmpty) {
      materialTitle = _uploadedTitle.isNotEmpty ? _uploadedTitle : 'Uploaded material';
      materialText = _uploadedRawText;
    } else if (_selectedMaterial != null) {
      materialTitle = _selectedMaterial!['title'] ?? 'Study material';
      materialText = _selectedMaterial!['rawText'] ?? '';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a file or select a study material first.')),
      );
      return;
    }

    if (materialText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The selected material has no text content. Please try another.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final quizResult = await _openaiService.generateQuiz(
        apiKey: apiKey,
        title: materialTitle,
        materialText: materialText,
        difficulty: _difficulty,
      );

      final quizData = {
        'id': 'quiz_${DateTime.now().millisecondsSinceEpoch}',
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
        _answeredQuestions.clear();
        _evaluationResult = null;
        // Clear uploaded file state after successful generation
        _uploadedRawText = '';
        _uploadedTitle = '';
        _uploadStatus = '';
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
                  setState(() {
                    _selectedMaterial = val;
                    // Clear uploaded file when selecting from dropdown
                    _uploadedRawText = '';
                    _uploadedTitle = '';
                    _uploadStatus = '';
                  });
                },
                items: _materialsList.isEmpty
                    ? []
                    : _materialsList.map((m) => DropdownMenuItem<Map<String, dynamic>>(
                          value: m,
                          child: Text(m['title'] ?? 'Material', style: GoogleFonts.poppins(fontSize: 13)),
                        )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // OR divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 16),

          // File upload button
          InkWell(
            onTap: _pickAndUploadFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _uploadedRawText.isNotEmpty
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _uploadedRawText.isNotEmpty
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _uploadedRawText.isNotEmpty ? Icons.check_circle : Icons.cloud_upload_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _uploadedRawText.isNotEmpty
                        ? 'File loaded: $_uploadedTitle'
                        : 'Upload Study File (PDF, DOCX, TXT)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_uploadStatus.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _uploadStatus,
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
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
                        _answeredQuestions.clear();
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
    final bool isAnswered = _answeredQuestions.contains(_currentQuestionIndex);

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionInput(type, options, currentAnswer, correctAns, isAnswered),

                  // Show correct answer and explanation after answering
                  if (isAnswered && (type == 'mcq' || type == 'true_false' || type == 'fill_in_the_blank')) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: currentAnswer == correctAns
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentAnswer == correctAns
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                currentAnswer == correctAns
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: currentAnswer == correctAns
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentAnswer == correctAns
                                      ? 'Correct! ✨'
                                      : 'Incorrect',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: currentAnswer == correctAns
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (currentAnswer != correctAns) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Correct Answer: $correctAns',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                          if (explanation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Explanation: $explanation',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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

              // Submit Answer Button (for MCQ, true/false, fill_in_the_blank)
              if (!isAnswered && (type == 'mcq' || type == 'true_false' || type == 'fill_in_the_blank') && currentAnswer.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Submit Answer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      _answeredQuestions.add(_currentQuestionIndex);
                    });
                  },
                ),

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

  Widget _buildQuestionInput(String type, List options, String currentAnswer, String correctAnswer, bool isAnswered) {
    if (type == 'mcq' || type == 'true_false') {
      return Column(
        children: options.map((opt) {
          final optStr = opt.toString();
          final isSelected = currentAnswer == optStr;
          final isCorrectOption = optStr == correctAnswer;

          // Determine colors based on answer state
          Color bgColor;
          Color borderColor;
          if (isAnswered) {
            if (isCorrectOption) {
              bgColor = Colors.green.shade50;
              borderColor = Colors.green;
            } else if (isSelected && !isCorrectOption) {
              bgColor = Colors.red.shade50;
              borderColor = Colors.red;
            } else {
              bgColor = Colors.white;
              borderColor = Colors.grey.shade200;
            }
          } else {
            bgColor = isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white;
            borderColor = isSelected ? AppColors.primary : Colors.grey.shade200;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isAnswered && (isCorrectOption || (isSelected && !isCorrectOption)) ? 2 : 1),
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Expanded(child: Text(optStr, style: GoogleFonts.poppins(fontSize: 13))),
                  if (isAnswered && isCorrectOption)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  if (isAnswered && isSelected && !isCorrectOption)
                    const Icon(Icons.cancel, color: Colors.red, size: 20),
                ],
              ),
              value: optStr,
              activeColor: isAnswered
                  ? (isCorrectOption ? Colors.green : Colors.red)
                  : AppColors.primary,
              groupValue: currentAnswer.isEmpty ? null : currentAnswer,
              onChanged: isAnswered
                  ? null
                  : (val) {
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
          readOnly: isAnswered && type == 'fill_in_the_blank',
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
