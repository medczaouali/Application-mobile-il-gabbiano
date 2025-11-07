import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';

typedef UserActionCallback = Future<void> Function(String action);

class UserCard extends StatefulWidget {
  final User user;
  final Future<void> Function(String action) onAction; // actions: ban, delete, changeRole:<role>, resetPassword

  // Permissions computed by parent
  final bool canPromoteOrDemote;
  final bool canBan;
  final bool canResetPassword;
  final bool canDelete;
  final bool isPrimaryAdmin;

  const UserCard({
    super.key,
    required this.user,
    required this.onAction,
    this.canPromoteOrDemote = false,
    this.canBan = false,
    this.canResetPassword = false,
    this.canDelete = false,
    this.isPrimaryAdmin = false,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _loading = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runAction(String action) async {
    setState(() => _loading = true);
    try {
      await widget.onAction(action);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AnimatedSize(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) _controller.forward(); else _controller.reverse();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    u.profileImage != null && u.profileImage!.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: u.profileImage!.startsWith('http')
                                ? CachedNetworkImageProvider(u.profileImage!) as ImageProvider
                                : FileImage(File(u.profileImage!)),
                          )
                        : CircleAvatar(
                            child: Text((u.name.isNotEmpty ? u.name[0] : 'U').toUpperCase()),
                          ),
                    const SizedBox(width: 12),
                    // Name, email and badges stacked to avoid squeezing text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            u.email,
                            style: const TextStyle(color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (u.isBanned == 1)
                                Chip(
                                  label: const Text('Banni', style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.redAccent,
                                ),
                              Chip(
                                label: Text(
                                  u.role == 'admin'
                                      ? 'Admin'
                                      : (u.role == 'employee' ? 'Employé' : 'Client'),
                                ),
                backgroundColor: u.role == 'admin'
                  ? Colors.blueAccent.withValues(alpha: 0.15)
                  : (u.role == 'employee'
                    ? Colors.orangeAccent.withValues(alpha: 0.15)
                    : Colors.greenAccent.withValues(alpha: 0.2)),
                              ),
                              if (widget.isPrimaryAdmin)
                                Chip(
                                  avatar: const Icon(Icons.star, size: 16, color: Colors.deepPurple),
                                  label: const Text('Admin principal'),
                                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                                  shape: StadiumBorder(
                                    side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.3)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_controller),
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loading) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ] else ...[
                        Column(
                          children: [
                            if (u.role == 'admin')
                              IconButton(
                                tooltip: 'Rétrograder en client',
                                onPressed: widget.canPromoteOrDemote ? () => _runAction('changeRole:client') : null,
                                icon: const Icon(Icons.arrow_downward),
                                color: widget.canPromoteOrDemote ? null : Colors.grey,
                              )
                            else
                              IconButton(
                                tooltip: 'Promouvoir en admin',
                                onPressed: widget.canPromoteOrDemote ? () => _runAction('changeRole:admin') : null,
                                icon: const Icon(Icons.admin_panel_settings),
                                color: widget.canPromoteOrDemote ? null : Colors.grey,
                              ),
                            const SizedBox(height: 2),
                            Text(u.role == 'admin' ? 'Rétrograder' : 'Promouvoir', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            IconButton(
                              tooltip: u.isBanned == 1 ? 'Débannir' : 'Bannir',
                              onPressed: widget.canBan ? () => _runAction('ban') : null,
                              icon: Icon(u.isBanned == 1 ? Icons.lock_open : Icons.block),
                              color: widget.canBan
                                  ? (u.isBanned == 1 ? Colors.green : Colors.orange)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 2),
                            Text(u.isBanned == 1 ? 'Débannir' : 'Bannir', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            IconButton(
                              tooltip: 'Réinitialiser mot de passe',
                              onPressed: widget.canResetPassword ? () => _runAction('resetPassword') : null,
                              icon: const Icon(Icons.refresh),
                              color: widget.canResetPassword ? null : Colors.grey,
                            ),
                            const SizedBox(height: 2),
                            Text('Réinit. MDP', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: widget.canDelete ? () => _runAction('delete') : null,
                              icon: Icon(Icons.delete, color: widget.canDelete ? Colors.red : Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text('Supprimer', style: TextStyle(fontSize: 11, color: Colors.red)),
                          ],
                        ),
                      ],
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
