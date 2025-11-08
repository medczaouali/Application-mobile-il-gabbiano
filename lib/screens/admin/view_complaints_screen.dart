import 'dart:io';

import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../l10n/strings.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/TextbeltSmsService.dart';
import 'complaint_detail_screen.dart';

class ViewComplaintsScreen extends StatefulWidget {
  @override
  _ViewComplaintsScreenState createState() => _ViewComplaintsScreenState();
}

class _ViewComplaintsScreenState extends State<ViewComplaintsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextbeltSmsService _smsService = TextbeltSmsService();



  // Cette fonction n'est plus nécessaire si nous utilisons _sentimentColor
  // J'ai laissé colorFromHex pour l'instant au cas où elle serait utilisée ailleurs.
  Color colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor; // Ajoute l'opacité complète si elle manque
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Service':
        return Colors.blue;
      case 'Repas':
        return Colors.red;
      case 'Réservation':
        return Colors.teal;
      case 'Paiement':
        return Colors.purple;
      case 'Application':
        return Colors.green;
      case 'Autre':
      default:
        return Colors.grey;
    }
  }

  // ✅ VOTRE FONCTION DE COULEUR DE SENTIMENT
  Color _sentimentColor(String sentiment) {
    switch (sentiment.toLowerCase().trim()) {
      case 'negative':
        return Colors.red; // Rouge pour Négatif
      case 'positive':
        return Colors.green; // Vert pour Positif
      case 'neutral':
        return Colors.grey; // Gris pour Neutre
      default:
        return Colors.blueGrey; // Couleur par défaut/inconnue
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
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
        return Colors.yellow;
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
          future: _dbHelper.getComplaintsWithUser(),
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
                      final aiService = AiAnalysisService();
                      final status = c['status'] as String? ?? 'pending';
                      final createdAtRaw = c['created_at'] as String?;
                      final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;
                      final category = c['category'] as String? ?? Strings.other;

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: userProfileImage != null && userProfileImage.isNotEmpty
                            ? CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: userProfileImage.startsWith('http')
                              ? NetworkImage(userProfileImage) as ImageProvider
                              : FileImage(File(userProfileImage)),
                        )
                            : CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            (userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  // 1. CHIP DE CATÉGORIE
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(category).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      category,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: _categoryColor(category),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 8), // Espace

                                  // 2. CHIP DE SENTIMENT (MODIFIÉ pour utiliser _sentimentColor)
                                  FutureBuilder<String>(
                                    future: aiService.analyzeMessage(message),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return SizedBox(width: 50, height: 15, child: LinearProgressIndicator(minHeight: 2,));
                                      }

                                      if (snapshot.hasData && snapshot.data != null) {
                                        // Séparez la chaîne en Texte et Mot-clé de Sentiment
                                        // La fonction analyzeMessage renvoie [Texte du Sentiment] + \n + [Code Couleur] (Ex: 'Négatif 😠\n#F44336')
                                        final parts = snapshot.data!.split('\n');
                                        final sentimentText = parts[0];

                                        // 🎯 NOUVELLE LOGIQUE : Déduire le mot-clé du sentiment à partir du texte.
                                        // (Ceci suppose que le texte commence par Négatif, Positif ou Neutre)
                                        final sentimentKeyword = sentimentText.split(' ').first;

                                        // 🎯 Utilisation de votre fonction _sentimentColor
                                        final displayColor = _sentimentColor(sentimentKeyword);

                                        return Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            // Utilise la couleur du sentiment avec opacité
                                            color: displayColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            sentimentText,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              // Utilise la couleur du sentiment en plein pour le texte
                                              color: displayColor,
                                            ),
                                          ),
                                        );
                                      }

                                      // Retourne un widget vide si l'analyse échoue (Erreur ou Inconnu)
                                      return SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Ligne 2 : Utilisateur et Date (RESTE INCHANGÉE)
                            Text(
                              '${Strings.by} $userName · ${_roleLabel(userRole)}' + (createdAt != null ? ' · ${_formatDateTime(createdAt)}' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 92,
                          height: 48,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(_statusLabels[status] ?? status,
                                      style: TextStyle(color: _statusColor(status), fontSize: 11)),
                                ),
                                SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.all(4),
                                      constraints: BoxConstraints.tight(Size(28, 28)),
                                      tooltip: 'Répondre',
                                      icon: Icon(Icons.reply, size: 18),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: c))),
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.all(0),
                                      onSelected: (String newValue) async {
                                        if (id != null) {
                                          await _dbHelper.updateComplaintStatus(id, newValue);
                                          if (newValue == 'resolved') {
                                            final userPhone = c['user_phone'] as String? ?? '';
                                            if (userPhone.isNotEmpty) {
                                              await _smsService.sendSms(
                                                to: '+21698765073',
                                                message: 'Votre réclamation a été traitée avec succès.',
                                              );
                                            }
                                          }
                                          setState(() {});
                                        }
                                      },
                                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                                        PopupMenuItem(value: 'pending', child: Text('En attente')),
                                        PopupMenuItem(value: 'in_progress', child: Text('En cours')),
                                        PopupMenuItem(value: 'resolved', child: Text('Résolu')),
                                      ],
                                      child: Icon(Icons.more_vert, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        onTap: () async {
                          // open the reusable complaint dialog (contains history + reply box)
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: c)));
                        },
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