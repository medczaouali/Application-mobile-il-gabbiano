import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  LatLng? _picked;
  String? _addressLabel;
  bool _isReverseLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _picked = widget.initialLocation;
    if (_picked != null) _reverseGeocode(_picked!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_picked != null) {
        try {
          _mapController.move(_picked!, 13);
        } catch (e) {
          // ignore if map controller API differs
        }
      }
    });
  }

  Future<void> _reverseGeocode(LatLng latlng) async {
    setState(() => _isReverseLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latlng.latitude}&lon=${latlng.longitude}');
      final res = await http.get(url, headers: {'User-Agent': 'ilgabbiano-app'});
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _addressLabel = json['display_name'] as String?;
        });
      }
    } catch (e) {
      // ignore network errors
    } finally {
      setState(() => _isReverseLoading = false);
    }
  }

  void _onTapTap(LatLng latlng) {
    setState(() {
      _picked = latlng;
      _addressLabel = null;
    });
    _reverseGeocode(latlng);
  }

  Future<void> _useMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('location_services_disabled'))));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission de localisation refusée')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Offer to open app settings so the user can enable location permission
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).t('permission_denied_forever_title')),
          content: Text(AppLocalizations.of(context).t('permission_denied_forever_message')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('open_settings'))),
          ],
        ),
      );
      if (open == true) {
        await Geolocator.openAppSettings();
      }
      return;
    }

    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 10));
      } catch (_) {
        // Fallback to last known position if current position times out or fails
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('get_position_failed'))));
        return;
      }

      final latlng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(latlng, 16);
      setState(() {
        _picked = latlng;
      });
      _reverseGeocode(latlng);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('get_position_failed') + ' : $e')));
    }
  }

  void _choose() {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucun emplacement sélectionné')));
      return;
    }
    Navigator.of(context).pop({'lat': _picked!.latitude, 'lng': _picked!.longitude, 'address': _addressLabel});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Choisir l\'emplacement')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onTap: (tapPos, latlng) => _onTapTap(latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: _picked!,
                        child: Icon(Icons.location_on, color: Colors.red, size: 40),
                      )
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isReverseLoading) LinearProgressIndicator(),
                      if (_addressLabel != null) Text(_addressLabel!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (_addressLabel == null) Text(_picked != null ? '${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}' : 'Aucun emplacement'),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  children: [
                    ElevatedButton(onPressed: _choose, child: Text('Choisir')),
                    SizedBox(height: 8),
                    ElevatedButton.icon(onPressed: _useMyLocation, icon: Icon(Icons.my_location), label: Text('Utiliser ma position')),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
