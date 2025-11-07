import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:ilgabbiano/screens/client/map_picker_screen.dart';
import 'package:ilgabbiano/screens/client/settings_screen.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';
import 'package:ilgabbiano/screens/client/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _sessionManager = SessionManager();
  User? _user;
  String? _profileImagePath;
  double? _pickedLat;
  double? _pickedLng;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final session = await _sessionManager.getUserSession();
    if (session != null) {
      final user = await _dbHelper.getUserById(session['id']);
      setState(() {
        _user = user;
        _nameController.text = _user!.name;
        _emailController.text = _user!.email;
        _phoneController.text = _user!.phone;
        _addressController.text = _user!.address;
        _profileImagePath = _user!.profileImage;
      });
    }
  }

  // Pick image from gallery or camera and persist a safe copy inside app documents
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (pickedFile != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filename = 'profile_${_user?.id ?? 'me'}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
          final savedPath = p.join(appDir.path, filename);

          // delete previous stored image if it was stored inside app documents
          if (_profileImagePath != null && _profileImagePath!.startsWith(appDir.path)) {
            try {
              final oldFile = File(_profileImagePath!);
              if (await oldFile.exists()) await oldFile.delete();
            } catch (_) {}
          }

          await File(pickedFile.path).copy(savedPath);
          setState(() { _profileImagePath = savedPath; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).t('photo_saved'))),
          );
        } catch (e) {
          // fallback: use original path if copy fails
          setState(() { _profileImagePath = pickedFile.path; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).t('image_copy_failed'))),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('pick_image_error'))),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context).t('gallery')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text(AppLocalizations.of(context).t('camera')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              if (_profileImagePath != null)
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: Text(
                    AppLocalizations.of(context).t('delete'),
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _profileImagePath = null);
                  },
                ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text(AppLocalizations.of(context).t('cancel')),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Edit mode removed: fields are editable by default; avatar tap opens picker.

  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      // AI moderation for display name when updating profile
      // no-op: placeholder for future cloud moderation
      // Lightweight inline moderation (avoid import cycle risk):
      final name = _nameController.text.trim();
      final _badWords = [
        'fuck','shit','bitch','asshole','bastard','pute','merde','connard','enculé','cazzo','stronzo','merda','mierda','gilipollas','scheiße','arschloch','porra','caralho'
      ];
      final lower = name.toLowerCase();
      bool block = _badWords.any((w) => lower.contains(w));
      if (block) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('name_inappropriate'))),
        );
        return;
      }
      await _dbHelper.updateUserProfile(
        _user!.id!,
        _nameController.text,
        _emailController.text,
        _phoneController.text,
        _addressController.text,
        _pickedLat,
        _pickedLng,
        _profileImagePath,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('profile_updated')),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('delete_account')),
        content: Text(AppLocalizations.of(context).t('delete_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppLocalizations.of(context).t('delete'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dbHelper.deleteUser(_user!.id!);
      await _sessionManager.clearSession();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('account_deleted')),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).t('profile'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _updateProfile)],
      ),
      body: _user == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Personal info card
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context).t('name_label'),
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  validator: (value) => value!.isEmpty
                                      ? AppLocalizations.of(context).t('enter_name')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context).t('email_label'),
                                    prefixIcon: Icon(Icons.email),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context).t('phone_label'),
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context).t('address_label'),
                                    prefixIcon: Icon(Icons.home),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.map),
                                      onPressed: () async {
                                        final res = await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => MapPickerScreen(
                                              initialLocation: _pickedLat != null && _pickedLng != null
                                                  ? LatLng(_pickedLat!, _pickedLng!)
                                                  : null,
                                            ),
                                          ),
                                        );
                                        if (res != null && res is Map) {
                                          setState(() {
                                            _pickedLat = (res['lat'] as num).toDouble();
                                            _pickedLng = (res['lng'] as num).toDouble();
                                            if (res['address'] != null) {
                                              _addressController.text = res['address'] as String;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Quick actions card (Change Password)
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: BrandPalette.profileGradient),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.lock_reset, color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context).t('change_password'),
                                        style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                                      );
                                    },
                                    child: Text(AppLocalizations.of(context).t('change_password')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Settings button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                                );
                              },
                              icon: const Icon(Icons.settings),
                              label: Text(AppLocalizations.of(context).t('settings')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: _deleteAccount,
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            label: Text(
                              AppLocalizations.of(context).t('delete_account'),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

extension on _ProfileScreenState {
  Widget _buildHeader(BuildContext context) {
    final name = _nameController.text.isNotEmpty ? _nameController.text : AppLocalizations.of(context).t('profile');
    final email = _emailController.text;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: BrandPalette.headerGradient),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async { _showImageSourceActionSheet(); },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: BrandPalette.ordersGradient),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null,
                      child: _profileImagePath == null ? const Icon(Icons.person, size: 40) : null,
                    ),
                  ),
                ),
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.camera_alt, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 4),
                Text(email, style: GoogleFonts.lato(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(),
        ],
      ),
    );
  }
}
