import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  // Helper method to make requests to OpenAI Chat Completion
  Future<Map<String, dynamic>> callChatCompletion({
    required String apiKey,
    required List<Map<String, String>> messages,
    bool responseJson = false,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('OpenAI API Key is empty. Please set it in Settings.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = {
      'model': 'gpt-4o-mini',
      'messages': messages,
      'temperature': 0.3,
    };

    if (responseJson) {
      body['response_format'] = {'type': 'json_object'};
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded;
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        final errMsg = err['error']?['message'] ?? 'Status code: ${response.statusCode}';
        throw Exception(errMsg);
      }
    } catch (e) {
      throw Exception('Failed to connect to OpenAI: $e');
    }
  }

  // 1. AI TIMETABLE GENERATION
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
    return jsonDecode(text);
  }

  // 2. AI STUDY ASSISTANT (Summary, Notes, Definitions, Flashcards, Formula Sheet)
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
    return jsonDecode(text);
  }

  // 3. AI QUIZ GENERATION
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
    return jsonDecode(text);
  }

  // 4. AI ANSWER EVALUATION
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
    return jsonDecode(text);
  }
}
