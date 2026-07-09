import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;

/// Extracts plain text from uploaded study material files so the OpenAI
/// prompts (timetable/study-assistant/quiz) are built from the student's
/// actual content instead of a placeholder string.
class FileTextExtractor {
  /// Max characters kept per document. Keeps prompt size (and OpenAI cost)
  /// bounded even for large PDFs/DOCX. ~18,000 chars is roughly 4-5k tokens.
  static const int maxChars = 18000;

  /// Extracts text from any supported extension ('pdf', 'docx', 'txt').
  /// Throws an [Exception] with a user-friendly message on failure.
  static String extractText({
    required Uint8List bytes,
    required String extension,
  }) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    String text;
    switch (ext) {
      case 'pdf':
        text = _extractFromPdf(bytes);
        break;
      case 'docx':
        text = _extractFromDocx(bytes);
        break;
      case 'txt':
        text = utf8.decode(bytes, allowMalformed: true);
        break;
      default:
        throw Exception('Unsupported file type: .$ext');
    }

    text = text.trim();
    if (text.isEmpty) {
      throw Exception(
        'No readable text found in this file. It may be a scanned/image-only '
        'PDF, which is not supported yet — try pasting the text manually.',
      );
    }

    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n\n[...content truncated for length...]';
    }
    return text;
  }

  static String _extractFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    try {
      final String text = PdfTextExtractor(document).extractText();
      return text;
    } finally {
      document.dispose();
    }
  }

  static String _extractFromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('Invalid DOCX file (document.xml not found).'),
    );

    final content = documentFile.content as List<int>;
    final xmlString = utf8.decode(content);
    final document = xml.XmlDocument.parse(xmlString);

    final buffer = StringBuffer();
    // Word stores text inside <w:p> paragraphs, each containing <w:t> runs.
    for (final paragraph in document.findAllElements('w:p')) {
      for (final run in paragraph.findAllElements('w:t')) {
        buffer.write(run.innerText);
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
