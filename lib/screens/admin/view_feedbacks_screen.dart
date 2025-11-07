import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewFeedbacksScreen extends StatefulWidget {
  const ViewFeedbacksScreen({super.key});
  @override
  _ViewFeedbacksScreenState createState() => _ViewFeedbacksScreenState();
}

class _ViewFeedbacksScreenState extends State<ViewFeedbacksScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<void> _loadFuture;
  List<Map<String, dynamic>> _rows = const [];
  double _avg = 0.0;
  int _count = 0;
  final TextEditingController _search = TextEditingController();
  String _starsFilter = 'all'; // all,4+,3+,2+,1

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    final agg = await _dbHelper.getFeedbackAverage();
    final rows = await _dbHelper.getFeedbacksWithUsers();
    setState(() {
      _avg = (agg['average'] as double?) ?? 0.0;
      _count = (agg['count'] as int?) ?? 0;
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Avis des Clients')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (_rows.isEmpty) {
            return Center(child: Text('Aucun avis pour le moment.'));
          }
          // apply filters
          final s = _search.text.trim().toLowerCase();
          List<Map<String, dynamic>> data = _rows.where((r) {
            bool ok = true;
            if (s.isNotEmpty) {
              final name = (r['user_name'] as String? ?? '').toLowerCase();
              final c = (r['comment'] as String? ?? '').toLowerCase();
              ok = name.contains(s) || c.contains(s);
            }
            final rating = (r['rating'] as int?) ?? 0;
            switch (_starsFilter) {
              case '4+':
                ok = ok && rating >= 4;
                break;
              case '3+':
                ok = ok && rating >= 3;
                break;
              case '2+':
                ok = ok && rating >= 2;
                break;
              case '1':
                ok = ok && rating == 1;
                break;
              default:
                break;
            }
            return ok;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AverageHeader(avg: _avg, count: _count),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Rechercher par nom ou commentaire',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              suffixIcon: _search.text.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() {}); })
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: _starsFilter,
                          onChanged: (v) => setState(() => _starsFilter = v ?? 'all'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tous')),
                            DropdownMenuItem(value: '4+', child: Text('≥ 4 étoiles')),
                            DropdownMenuItem(value: '3+', child: Text('≥ 3 étoiles')),
                            DropdownMenuItem(value: '2+', child: Text('≥ 2 étoiles')),
                            DropdownMenuItem(value: '1', child: Text('1 étoile')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final r = data[index];
                    final rating = (r['rating'] as int?) ?? 0;
                    final name = (r['user_name'] as String?) ?? 'Utilisateur';
                    final img = (r['user_profile_image'] as String?);
                    final comment = (r['comment'] as String?) ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: img != null && img.isNotEmpty
                            ? CircleAvatar(
                                backgroundColor: Colors.transparent,
                                backgroundImage: img.startsWith('http')
                                    ? CachedNetworkImageProvider(img) as ImageProvider
                                    : FileImage(File(img)),
                              )
                            : CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                        title: Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16)),
                            ),
                            if (comment.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(comment),
                              ),
                          ],
                        ),
                        // Suppression désactivée côté admin: pas d'action destructive ici
                      ),
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

class _AverageHeader extends StatelessWidget {
  final double avg;
  final int count;
  const _AverageHeader({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final display = (avg.isNaN ? 0.0 : avg).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$display / 5', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('$count avis au total', style: GoogleFonts.lato(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
