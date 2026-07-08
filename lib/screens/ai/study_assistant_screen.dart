import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../services/openai_service.dart';
import '../../services/firestore_service.dart';

class StudyAssistantScreen extends StatefulWidget {
  const StudyAssistantScreen({super.key});

  @override
  State<StudyAssistantScreen> createState() => _StudyAssistantScreenState();
}

class _StudyAssistantScreenState extends State<StudyAssistantScreen> with SingleTickerProviderStateMixin {
  final _openaiService = OpenAIService();
  final _firestoreService = FirestoreService();

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  String _uploadStatus = '';
  String? _uploadedFileUrl;
  
  TabController? _tabController;
  List<Map<String, dynamic>> _materialHistory = [];
  Map<String, dynamic>? _activeMaterial;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.user?.uid;
    if (uid == null) return;

    _firestoreService.getStudyMaterialsStream(uid).first.then((data) {
      setState(() {
        _materialHistory = data;
        if (data.isNotEmpty) {
          _activeMaterial = data.first;
        }
      });
    });
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _uploadStatus = 'Uploading: ${file.name}...';
        });

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final uid = auth.user?.uid;
        if (uid == null) return;

        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception("Could not read file bytes");
        }

        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('study_materials')
            .child('$uid-${DateTime.now().millisecondsSinceEpoch}-${file.name}');

        final uploadTask = ref.putData(bytes);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _uploadedFileUrl = downloadUrl;
          _uploadStatus = 'Successfully uploaded: ${file.name}! ✓';
          if (_titleController.text.isEmpty) {
            _titleController.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
        });

        // If it is a TXT file, we can read its contents to the text area
        if (file.extension == 'txt') {
          final content = utf8.decode(bytes);
          setState(() {
            _notesController.text = content;
          });
        } else {
          setState(() {
            _notesController.text = "[File uploaded: ${file.name}. AI will analyze this file's context.]";
          });
        }
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Failed to upload file: $e';
      });
    }
  }

  void _generateAnalysis() async {
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

    if (_titleController.text.isEmpty || _notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and paste or upload study notes.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final analysis = await _openaiService.processStudyMaterial(
        apiKey: apiKey,
        title: _titleController.text.trim(),
        rawText: _notesController.text,
      );

      final materialData = {
        'id': UniqueKey().hashCode.toString(),
        'title': _titleController.text.trim(),
        'rawText': _notesController.text,
        'fileUrl': _uploadedFileUrl ?? '',
        'summary': analysis['summary'] ?? '',
        'importantPoints': analysis['importantPoints'] ?? [],
        'shortNotes': analysis['shortNotes'] ?? '',
        'flashCards': analysis['flashCards'] ?? [],
        'keyDefinitions': analysis['keyDefinitions'] ?? {},
        'formulaSheet': analysis['formulaSheet'] ?? 'No formulas found.',
      };

      // Save to Firestore
      await _firestoreService.saveStudyMaterial(uid, materialData);

      setState(() {
        _activeMaterial = materialData;
        _notesController.clear();
        _titleController.clear();
        _uploadedFileUrl = null;
        _uploadStatus = '';
      });

      _loadHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Study Material Sheets generated! 📚🤖'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
          'AI Study Assistant',
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
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI Study assistant is reading your files... 📚🤖', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              )
            : Column(
                children: [
                  // Upper tabs (Create vs View History)
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'New Material'),
                        Tab(text: 'Notes & summary'),
                        Tab(text: 'Flashcards'),
                        Tab(text: 'Study Hub Sheets'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: NEW MATERIAL
                        _buildNewMaterialTab(hasApiKey),

                        // TAB 2: SUMMARY & NOTES
                        _buildSummaryTab(),

                        // TAB 3: FLASHCARDS
                        _buildFlashcardsTab(),

                        // TAB 4: STUDY HUB SHEETS & HISTORY
                        _buildHistoryTab(),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Widget _buildNewMaterialTab(bool hasApiKey) {
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
                '⚠️ OpenAI API Key is missing. Please configure it in your Settings to analyze materials.',
                style: GoogleFonts.poppins(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Upload Notes or Materials',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Material Title',
              prefixIcon: const Icon(Icons.bookmark_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // File picker button
          InkWell(
            onTap: _pickAndUploadFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Pick Study File (PDF, DOCX, TXT)',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                  if (_uploadStatus.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _uploadStatus,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _notesController,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Paste raw study notes / text here',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: Text('Generate AI Study Sheets', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _generateAnalysis,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_activeMaterial == null) {
      return const Center(child: Text('No active study material selected. Create or select one in the History tab.'));
    }

    final summary = _activeMaterial!['summary'] ?? '';
    final List points = _activeMaterial!['importantPoints'] ?? [];
    final notes = _activeMaterial!['shortNotes'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _activeMaterial!['title'] ?? 'Summary',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 14),
          _buildAnalysisSection(
            title: 'AI Summary',
            child: Text(summary, style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: Colors.grey.shade800)),
          ),
          const SizedBox(height: 16),
          _buildAnalysisSection(
            title: 'Important Points',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: points.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(p.toString(), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade800))),
                      ],
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalysisSection(
            title: 'Detailed Notes',
            child: Text(notes, style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardsTab() {
    if (_activeMaterial == null) {
      return const Center(child: Text('No study cards available.'));
    }

    final List cards = _activeMaterial!['flashCards'] ?? [];

    if (cards.isEmpty) {
      return const Center(child: Text('No flashcards found for this material.'));
    }

    return PageView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _FlashcardWidget(
          front: card['front'] ?? '',
          back: card['back'] ?? '',
          cardNumber: '${index + 1} / ${cards.length}',
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_activeMaterial == null) {
      return const Center(child: Text('No materials saved.'));
    }

    final Map definitions = _activeMaterial!['keyDefinitions'] ?? {};
    final formula = _activeMaterial!['formulaSheet'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Definitions
          if (definitions.isNotEmpty) ...[
            _buildAnalysisSection(
              title: 'Key Definitions',
              child: Column(
                children: definitions.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key}: ', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          Expanded(child: Text(e.value.toString(), style: GoogleFonts.poppins(fontSize: 12))),
                        ],
                      ),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Formula Sheet
          _buildAnalysisSection(
            title: 'Formula & Law Sheet',
            child: Text(formula, style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: Colors.grey.shade800)),
          ),
          const SizedBox(height: 24),

          // History List
          Text('Select from History', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ..._materialHistory.map((m) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(m['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Created: ${m['rawText'] != null ? "AI Sheet ready" : ""}', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    setState(() {
                      _activeMaterial = m;
                    });
                    _tabController?.animateTo(1); // Jump to Summary
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── FLASHCARD INTERACTIVE COMPONENT ─────────────────────────
class _FlashcardWidget extends StatefulWidget {
  final String front, back, cardNumber;
  const _FlashcardWidget({required this.front, required this.back, required this.cardNumber});

  @override
  State<_FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<_FlashcardWidget> {
  bool _showFront = true;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: InkWell(
          onTap: () => setState(() => _showFront = !_showFront),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(28),
            width: double.infinity,
            height: 380,
            decoration: BoxDecoration(
              gradient: _showFront
                  ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)])
                  : const LinearGradient(colors: [Color(0xFF009688), Color(0xFF4CAF50)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_showFront ? AppColors.primary : Colors.green).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.cardNumber,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _showFront ? widget.front : widget.back,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Text(
                  _showFront ? 'Tap to Flip to Answer 🔄' : 'Tap to Flip to Question 🔄',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
