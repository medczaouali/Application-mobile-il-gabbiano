import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/complaint_screen.dart';
import '../../db/database_helper.dart';
import '../../models/complaint.dart';
import '../../services/session_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../services/realtime_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';

class ComplaintHistoryScreen extends StatefulWidget {
  @override
  _ComplaintHistoryScreenState createState() => _ComplaintHistoryScreenState();
}

class _ComplaintHistoryScreenState extends State<ComplaintHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();
  late Future<List<Complaint>> _complaintsFuture;
  int? _currentUserId;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _refreshComplaints();
    // subscribe to realtime events so unread badges update immediately
    _realtimeSub = RealtimeService().stream.listen((event) {
      // When a new reply arrives, refresh complaints to update unread badges
      // We don't crash if user id missing; _getComplaints will handle it.
      _refreshComplaints();
    });
  }

  void _refreshComplaints() {
    setState(() {
      _complaintsFuture = _getComplaints();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<List<Complaint>> _getComplaints() async {
    final session = await _sessionManager.getUserSession();
    _currentUserId = session?['id'];
    if (session != null) {
      return _dbHelper.getComplaintsByUser(session['id']);
    }
    return [];
  }

  void _navigateToComplaintScreen([Complaint? complaint]) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ComplaintScreen(complaint: complaint),
      ),
    );
    // If the user opened an existing complaint, mark messages as read
    if (complaint != null && _currentUserId != null) {
      await _dbHelper.markComplaintMessagesRead(complaint.id!, _currentUserId!);
    }
    if (result == true) {
      _refreshComplaints();
    } else {
      // Always refresh to update unread badges
      _refreshComplaints();
    }
  }

  void _deleteComplaint(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cette réclamation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteComplaint(id);
      _refreshComplaints();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Réclamation supprimée avec succès.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('complaint_history')),
      ),
      body: FutureBuilder<List<Complaint>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).t('no_complaints'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          final complaints = snapshot.data!;
          return ListView.builder(
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              final canModify = complaint.status == 'pending';

              // parse and format created_at if available
              String createdStr = '';
              if (complaint.createdAt != null && complaint.createdAt!.isNotEmpty) {
                try {
                  final dt = DateTime.parse(complaint.createdAt!);
                  createdStr = DateFormat('dd MMM yyyy – HH:mm').format(dt);
                } catch (_) {
                  createdStr = complaint.createdAt!;
                }
              }

              Color statusColor;
              switch (complaint.status) {
                case 'resolved':
                  statusColor = Colors.green;
                  break;
                case 'in_progress':
                case 'processing':
                  statusColor = Colors.orange;
                  break;
                case 'pending':
                default:
                  statusColor = Colors.blueGrey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () => _navigateToComplaintScreen(complaint),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(complaint.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    backgroundColor: statusColor.withOpacity(0.12),
                                    label: Text(
                                      complaint.status.replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (createdStr.isNotEmpty)
                                    Text(createdStr, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                                  // Use an explicit SizedBox to push trailing widgets to the end rather than Spacer()
                                  const SizedBox(width: 8),
                                  Expanded(child: SizedBox.shrink()),
                                  // Unread messages indicator (driven by UnreadProvider)
                                  if (_currentUserId != null)
                                    Builder(builder: (ctx) {
                                      int cnt = 0;
                                      try {
                                        final up = Provider.of<UnreadProvider>(ctx);
                                        cnt = up.getCountForComplaint(complaint.id);
                                      } catch (e) {
                                        // provider not available - treat as 0
                                      }
                                      if (cnt > 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.notification_important, color: Colors.redAccent, size: 18),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                                                child: Text('$cnt', style: TextStyle(color: Colors.white, fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  if (canModify)
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _navigateToComplaintScreen(complaint);
                                        if (v == 'delete') _deleteComplaint(complaint.id!);
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text(AppLocalizations.of(context).t('edit'))])),
                                        PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text(AppLocalizations.of(context).t('delete'), style: TextStyle(color: Colors.red))])),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (100 * index).ms);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToComplaintScreen(),
        child: Icon(Icons.add),
        tooltip: AppLocalizations.of(context).t('new_complaint'),
      ),
    );
  }
}