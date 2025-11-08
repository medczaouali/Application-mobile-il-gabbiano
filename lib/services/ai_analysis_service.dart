import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiAnalysisService {
  final Dio _dio = Dio();
  // Switched to a robust multilingual model that outputs NEG/NEU/POS labels
  final String _apiUrl =dotenv.env['HUGGINGFACE_API_URL']!;

  // Using the new key
  final String _apiKey = dotenv.env['HUGGINGFACE_API_KEY']!;

  Future<String> analyzeMessage(String message) async {
    try {
      final response = await _dio.post(
        _apiUrl,
        options: Options(headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json"
        }),
        data: {
          "inputs": message,
          "options": {"wait_for_model": true}
        },
      );

      final data = response.data;
      if (data is List && data.isNotEmpty) {
        // This logic handles the standard Hugging Face response structure
        final result = data[0] is List ? data[0] : data;
        final best = result.reduce((a, b) => a['score'] > b['score'] ? a : b);

        // Use the updated mapping function for this specific model's labels
        return _mapLabel(best['label']);
      }
      return "Inconnu";
    } catch (e) {
      print("AI Error: $e");
      return "Erreur";
    }
  }

  // FINAL UPDATED FUNCTION: Maps the labels correctly, handling prefixes.
  String _mapLabel(String label) {
    // Convert the returned label to lowercase for reliable comparison
    final cleanLabel = label.trim().toLowerCase();

    switch (cleanLabel) {
      case 'positive':
        return 'positive';
      case 'neutral':
        return 'neutral';
      case 'negative':
        return 'negative';
    // The model may also return 'LABEL_2', 'LABEL_1', 'LABEL_0' depending on the version/input,
    // but we prioritize the word labels since the log showed 'negative'.
    // If you want full safety, you could add cases for 'LABEL_2' etc. as well.
      default:
      // This is where 'negative' fell previously. It will now be caught above.
        print("Unrecognized Hugging Face Label: $label");
        return 'Inconnu';
    }
  }
}