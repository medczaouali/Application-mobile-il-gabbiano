
import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../models/user.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/user_card.dart';
import '../../l10n/strings.dart';

class ManageUsersScreen extends StatefulWidget {
  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Advanced actions are handled inline via UserCard's onAction callback.

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
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
          // prepare list and apply client role filter
          final allUsers = snapshot.data!;
          final clients = allUsers.where((user) => user.role == 'client').toList();

          // search filter (name, email, phone)
          final search = _searchController.text.trim().toLowerCase();
          final users = search.isEmpty
              ? clients
              : clients.where((u) {
                  final name = u.name.toLowerCase();
                  final email = u.email.toLowerCase();
                  final phone = u.phone.toLowerCase();
                  return name.contains(search) || email.contains(search) || phone.contains(search);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
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
                    Text('${users.length} utilisateur(s)'),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(top: 0, bottom: 24),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return UserCard(
                      user: user,
                      onAction: (action) async {
                        try {
                          if (action == 'ban') {
                            await _dbHelper.banUser(user.id!, user.isBanned != 1);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut de bannissement mis à jour')));
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
                            await _dbHelper.updateUserRole(user.id!, newRole);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rôle modifié')));
                            return;
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      },
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
}
