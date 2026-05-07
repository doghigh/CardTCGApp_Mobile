import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService _instance = OcrService._();
  OcrService._();
  factory OcrService() => _instance;

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, String>> extractCardInfo(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    return _parse(recognized.text);
  }

  Map<String, String> _parse(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String name = '';
    String cardNumber = '';
    String setName = '';

    // Card number: 025/165, SV01, SWSH123, XY-123, etc.
    final numRe = RegExp(r'\b(\d{1,3}/\d{2,3}|[A-Z]{2,5}[-\s]?\d{1,4})\b');

    // Set name indicators (common TCG set keywords)
    final setIndicators = RegExp(
      r'\b(base set|jungle|fossil|team rocket|gym|neo|e-series|ex |delta|diamond|pearl|'
      r'heartgold|soulsilver|black|white|xy|sun|moon|sword|shield|scarlet|violet|'
      r'paldea|obsidian|temporal|paradox|twilight|shrouded|stellar|surging|'
      r'core set|ravnica|innistrad|zendikar|strixhaven|dominaria|kamigawa|'
      r'original|unlimited|limited|revised|fourth|fifth|classic)\b',
      caseSensitive: false,
    );

    // Junk line patterns: pure numbers/symbols, HP values, energy symbols
    final junkRe = RegExp(
      r'^[\d/\\+\-]+$|^(HP|GX|EX|V|VMAX|VSTAR|VUNION|TAG TEAM|δ|◇|★)$|'
      r'^\d+\s*(HP|%)|^[©®™]',
      caseSensitive: false,
    );

    for (final line in lines) {
      final m = numRe.firstMatch(line);
      if (m != null && cardNumber.isEmpty) {
        cardNumber = m.group(0)!;
      }
    }

    // Name: first substantive line that isn't a number, set, or junk
    for (final line in lines) {
      if (line.length < 3) continue;
      if (junkRe.hasMatch(line)) continue;
      if (numRe.hasMatch(line)) continue;
      if (line.contains('@') || line.contains('http')) continue;
      // Skip lines that look like copyright or legal text
      if (line.length > 60) continue;
      if (name.isEmpty) {
        name = _cleanName(line);
        continue;
      }
      // Set name: look for known set keywords after we have a name
      if (setName.isEmpty && setIndicators.hasMatch(line)) {
        setName = _cleanName(line);
      }
    }

    return {
      'name': name,
      'card_number': cardNumber,
      'set_name': setName,
    };
  }

  String _cleanName(String raw) {
    // Remove trailing punctuation, stray symbols, and normalize whitespace
    return raw
        .replaceAll(RegExp('[^\\w\\s\\-\\\'\\.\\u00e9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() => _recognizer.close();
}
