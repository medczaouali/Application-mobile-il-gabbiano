import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/complaint.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../services/realtime_service.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';

class ComplaintScreen extends StatefulWidget {
  final Complaint? complaint;

  const ComplaintScreen({super.key, this.complaint});

  @override
  _ComplaintScreenState createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  late DatabaseHelper _dbHelper;
  int? _userId;
  String? _userRole;
  bool _isSubmitting = false;
  bool _loadingUser = true;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription? _realtimeSub;

  bool get _isEditing => widget.complaint != null;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadUserId();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels <= _scrollCtrl.position.minScrollExtent + 40) {
        _loadMoreMessages();
      }
    });

    if (_isEditing) {
      _messageController.text = widget.complaint!.message;
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = _isEditing ? widget.complaint!.userId : prefs.getInt('userId');
      _userRole = prefs.getString('userRole');
      _loadingUser = false;
    });
    // If editing an existing complaint, load its messages
    // If this screen has a complaint id, load its messages (covers existing complaints opened from history)
    if (widget.complaint?.id != null) {
      // Immediately clear the unread count locally so the badge is removed
      // even if the DB update or schema migration takes time or fails.
      // Use safe static helper which will no-op if UnreadProvider hasn't been
      // instantiated yet. This prevents LookupFailed exceptions.
      await UnreadProvider.safeMarkComplaintRead(widget.complaint!.id!, refreshDb: false);
      await _loadMessages();
      // subscribe to realtime updates for this user so admin replies appear live
      _realtimeSub = RealtimeService().stream.listen((event) async {
        if (event['complaintId'] == widget.complaint!.id) {
          await _loadMessages();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nouvelle réponse disponible')));
          }
        }
      });
    }
  }

  Future<void> _loadMessages() async {
    if (widget.complaint?.id == null) return;
    // load latest page (most recent messages)
    final msgs = await _dbHelper.getComplaintMessagesPaginated(widget.complaint!.id!, limit: 20);
    if (_userId != null) {
      try {
        await _dbHelper.getUnreadMessagesCount(widget.complaint!.id!, _userId!);
      } catch (e) {
        // ignore DB errors here; we still attempt to mark read and clear provider
      }
      // mark read now that user opened the complaint
      try {
        await _dbHelper.markComplaintMessagesRead(widget.complaint!.id!, _userId!);
      } catch (e) {
        // ignore DB mark-read errors
      }
      // Prefer the Provider when available, but fall back to the safe static
      // helper to avoid lookup exceptions.
      try {
        Provider.of<UnreadProvider>(context, listen: false).markComplaintRead(widget.complaint!.id!, refreshDb: true);
      } catch (e) {
        await UnreadProvider.safeMarkComplaintRead(widget.complaint!.id!, refreshDb: true);
      }
    }
    setState(() {
      _messages = msgs;
      _hasMore = msgs.length >= 20;
    });
    // scroll to bottom after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMore || !_hasMore || !_isEditing || widget.complaint?.id == null) return;
    setState(() => _loadingMore = true);
    final firstCreated = _messages.isNotEmpty ? _messages.first['created_at'] as String? : null;
    final more = await _dbHelper.getComplaintMessagesPaginated(widget.complaint!.id!, beforeCreatedAt: firstCreated, limit: 20);
    setState(() {
      _messages = [...more, ..._messages];
      _hasMore = more.length >= 20;
      _loadingMore = false;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollCtrl.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: utilisateur non identifié. Veuillez vous connecter.')),
      );
      return;
    }

    final complaint = Complaint(
      id: _isEditing ? widget.complaint!.id : null,
      userId: _userId!,
      message: _messageController.text,
      status: _isEditing ? widget.complaint!.status : 'pending',
    );

    // If editing and status is not pending, disallow updates
    if (_isEditing && widget.complaint!.status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cette réclamation ne peut plus être modifiée.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        try {
          await _dbHelper.updateComplaint(complaint);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Réclamation modifiée avec succès.')),
          );
          Navigator.pop(context, true);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la modification: ${e.toString()}')));
        }
      } else {
        try {
          await _dbHelper.createComplaint(complaint);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Réclamation envoyée avec succès.')),
          );
          Navigator.pop(context, true); // go back to list
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'envoi: ${e.toString()}')));
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _isEditing ? 'Modifier la réclamation' : 'Envoyer une Réclamation',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Professional header
                if (_userRole == 'employee')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium, color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 8),
                        Text('Mode Professionnel', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),

                // If still loading user id, show a small loader; if no user, prompt to login
                if (_loadingUser)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (!_loadingUser && _userId == null)
                  Card(
                    color: Colors.yellow.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(child: Text('Vous devez être connecté pour envoyer une réclamation.')),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen()));
                            },
                            child: Text('Se connecter'),
                          )
                        ],
                      ),
                    ),
                  ),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isEditing
                              ? 'Modifiez votre réclamation ci-dessous.'
                              : 'Veuillez décrire votre problème ci-dessous. Notre équipe l\'examinera dans les plus brefs délais.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(height: 12),

                        // Show status chip when editing
                        if (_isEditing) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.complaint!.status == 'resolved'
                                    ? Colors.green.withOpacity(0.12)
                                    : widget.complaint!.status == 'in_progress'
                                        ? Colors.orange.withOpacity(0.12)
                                        : Colors.blueGrey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.complaint!.status == 'resolved'
                                    ? 'Résolu'
                                    : widget.complaint!.status == 'in_progress'
                                        ? 'En cours'
                                        : 'En attente',
                                style: TextStyle(
                                    color: widget.complaint!.status == 'resolved'
                                        ? Colors.green
                                        : widget.complaint!.status == 'in_progress'
                                            ? Colors.orange
                                            : Colors.blueGrey,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Conversation (paginated, with avatars & date separators)
                          if (_messages.isNotEmpty) ...[
                            Container(
                              constraints: BoxConstraints(maxHeight: 320),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notif) {
                                  if (notif.metrics.pixels <= notif.metrics.minScrollExtent + 40) {
                                    _loadMoreMessages();
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollCtrl,
                                  shrinkWrap: true,
                                  itemCount: _messages.length + (_loadingMore ? 1 : 0),
                                  itemBuilder: (context, i) {
                                    if (_loadingMore && i == 0) {
                                      return Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)));
                                    }
                                    final idx = _loadingMore ? i - 1 : i;
                                    final m = _messages[idx];
                                    final isMine = m['sender_id'] == _userId;
                                    final created = m['created_at'] != null ? DateTime.tryParse(m['created_at']) : null;

                                    // Date separator: show when first message or day changed
                                    Widget dateSep = SizedBox.shrink();
                                    if (idx == 0 || (idx > 0 && _messages[idx - 1]['created_at'] != null && (DateTime.tryParse(_messages[idx - 1]['created_at'])?.day != created?.day || DateTime.tryParse(_messages[idx - 1]['created_at'])?.month != created?.month || DateTime.tryParse(_messages[idx - 1]['created_at'])?.year != created?.year))) {
                                      final dt = created ?? DateTime.now();
                                      dateSep = Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Center(child: Text(DateFormat('dd MMM yyyy').format(dt), style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                                      );
                                    }

                                    return Column(
                                      children: [
                                        dateSep,
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isMine)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: CircleAvatar(
                                                  radius: 16,
                                                  backgroundImage: m['sender_profile_image'] != null && (m['sender_profile_image'] as String).isNotEmpty
                                                      ? ((m['sender_profile_image'] as String).startsWith('http') ? NetworkImage(m['sender_profile_image']) : FileImage(File(m['sender_profile_image']))) as ImageProvider
                                                      : null,
                                                  child: (m['sender_profile_image'] == null || (m['sender_profile_image'] as String).isEmpty) ? Text((m['sender_name'] as String?)?.substring(0,1).toUpperCase() ?? '?') : null,
                                                ),
                                              ),
                                            Expanded(
                                              child: Align(
                                                alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                                child: Container(
                                                  margin: EdgeInsets.symmetric(vertical: 6),
                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: isMine ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(m['message'] as String),
                                                      const SizedBox(height: 6),
                                                      Text(created != null ? DateFormat('HH:mm').format(created) : '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (isMine) SizedBox(width: 40),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],

                        TextFormField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            labelText: 'Message',
                            hintText: 'Entrez les détails de votre réclamation ici...',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          maxLines: 8,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un message.';
                            }
                            return null;
                          },
                          enabled: !_isEditing || widget.complaint!.status == 'pending',
                        ),
                        SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: (_loadingUser || (_isEditing && widget.complaint!.status != 'pending') || _isSubmitting)
                              ? null
                              : _submitComplaint,
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(_isEditing ? 'Modifier' : 'Envoyer'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
