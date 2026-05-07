import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._();
  OcrService._();
  factory OcrService() => _instance;

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, String>> extractCardInfo(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    final text = recognized.text;
    return _parse(text);
  }

  Map<String, String> _parse(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String name = '';
    String cardNumber = '';

    // Card number: patterns like 025/165, SV01, SWSH123
    final numRe = RegExp(r'\b(\d{1,3}/\d{2,3}|[A-Z]{2,4}\d{1,4})\b');
    for (final line in lines) {
      final m = numRe.firstMatch(line);
      if (m != null) {
        cardNumber = m.group(0)!;
        break;
      }
    }

    // Name: first reasonably long line that isn't a number/set/symbol line
    final junkRe = RegExp(r'^[\d/\\HP]+$|^(HP|GX|EX|V|VMAX|VSTAR)$', caseSensitive: false);
    for (final line in lines) {
      if (line.length >= 3 && !junkRe.hasMatch(line) && !numRe.hasMatch(line)) {
        name = line;
        break;
      }
    }

    return {'name': name, 'card_number': cardNumber};
  }

  void dispose() => _recognizer.close();
}
