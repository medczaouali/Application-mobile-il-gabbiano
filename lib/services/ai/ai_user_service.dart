import 'dart:ui';

class AIUserService {
  /// Pick a supported locale based on device or googleLocale.
  /// Supported: en, fr, it, es, de, pt, ar
  Locale suggestSupportedLocale({Locale? device, String? googleLocale}) {
    const supported = ['en', 'fr', 'it', 'es', 'de', 'pt', 'ar'];
    String? code;

    if (googleLocale != null && googleLocale.isNotEmpty) {
      code = googleLocale.split('_').first.toLowerCase();
      if (!supported.contains(code)) code = null;
    }

    code ??= (device?.languageCode ?? 'en');
    if (!supported.contains(code)) code = 'en';

    return Locale(code);
  }
}
