import 'package:url_launcher/url_launcher.dart' as ul;

Future<bool> canLaunchUrl(Uri uri) async {
  try {
    return await ul.canLaunchUrl(uri);
  } catch (_) {
    return false;
  }
}

class LaunchMode {
  static const externalApplication = ul.LaunchMode.externalApplication;
}

Future<void> launchUrl(Uri uri, {dynamic mode}) async {
  final useExternal = mode == LaunchMode.externalApplication || mode == ul.LaunchMode.externalApplication;
  final launchMode = useExternal ? ul.LaunchMode.externalApplication : ul.LaunchMode.platformDefault;
  await ul.launchUrl(uri, mode: launchMode);
}
