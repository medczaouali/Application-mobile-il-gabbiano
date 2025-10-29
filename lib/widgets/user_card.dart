import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:cached_network_image/cached_network_image.dart';

typedef UserActionCallback = Future<void> Function(String action);

class UserCard extends StatefulWidget {
  final User user;
  final Future<void> Function(String action) onAction; // actions: ban, delete, changeRole:<role>, resetPassword

  const UserCard({Key? key, required this.user, required this.onAction}) : super(key: key);

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
                  children: [
                    u.profileImage != null && u.profileImage!.isNotEmpty
                        ? CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: u.profileImage!.startsWith('http')
                    ? CachedNetworkImageProvider(u.profileImage!) as ImageProvider
                                : FileImage(File(u.profileImage!)),
                          )
                        : CircleAvatar(child: Text((u.name.isNotEmpty ? u.name[0] : 'U').toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u.name, style: TextStyle(fontWeight: FontWeight.w600)), Text(u.email, style: TextStyle(color: Colors.grey))])),
                    Chip(label: Text(u.role), backgroundColor: u.role == 'admin' ? Colors.blueAccent : Colors.greenAccent),
                    const SizedBox(width: 8),
                    RotationTransition(turns: Tween(begin: 0.0, end: 0.5).animate(_controller), child: Icon(Icons.expand_more)),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (_loading) CircularProgressIndicator() else IconButton(onPressed: () => _runAction('changeRole:admin'), icon: Icon(Icons.admin_panel_settings)),
                    SizedBox(width: 8),
                    IconButton(onPressed: () => _runAction('ban'), icon: Icon(u.isBanned == 1 ? Icons.lock_open : Icons.block), color: u.isBanned == 1 ? Colors.green : Colors.orange),
                    SizedBox(width: 8),
                    IconButton(onPressed: () => _runAction('resetPassword'), icon: Icon(Icons.refresh), tooltip: 'Reset Password'),
                    Spacer(),
                    IconButton(onPressed: () => _runAction('delete'), icon: Icon(Icons.delete, color: Colors.red)),
                  ])
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
