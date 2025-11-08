import 'package:dio/dio.dart';

class TextbeltSmsService {
  final Dio _dio = Dio(); // ✅ Create a Dio instance

  Future<void> sendSms({
    required String to,
    required String message,
  }) async {
    const String apiUrl = 'https://api.textbelt.com/text'; // ✅ safer endpoint
    const String apiKey = 'textbelt'; // free key, 1 SMS/day

    try {
      final response = await _dio.post(
        apiUrl,
        data: {
          'phone': to,
          'message': message,
          'key': apiKey,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent': 'Mozilla/5.0', // ✅ helps bypass Cloudflare
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          print('✅ SMS sent successfully to $to');
        } else {
          print('❌ Failed to send SMS: ${data['error']}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error sending SMS: $e');
    }
  }
}
