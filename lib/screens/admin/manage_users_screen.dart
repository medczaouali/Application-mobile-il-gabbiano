
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../../db/database_helper.dart';
import '../../models/user.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/user_card.dart';
import '../../l10n/strings.dart';
import '../../services/session_manager.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _session = SessionManager();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _roleFilter = 'all'; // all, client, employee, admin
  String _bannedFilter = 'all'; // all, banned, not_banned
  String _sort = 'name_asc'; // name_asc, name_desc, role

  int? _currentUserId;
  String? _currentUserRole;

  // Advanced actions are handled inline via UserCard's onAction callback.

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSession();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSession() async {
    final sess = await _session.getUserSession();
    if (!mounted) return;
    setState(() {
      _currentUserId = sess?['id'] as int?;
      _currentUserRole = sess?['role'] as String?;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Gérer les Utilisateurs'),
      body: FutureBuilder<List<User>>(
        future: _dbHelper.getAllUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          // start from all users
          final allUsers = List<User>.of(snapshot.data!);
          // Determine primary (main) admin: prefer the seeded admin@admin.com, else the admin with the smallest ID
          int? primaryAdminId;
          for (final u in allUsers) {
            if (u.email.toLowerCase() == 'admin@admin.com') {
              primaryAdminId = u.id;
              break;
            }
          }
          if (primaryAdminId == null) {
            final admins = allUsers.where((u) => u.role == 'admin' && u.id != null).toList();
            if (admins.isNotEmpty) {
              admins.sort((a, b) => (a.id ?? 1 << 30).compareTo(b.id ?? 1 << 30));
              primaryAdminId = admins.first.id;
            }
          }

          List<User> users = List.of(allUsers);

          // role filter
          if (_roleFilter != 'all') {
            users = users.where((u) => u.role == _roleFilter).toList();
          }

          // banned filter
          if (_bannedFilter == 'banned') {
            users = users.where((u) => u.isBanned == 1).toList();
          } else if (_bannedFilter == 'not_banned') {
            users = users.where((u) => u.isBanned != 1).toList();
          }

          // search filter (name, email, phone)
          final search = _searchController.text.trim().toLowerCase();
          if (search.isNotEmpty) {
            users = users.where((u) {
              final name = u.name.toLowerCase();
              final email = u.email.toLowerCase();
              final phone = u.phone.toLowerCase();
              return name.contains(search) || email.contains(search) || phone.contains(search);
            }).toList();
          }

          // sort
          users.sort((a, b) {
            switch (_sort) {
              case 'name_desc':
                return b.name.toLowerCase().compareTo(a.name.toLowerCase());
              case 'role':
                final r = a.role.toLowerCase().compareTo(b.role.toLowerCase());
                if (r != 0) return r;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              case 'name_asc':
              default:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _searchFocusNode,
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Rechercher par nom, email ou téléphone',
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        FocusScope.of(context).requestFocus(_searchFocusNode);
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _sort,
                          onChanged: (v) => setState(() => _sort = v ?? 'name_asc'),
                          items: const [
                            DropdownMenuItem(value: 'name_asc', child: Text('Nom A→Z')),
                            DropdownMenuItem(value: 'name_desc', child: Text('Nom Z→A')),
                            DropdownMenuItem(value: 'role', child: Text('Par rôle')),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Exporter en CSV',
                          child: OutlinedButton.icon(
                            onPressed: users.isEmpty ? null : () => _exportUsersCsv(users),
                            icon: const Icon(Icons.grid_on),
                            label: const Text('CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Exporter en PDF',
                          child: FilledButton.icon(
                            onPressed: users.isEmpty ? null : () => _exportUsersPdf(users),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip('all', 'Tous les rôles', _roleFilter, (v) => setState(() => _roleFilter = v)),
                              _buildFilterChip('client', 'Clients', _roleFilter, (v) => setState(() => _roleFilter = v)),
                              _buildFilterChip('admin', 'Admins', _roleFilter, (v) => setState(() => _roleFilter = v)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildBannedChip('all', 'Tous'),
                            _buildBannedChip('not_banned', 'Actifs'),
                            _buildBannedChip('banned', 'Bannis'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('${users.length} utilisateur(s)', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossAxisCount = w >= 1100 ? 4 : w >= 900 ? 3 : w >= 620 ? 2 : 1;
                    if (crossAxisCount == 1) {
                      return ListView.builder(
                        padding: EdgeInsets.only(top: 0, bottom: 24),
                        itemCount: users.length,
                        itemBuilder: (context, index) => _buildUserTile(users[index], primaryAdminId),
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.only(top: 0, bottom: 24, left: 8, right: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.9,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) => _buildUserTile(users[index], primaryAdminId),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportUsersCsv(List<User> users) async {
    try {
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'utilisateurs_$ts.csv';
      final buffer = StringBuffer();
      // Header
      buffer.writeln('ID;Nom;Email;Téléphone;Rôle;Statut;Adresse;Latitude;Longitude');
      for (final u in users) {
        final statut = u.isBanned == 1 ? 'Banni' : 'Actif';
        final line = [
          u.id?.toString() ?? '',
          _csvEscape(u.name),
          _csvEscape(u.email),
          _csvEscape(u.phone),
          _csvEscape(u.role),
          statut,
          _csvEscape(u.address),
          u.latitude?.toStringAsFixed(6) ?? '',
          u.longitude?.toStringAsFixed(6) ?? '',
        ].join(';');
        buffer.writeln(line);
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
  await file.writeAsString(buffer.toString(), encoding: utf8);

      await Share.shareXFiles([XFile(file.path)],
          subject: 'Export utilisateurs (CSV)', text: 'Export des utilisateurs au $ts');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec export CSV: $e')));
    }
  }

  String _csvEscape(String v) {
    // Replace separators and line breaks; wrap with quotes if needed
    var s = v.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final needsQuote = s.contains(';') || s.contains('"');
    if (needsQuote) {
      s = s.replaceAll('"', '""');
      return '"$s"';
    }
    return s;
  }

  Future<void> _exportUsersPdf(List<User> users) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final ts = DateFormat('dd/MM/yyyy HH:mm').format(now);

      final headers = ['ID', 'Nom', 'Email', 'Téléphone', 'Rôle', 'Statut'];
      final data = users.map((u) => [
            u.id?.toString() ?? '',
            u.name,
            u.email,
            u.phone,
            u.role,
            u.isBanned == 1 ? 'Banni' : 'Actif',
          ]).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Export utilisateurs', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(ts, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: headers,
              data: data,
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            ),
            pw.SizedBox(height: 8),
            pw.Text('${users.length} utilisateur(s)', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final fileName = 'utilisateurs_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([XFile(file.path)], subject: 'Export utilisateurs (PDF)');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec export PDF: $e')));
    }
  }

  Widget _buildUserTile(User user, int? primaryAdminId) {
    final isPrimaryTarget = (primaryAdminId != null && user.id == primaryAdminId);
    final isSelf = (_currentUserId != null && user.id == _currentUserId);
    final currentIsPrimary = (_currentUserId != null && primaryAdminId != null && _currentUserId == primaryAdminId);
    final currentIsAdmin = (_currentUserRole == 'admin');

    // Permission rules
    final canChangeRole = currentIsPrimary && !isSelf && !isPrimaryTarget; // only main admin can change roles, never on self or primary
    final canBan = currentIsAdmin && !isPrimaryTarget && !isSelf; // cannot ban main admin or self
    final canDelete = currentIsAdmin && !isPrimaryTarget && !isSelf; // cannot delete main admin or self
    final canReset = currentIsAdmin && !isPrimaryTarget; // secondary cannot act on primary

    return UserCard(
      user: user,
      isPrimaryAdmin: isPrimaryTarget,
      canPromoteOrDemote: canChangeRole,
      canBan: canBan,
      canResetPassword: canReset,
      canDelete: canDelete,
      onAction: (action) async {
                        try {
                          // Guard actions server-side too
                          if (action.startsWith('changeRole:')) {
                            if (!canChangeRole) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action non autorisée")));
                              return;
                            }
                          }
                          if (action == 'ban' && !canBan) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action non autorisée")));
                            return;
                          }
                          if (action == 'delete' && !canDelete) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action non autorisée")));
                            return;
                          }
                          if (action == 'resetPassword' && !canReset) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action non autorisée")));
                            return;
                          }
                          if (action == 'ban') {
                            final isBanned = user.isBanned == 1;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(isBanned ? 'Lever le bannissement ?' : 'Bannir cet utilisateur ?'),
                                content: Text(isBanned
                                    ? 'L’utilisateur pourra se reconnecter et utiliser l’application.'
                                    : 'L’utilisateur ne pourra plus se connecter ni utiliser l’application.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(Strings.cancel)),
                                  ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(Strings.confirm)),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _dbHelper.banUser(user.id!, !isBanned);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(!isBanned ? 'Utilisateur banni' : 'Utilisateur débanni')),
                              );
                            }
                            return;
                          }
                          if (action == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Supprimer utilisateur'),
                                content: Text('Voulez-vous vraiment supprimer cet utilisateur ? Cette action est irréversible.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(Strings.cancel)),
                                  ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(Strings.confirm)),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _dbHelper.deleteUser(user.id!);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Utilisateur supprimé')));
                            }
                            return;
                          }
                          if (action == 'resetPassword') {
                            await _dbHelper.updatePasswordById(user.id!, 'Welcome123');
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mot de passe réinitialisé')));
                            return;
                          }
                          if (action.startsWith('changeRole:')) {
                            final newRole = action.split(':').last;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text('Changer le rôle ?'),
                                content: Text(newRole == 'admin'
                                    ? 'Promouvoir cet utilisateur au rôle Administrateur ? Il aura accès au back‑office.'
                                    : 'Changer le rôle de cet utilisateur en "$newRole" ?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(Strings.cancel)),
                                  ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(Strings.confirm)),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _dbHelper.updateUserRole(user.id!, newRole);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newRole == 'admin' ? 'Utilisateur promu administrateur' : 'Rôle modifié')));
                            }
                            return;
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      },
    );
  }

  Widget _buildFilterChip(String value, String label, String groupValue, void Function(String) onSelected) {
    final selected = groupValue == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: selected ? Icon(Icons.check, size: 18) : null,
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _buildBannedChip(String value, String label) {
    final selected = _bannedFilter == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _bannedFilter = value),
    );
  }
}
