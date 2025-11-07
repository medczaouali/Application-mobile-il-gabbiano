import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/chat_bubble.dart';
import '../../db/database_helper.dart';
import '../../l10n/strings.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const ComplaintDetailScreen({Key? key, required this.complaint}) : super(key: key);

  @override
  _ComplaintDetailScreenState createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId') ?? 0;
    });
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final id = widget.complaint['id'] as int?;
    if (id == null) return;
    final msgs = await _dbHelper.getComplaintMessages(id);
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    // scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('userId') ?? 0;
    final id = widget.complaint['id'] as int?;
    if (id == null) return;
    await _dbHelper.addComplaintMessage(id, currentUserId, text);
    _replyController.clear();
    await _loadMessages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Réponse envoyée')));
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.complaint['user_name'] as String? ?? 'Utilisateur';
    final message = widget.complaint['message'] as String? ?? '';
    final status = widget.complaint['status'] as String? ?? 'pending';
    final type = widget.complaint['type'] as String? ?? 'general';
    Color typeColor;
    String typeLabel;
    switch (type) {
      case 'technical':
        typeColor = Colors.indigo;
        typeLabel = 'Technique';
        break;
      case 'order':
        typeColor = Colors.teal;
        typeLabel = 'Commande';
        break;
      case 'food':
        typeColor = Colors.deepOrange;
        typeLabel = 'Plats';
        break;
      case 'service':
        typeColor = Colors.purple;
        typeLabel = 'Service';
        break;
      default:
        typeColor = Colors.blueGrey;
        typeLabel = 'Autre';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Réclamation de $userName'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(typeLabel.toUpperCase(), style: TextStyle(fontSize: 12, color: typeColor)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(message),
                              subtitle: Text('${Strings.by} $userName'),
                            ),
                          );
                        }
                                            final m = _messages[i - 1];
                                            final senderName = m['sender_name'] as String? ?? '';
                                            final sentAt = m['created_at'] as String? ?? '';
                                            final senderId = m['sender_id'] as int?;
                                            final bool isMe = _currentUserId != null && senderId == _currentUserId;
                                            final bubbleColor = isMe ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
                                            final textColor = isMe ? Colors.white : Colors.black87;

                                            return Container(
                                              margin: EdgeInsets.symmetric(vertical: 6),
                                              child: Row(
                                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (!isMe) ...[
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: Colors.grey.shade200,
                                                      child: Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?'),
                                                    ),
                                                    SizedBox(width: 8),
                                                  ],

                                                  ConstrainedBox(
                                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                                    child: Column(
                                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                      children: [
                                                        Text(senderName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                        SizedBox(height: 6),
                                                        ChatBubble(
                                                          isMe: isMe,
                                                          color: bubbleColor,
                                                          child: Text(
                                                            m['message'] as String? ?? '',
                                                            style: TextStyle(color: textColor),
                                                          ),
                                                        ),
                                                        SizedBox(height: 6),
                                                        Text(sentAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                                      ],
                                                    ),
                                                  ),

                                                  if (isMe) ...[
                                                    SizedBox(width: 8),
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: Colors.blue.shade50,
                                                      child: Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?'),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                      },
                    ),
            ),
            // Reply input
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: Strings.reply,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendReply,
                      child: Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
