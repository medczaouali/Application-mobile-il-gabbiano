import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/widgets/custom_button.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:ilgabbiano/screens/client/map_picker_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _sessionManager = SessionManager();
  User? _user;
  String? _profileImagePath;
  double? _pickedLat;
  double? _pickedLng;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();
  String? _originalName;
  String? _originalPhone;
  String? _originalAddress;
  String? _originalProfileImage;

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

  final _addressController = TextEditingController();

  // image picking handled by _pickImageFromSource and action sheet

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (pickedFile != null) {
        // copy the picked file into app documents directory to avoid losing access
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filename = 'profile_${_user?.id ?? 'me'}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
          final savedPath = p.join(appDir.path, filename);

          // delete previous image if it was stored inside app documents
          if (_profileImagePath != null && _profileImagePath!.startsWith(appDir.path)) {
            try {
              final oldFile = File(_profileImagePath!);
              if (await oldFile.exists()) await oldFile.delete();
            } catch (_) {}
          }

          await File(pickedFile.path).copy(savedPath);
          setState(() {
            _profileImagePath = savedPath;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('photo_saved'))));
        } catch (e) {
          // fallback: use original path if copy fails
          setState(() {
            _profileImagePath = pickedFile.path;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('image_copy_failed'))));
        }
      }
    } catch (e) {
      // ignore or show snackbar
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('pick_image_error'))));
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(context: context, builder: (ctx) {
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
                title: Text(AppLocalizations.of(context).t('delete'), style: TextStyle(color: Colors.redAccent)),
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
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _originalName = _nameController.text;
      _originalPhone = _phoneController.text;
      _originalAddress = _addressController.text;
      _originalProfileImage = _profileImagePath;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _originalName ?? '';
      _phoneController.text = _originalPhone ?? '';
      _addressController.text = _originalAddress ?? '';
      _profileImagePath = _originalProfileImage;
    });
  }

  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
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
        SnackBar(content: Text(AppLocalizations.of(context).t('profile_updated'))),
      );
      setState(() {
        _isEditing = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text.trim();
    final next = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
      if (next.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('new_password_empty'))));
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('passwords_do_not_match'))));
      return;
    }
    // verify current password
    final verified = await _dbHelper.loginUser(_user!.email, current);
    if (verified == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('current_password_incorrect'))));
      return;
    }
    await _dbHelper.updatePasswordById(_user!.id!, next);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('password_changed'))));
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _deleteAccount() async {
      final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('delete_account')),
        content: Text(AppLocalizations.of(context).t('delete_account_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context).t('delete'), style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _dbHelper.deleteUser(_user!.id!);
      await _sessionManager.clearSession();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('account_deleted'))));
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginScreen()), (route) => false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).t('profile'),
        actions: _isEditing
            ? [
                IconButton(icon: Icon(Icons.check), onPressed: _updateProfile),
                IconButton(icon: Icon(Icons.close), onPressed: _cancelEditing),
              ]
            : [
                IconButton(icon: Icon(Icons.edit), onPressed: _startEditing),
              ],
      ),
      body: _user == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (_isEditing) {
                          _showImageSourceActionSheet();
                        } else {
                          final start = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(AppLocalizations.of(context).t('modify_photo')),
                              content: Text(AppLocalizations.of(context).t('activate_edit_mode')),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))),
                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('activate'))),
                              ],
                            ),
                          );
                          if (start == true) {
                            _startEditing();
                            // small delay to allow UI update
                            await Future.delayed(Duration(milliseconds: 150));
                            _showImageSourceActionSheet();
                          }
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _profileImagePath != null ? FileImage(File(_profileImagePath!)) : null,
                            child: _profileImagePath == null ? Icon(Icons.person, size: 50) : null,
                          ),
                          if (_isEditing)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.camera_alt, size: 18),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('name_label'), prefixIcon: Icon(Icons.person)),
                      validator: (value) => value!.isEmpty ? AppLocalizations.of(context).t('enter_name') : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('email_label'), prefixIcon: Icon(Icons.email)),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('phone_label'), prefixIcon: Icon(Icons.phone)),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).t('address_label'),
                        prefixIcon: Icon(Icons.home),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.map),
                          onPressed: () async {
                            final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: _pickedLat != null && _pickedLng != null ? LatLng(_pickedLat!, _pickedLng!) : null)));
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
                    SizedBox(height: 12),
                    Divider(),
                    Align(alignment: Alignment.centerLeft, child: Text(AppLocalizations.of(context).t('change_password'), style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('current_password_label'), prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                    ),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('new_password_label'), prefixIcon: Icon(Icons.lock_outline)),
                      obscureText: true,
                    ),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context).t('confirm_password_label'), prefixIcon: Icon(Icons.lock_outline)),
                      obscureText: true,
                    ),
                    SizedBox(height: 12),
                    LayoutBuilder(builder: (ctx, constraints) {
                      // If the available width is small, stack the buttons vertically to avoid overflow
                      if (constraints.maxWidth < 360) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomButton(
                              text: AppLocalizations.of(context).t('update'),
                              onPressed: _updateProfile,
                              icon: Icons.save,
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _changePassword,
                                icon: Icon(Icons.refresh),
                                label: Text(AppLocalizations.of(context).t('change_password')),
                              ),
                            ),
                          ],
                        );
                      }

                      // Otherwise keep them in a row with flexible sizing
                      return Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: AppLocalizations.of(context).t('update'),
                              onPressed: _updateProfile,
                              icon: Icons.save,
                            ),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: _changePassword,
                              icon: Icon(Icons.refresh),
                              label: FittedBox(fit: BoxFit.scaleDown, child: Text(AppLocalizations.of(context).t('change_password'))),
                            ),
                          )
                        ],
                      );
                    }),
                    SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _deleteAccount,
                      icon: Icon(Icons.delete, color: Colors.redAccent),
                      label: Text(AppLocalizations.of(context).t('delete_account'), style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent)),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
