import 'dart:io';

import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../l10n/strings.dart';
import 'complaint_detail_screen.dart';
import 'package:ilgabbiano/services/ai/sentiment_service.dart';

class ViewComplaintsScreen extends StatefulWidget {
  const ViewComplaintsScreen({super.key});
  @override
  _ViewComplaintsScreenState createState() => _ViewComplaintsScreenState();
}

class _ViewComplaintsScreenState extends State<ViewComplaintsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  DateTime? _fromDate;
  DateTime? _toDate;
  final _sentiment = SentimentService();
  bool _sortByPriority = true;
  late Future<List<Map<String, dynamic>>> _complaintsFuture; // cache to avoid refetch on every keypress

  @override
  void initState() {
    super.initState();
    // no role filter anymore; default: no date filter, empty search
    _complaintsFuture = _dbHelper.getComplaintsWithUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchController.removeListener(_onSearchChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openStatusSheet({required int id, required String current}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(String value, String label) => ListTile(
              leading: Icon(
                value == 'pending'
                    ? Icons.schedule
                    : value == 'in_progress'
                        ? Icons.playlist_add_check
                        : Icons.check_circle,
                color: _statusColor(value),
              ),
              title: Text(label),
              trailing: current == value ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
              onTap: () => Navigator.of(ctx).pop(value),
            );

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Text('Changer le statut', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                tile('pending', _statusLabels['pending'] ?? 'En attente'),
                tile('in_progress', _statusLabels['in_progress'] ?? 'En cours'),
                tile('resolved', _statusLabels['resolved'] ?? 'Résolu'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null && choice != current) {
      await _dbHelper.updateComplaintStatus(id, choice);
      _complaintsFuture = _dbHelper.getComplaintsWithUser();
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour: ${_statusLabels[choice] ?? choice}')),
        );
      }
    }
  }

  

  final _statusLabels = {
    'pending': 'En attente',
    'in_progress': 'En cours',
    'resolved': 'Résolu',
  };

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'employee':
        return 'Employé';
      case 'client':
      default:
        return 'Client';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.blueGrey;
    }
  }

  Color _sentimentColor(String label) {
    switch (label) {
      case 'negative':
        return Colors.redAccent;
      case 'positive':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatRange(DateTime? from, DateTime? to) {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    if (from == null && to == null) return '';
    if (from != null && to != null) return '${fmt(from)} — ${fmt(to)}';
    if (from != null) return 'Depuis ${fmt(from)}';
    return 'Jusqu\'à ${fmt(to!)}';
  }

  String _formatDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(title: Text(Strings.complaintsTitle)),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _complaintsFuture,
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(Strings.noComplaints));
          }
          final allComplaints = snapshot.data!;

          // Apply search and date filters
          final search = _searchController.text.trim().toLowerCase();
          List<Map<String, dynamic>> complaints = allComplaints.where((c) {
            bool matchesSearch = true;
            if (search.isNotEmpty) {
              final message = (c['message'] as String? ?? '').toLowerCase();
              final userName = (c['user_name'] as String? ?? '').toLowerCase();
              matchesSearch = message.contains(search) || userName.contains(search);
            }

            bool matchesDate = true;
            if (_fromDate != null || _toDate != null) {
              final createdRaw = c['created_at'] as String?;
              if (createdRaw == null) return false;
              final created = DateTime.tryParse(createdRaw)?.toLocal();
              if (created == null) return false;
              if (_fromDate != null) {
                if (created.isBefore(_fromDate!)) matchesDate = false;
              }
              if (_toDate != null) {
                // include the entire day for the toDate
                final endOfDay = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
                if (created.isAfter(endOfDay)) matchesDate = false;
              }
            }

            return matchesSearch && matchesDate;
          }).toList();

          if (_sortByPriority) {
            complaints.sort((a, b) {
              final sa = _sentiment.analyze((a['message'] as String?) ?? '');
              final sb = _sentiment.analyze((b['message'] as String?) ?? '');
              return sb.priority.compareTo(sa.priority); // high first
            });
          }

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
                          hintText: 'Rechercher par message ou utilisateur',
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
                    IconButton(
                      tooltip: 'Filtrer par période',
                      icon: Icon(Icons.date_range),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                          initialDateRange: _fromDate != null && _toDate != null
                              ? DateTimeRange(start: _fromDate!, end: _toDate!)
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _fromDate = picked.start;
                            _toDate = picked.end;
                          });
                        }
                      },
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Chip(
                          avatar: Icon(Icons.filter_alt, size: 18),
                          label: Text(_formatRange(_fromDate, _toDate)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                        child: Text('Effacer'),
                      ),
                    ],
                    IconButton(
                      tooltip: _sortByPriority ? 'Trier: priorité (élevée d\'abord)' : 'Trier: par date/filtre',
                      icon: Icon(Icons.priority_high, color: _sortByPriority ? Colors.redAccent : null),
                      onPressed: () => setState(() => _sortByPriority = !_sortByPriority),
                    ),
                    SizedBox(width: 8),
                    Text('${complaints.length} réclamation(s)'),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 20),
                  itemCount: complaints.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = complaints[index];
                    final id = c['id'] as int?;
                    final userName = c['user_name'] as String? ?? 'Utilisateur';
                    final userRole = c['user_role'] as String? ?? '';
                    final userProfileImage = c['user_profile_image'] as String?;
                    final message = c['message'] as String? ?? '';
                    final tone = _sentiment.analyze(message);
                    final status = c['status'] as String? ?? 'pending';
                    final type = c['type'] as String? ?? 'general';
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
                    final createdAtRaw = c['created_at'] as String?;
                    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;

          return InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: c)),
              );
              _complaintsFuture = _dbHelper.getComplaintsWithUser();
              if (mounted) setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading avatar
                  userProfileImage != null && userProfileImage.isNotEmpty
                      ? CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: userProfileImage.startsWith('http')
                              ? NetworkImage(userProfileImage) as ImageProvider
                              : FileImage(File(userProfileImage)),
                        )
                      : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            (userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Strings.by} $userName · ${_roleLabel(userRole)}' +
                              (createdAt != null ? ' · ${_formatDateTime(createdAt)}' : ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Trailing actions (no height constraint now)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _statusLabels[status] ?? status,
                            style: TextStyle(color: _statusColor(status), fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(color: typeColor, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _sentimentColor(tone.label).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tone.label == 'negative'
                                    ? Icons.sentiment_very_dissatisfied
                                    : tone.label == 'positive'
                                        ? Icons.sentiment_satisfied_alt
                                        : Icons.sentiment_neutral,
                                size: 12,
                                color: _sentimentColor(tone.label),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tone.label,
                                style: TextStyle(color: _sentimentColor(tone.label), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: const EdgeInsets.all(8),
                              constraints: BoxConstraints.tight(const Size(40, 40)),
                              tooltip: 'Répondre',
                              icon: const Icon(Icons.reply, size: 24),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: c)),
                              ),
                            ),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                                icon: const Icon(Icons.tune, size: 18),
                                label: const Text('Statut', style: TextStyle(fontSize: 12)),
                                onPressed: id == null ? null : () => _openStatusSheet(id: id, current: status),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
                  },
                ),
              ),
            ],
          );
        },
      ), // FutureBuilder
    ), // SafeArea
  ); // Scaffold
  }
}
