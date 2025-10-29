import 'package:flutter/material.dart';
// For production, consider using `package:url_launcher/url_launcher.dart`.
import '../../utils/launcher.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class RestaurantInfoScreen extends StatelessWidget {
  const RestaurantInfoScreen({Key? key}) : super(key: key);

  // Contact details (as requested)
  final String phone = '+39 041 554 1174';
  final String whatsapp = '+39 392 768 6418';
  final String address = 'Viale Trieste 31, Sottomarina, Venice';
  final String facebook = 'https://www.facebook.com/ilgabbiano2Sottomarina';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('contact_info_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.store, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  Text('Il Gabbiano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 6),
                                  Text(AppLocalizations.of(context).t('restaurant_info'), style: TextStyle(color: Colors.black54)),
                                ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Divider(),

                    const SizedBox(height: 8),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone, color: Colors.green),
                      title: Text(AppLocalizations.of(context).t('phone_label')),
                      subtitle: Text('+39 041 554 1174'),
                      trailing: IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () => _launchUrl('tel:+390415541174'),
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.message, color: Colors.teal),
                      title: Text(AppLocalizations.of(context).t('whatsapp_label')),
                      subtitle: const Text('+39 392 768 6418'),
                      trailing: IconButton(
                        icon: const Icon(Icons.send, color: Colors.teal),
                        onPressed: () => _launchUrl('https://wa.me/393927686418'),
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on, color: Colors.redAccent),
                      title: Text(AppLocalizations.of(context).t('location_label')),
                      subtitle: Text(address),
                      trailing: IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _launchUrl('https://www.google.com/maps/search/${Uri.encodeComponent(address)}'),
                      ),
                    ),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.facebook, color: Colors.blue),
                      title: Text(AppLocalizations.of(context).t('facebook_label')),
                      subtitle: Text('Il gabbiano2'),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _launchUrl(facebook),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(AppLocalizations.of(context).t('opening_hours'), style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text(AppLocalizations.of(context).t('opening_hours_text')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Center(
              child: Text(AppLocalizations.of(context).t('visit_us'), style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
