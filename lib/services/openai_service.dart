import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class OpenAIService {
  // ---------------------------------------------------------------------------
  // Core chat completion – drop-in replacement for the old OpenAI HTTP call.
  //
  // Returns a Map that mirrors the OpenAI response shape so every call-site
  // (e.g. exam_manager_screen.dart) that reads
  //   response['choices'][0]['message']['content']
  // continues to work unchanged.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> callChatCompletion({
    required String apiKey,
    required List<Map<String, String>> messages,
    bool responseJson = false,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API Key is empty. Please set it in Settings.');
    }

    try {
      // Build the Gemini model with the same low-temperature behaviour.
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          responseMimeType: responseJson ? 'application/json' : null,
        ),
      );

      // Translate the OpenAI-style messages list into Gemini Content objects.
      // 'system' messages become a systemInstruction; everything else maps to
      // 'user' / 'model' roles.
      Content? systemInstruction;
      final List<Content> history = [];

      for (final msg in messages) {
        final role = msg['role'] ?? 'user';
        final text = msg['content'] ?? '';

        if (role == 'system') {
          // Accumulate system text – Gemini accepts a single system instruction.
          if (systemInstruction == null) {
            systemInstruction = Content.system(text);
          } else {
            // Merge additional system messages into the existing one.
            systemInstruction = Content.system(
              '${systemInstruction.parts.map((p) => p is TextPart ? p.text : '').join('\n')}\n$text',
            );
          }
        } else if (role == 'assistant') {
          history.add(Content.model([TextPart(text)]));
        } else {
          // 'user' or anything else → user turn
          history.add(Content('user', [TextPart(text)]));
        }
      }

      // The last user message is sent as the new prompt.
      final lastContent = history.isNotEmpty
          ? history.last
          : Content('user', [TextPart('')]);

      final lastText = lastContent.parts
          .whereType<TextPart>()
          .map((p) => p.text)
          .join('\n');

      // If there's a system instruction, create a new model with it.
      final modelWithSystem = systemInstruction != null
          ? GenerativeModel(
              model: 'gemini-2.5-flash',
              apiKey: apiKey,
              systemInstruction: systemInstruction,
              generationConfig: GenerationConfig(
                temperature: 0.3,
                responseMimeType: responseJson ? 'application/json' : null,
              ),
            )
          : model;

      final chatWithSystem = modelWithSystem.startChat(
        history: history.length > 1 ? history.sublist(0, history.length - 1) : [],
      );

      final geminiResponse = await chatWithSystem.sendMessage(
        Content('user', [TextPart(lastText)]),
      );

      final responseText = geminiResponse.text ?? '';

      // Return in the same OpenAI-compatible shape so all call-sites keep
      // working (e.g. response['choices'][0]['message']['content']).
      return {
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': responseText,
            },
          },
        ],
      };
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to connect to Gemini: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helper: strip markdown code fences (```json … ```) that Gemini may wrap
  // around JSON output and then decode.
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _cleanAndDecodeJson(String raw) {
    String cleaned = raw.trim();

    // Remove leading ```json or ``` and trailing ```
    final fencePattern = RegExp(r'^```(?:json)?\s*\n?', caseSensitive: false);
    if (fencePattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(fencePattern, '');
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trimRight();
    }

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // 1. AI TIMETABLE GENERATION
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> generateTimetable({
    required String apiKey,
    required List<Map<String, String>> exams, // List of {subject, date, difficulty}
    required double dailyHours,
    required List<String> subjectsList,
  }) async {
    final systemPrompt = 
        "You are an academic planner. Create a daily/weekly study timetable in JSON format.\n"
        "Input: Available hours: $dailyHours hours per day.\n"
        "Subjects: ${subjectsList.join(', ')}.\n"
        "Upcoming Exams: ${jsonEncode(exams)}.\n"
        "Constraints:\n"
        "1. Prioritize subjects with upcoming exams and higher difficulty.\n"
        "2. Balance workload (max hours per subject per day is 2.5 hours).\n"
        "3. Include study breaks (e.g. 50 mins focus, 10 mins break).\n"
        "4. Include review/revision sessions closer to the exam dates.\n"
        "Output MUST be JSON matching this schema:\n"
        "{\n"
        "  \"weeklySchedule\": {\n"
        "    \"Monday\": [{\"subject\": \"Math\", \"timeSlot\": \"09:00 AM - 11:30 AM\", \"durationHours\": 2.5, \"focusArea\": \"Chapter 3 Revision\"}],\n"
        "    \"Tuesday\": [...]\n"
        "  },\n"
        "  \"dailyTips\": [\"Tip 1\", \"Tip 2\"]\n"
        "}";

    final response = await callChatCompletion(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Generate my personalized study timetable.'}
      ],
      responseJson: true,
    );

    final String text = response['choices'][0]['message']['content'];
    return _cleanAndDecodeJson(text);
  }

  // ---------------------------------------------------------------------------
  // 2. AI STUDY ASSISTANT (Summary, Notes, Definitions, Flashcards, Formula Sheet)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> processStudyMaterial({
    required String apiKey,
    required String title,
    required String rawText,
  }) async {
    final systemPrompt = 
        "You are an AI Study Assistant. Extract key details from this study material and structure them as a JSON object.\n"
        "Text content:\n$rawText\n\n"
        "Format the output strictly as JSON with the following keys:\n"
        "{\n"
        "  \"summary\": \"A concise 3-4 sentence summary of the material.\",\n"
        "  \"importantPoints\": [\"Point 1\", \"Point 2\", ...],\n"
        "  \"shortNotes\": \"Detailed organized bullet-point notes of the content.\",\n"
        "  \"flashCards\": [{\"front\": \"Question/Concept\", \"back\": \"Answer/Explanation\"}, ...],\n"
        "  \"keyDefinitions\": {\"term1\": \"definition1\", \"term2\": \"definition2\", ...},\n"
        "  \"formulaSheet\": \"Markdown list of formulas/laws if applicable, otherwise 'No formulas found in this material.'\"\n"
        "}";

    final response = await callChatCompletion(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Analyze this study material.'}
      ],
      responseJson: true,
    );

    final String text = response['choices'][0]['message']['content'];
    return _cleanAndDecodeJson(text);
  }

  // ---------------------------------------------------------------------------
  // 3. AI QUIZ GENERATION
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> generateQuiz({
    required String apiKey,
    required String title,
    required String materialText,
    required String difficulty, // 'easy', 'medium', 'hard'
  }) async {
    final systemPrompt = 
        "You are an AI Quiz Generator. Based on the study material provided below, generate a comprehensive quiz. difficulty: $difficulty.\n"
        "Material:\n$materialText\n\n"
        "Generate 10 questions in total, covering multiple types: Multiple Choice (MCQ), Fill in the blanks, True/False, Short Answer, and Long Answer.\n"
        "Output strictly as a JSON object matching this schema:\n"
        "{\n"
        "  \"quizTitle\": \"Quiz name\",\n"
        "  \"questions\": [\n"
        "    {\n"
        "      \"id\": \"1\",\n"
        "      \"type\": \"mcq\",\n"
        "      \"question\": \"Question text\",\n"
        "      \"options\": [\"Option A\", \"Option B\", \"Option C\", \"Option D\"],\n"
        "      \"correctAnswer\": \"Option A\",\n"
        "      \"explanation\": \"Explanation of correct answer\"\n"
        "    },\n"
        "    {\n"
        "      \"id\": \"2\",\n"
        "      \"type\": \"true_false\",\n"
        "      \"question\": \"Statement text\",\n"
        "      \"options\": [\"True\", \"False\"],\n"
        "      \"correctAnswer\": \"True\",\n"
        "      \"explanation\": \"Explanation\"\n"
        "    },\n"
        "    {\n"
        "      \"id\": \"3\",\n"
        "      \"type\": \"fill_in_the_blank\",\n"
        "      \"question\": \"The capital of ___ is Paris.\",\n"
        "      \"correctAnswer\": \"France\",\n"
        "      \"explanation\": \"Explanation\"\n"
        "    },\n"
        "    {\n"
        "      \"id\": \"4\",\n"
        "      \"type\": \"short_answer\",\n"
        "      \"question\": \"Explain X in brief.\",\n"
        "      \"correctAnswer\": \"Expected core keywords or model answer\",\n"
        "      \"explanation\": \"Sample answer grading criteria\"\n"
        "    },\n"
        "    {\n"
        "      \"id\": \"5\",\n"
        "      \"type\": \"long_answer\",\n"
        "      \"question\": \"Describe X in detail.\",\n"
        "      \"correctAnswer\": \"Comprehensive model answer details\",\n"
        "      \"explanation\": \"Key concepts to grade\"\n"
        "    }\n"
        "  ]\n"
        "}";

    final response = await callChatCompletion(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Generate the quiz.'}
      ],
      responseJson: true,
    );

    final String text = response['choices'][0]['message']['content'];
    return _cleanAndDecodeJson(text);
  }

  // ---------------------------------------------------------------------------
  // 4. AI ANSWER EVALUATION
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> evaluateAnswer({
    required String apiKey,
    required String question,
    required String modelAnswer,
    required String userAnswer,
  }) async {
    final systemPrompt = 
        "You are an academic evaluator. Evaluate the student's answer against the question and the model answer.\n"
        "Question: $question\n"
        "Model Answer: $modelAnswer\n"
        "Student Answer: $userAnswer\n\n"
        "Assess accuracy, completeness, and highlight any missing concepts. Assign a score out of 10.\n"
        "Output strictly as a JSON object matching this schema:\n"
        "{\n"
        "  \"score\": 8.5,\n"
        "  \"feedback\": \"Feedback explaining the score.\",\n"
        "  \"modelAnswer\": \"Standard model answer display\",\n"
        "  \"missingConcepts\": [\"Concept A\", \"Concept B\"],\n"
        "  \"suggestions\": \"Suggestions to improve the answer\"\n"
        "}";

    final response = await callChatCompletion(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': 'Evaluate this answer.'}
      ],
      responseJson: true,
    );

    final String text = response['choices'][0]['message']['content'];
    return _cleanAndDecodeJson(text);
  }
}
