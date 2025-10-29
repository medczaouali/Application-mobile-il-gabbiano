import 'package:flutter/material.dart';
import '../../db/database_helper.dart';
import '../../models/feedbacks.dart' as model;
import '../../models/user.dart';

class FeedbacksScreen extends StatefulWidget {
  @override
  _FeedbacksScreenState createState() => _FeedbacksScreenState();
}

class _FeedbacksScreenState extends State<FeedbacksScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  late Future<List<model.Feedback>> _future;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _future = _db.getFeedback();
    _animController = AnimationController(vsync: this, duration: Duration(milliseconds: 600));
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _db.getFeedback();
    });
    // restart animation after refresh
    _animController.reset();
    _animController.forward();
  }

  Widget _starRow(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: size);
      }),
    );
  }

  Widget _buildHeader(double avg, int total) {
    final headerAnimation = CurvedAnimation(parent: _animController, curve: Interval(0.0, 0.35, curve: Curves.easeOut));

    return FadeTransition(
      opacity: headerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, 0.08), end: Offset.zero).animate(headerAnimation),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.white]),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.amber.shade100,
            child: Icon(Icons.star, color: Colors.amber.shade800, size: 36),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avis clients', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    SizedBox(width: 12),
                    _starRow(avg.round(), size: 20),
                    Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$total avis', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        SizedBox(height: 4),
                        Text(total == 0 ? '—' : '${(avg / 5 * 100).round()}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
    );
  }

  Widget _buildFeedbackCard(model.Feedback f) {
    return FutureBuilder<User?>(
      future: _db.getUserById(f.userId),
      builder: (context, snap) {
        final user = snap.data;
        String title = user?.name ?? 'Utilisateur #${f.userId}';
        String? image = user?.profileImage;

        // Each card will have its own small animation driven by the parent controller using an interval.
        // The start offset will be computed when the widget tree builds (index unknown here), so we use a
        // simple FadeTransition + SlideTransition wired to the same controller with a short interval.
        final anim = CurvedAnimation(parent: _animController, curve: Interval(0.35, 1.0, curve: Curves.easeOut));

        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, 0.04), end: Offset.zero).animate(anim),
            child: Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: image != null && image.isNotEmpty ? NetworkImage(image) as ImageProvider : null,
                      child: image == null || image.isEmpty ? Text(title.isNotEmpty ? title[0].toUpperCase() : '#', style: TextStyle(fontWeight: FontWeight.bold)) : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600))),
                              Text('ID ${f.userId}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 6),
                          _starRow(f.rating),
                          SizedBox(height: 8),
                          if (f.comment != null && f.comment!.isNotEmpty)
                            Text(f.comment!, style: TextStyle(color: Colors.grey[800]))
                          else
                            Text('Pas de commentaire', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Supprimer cet avis ?'),
                                      content: Text('Cette action est irréversible.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler')),
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _db.deleteFeedback(f.userId);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avis supprimé')));
                                    _refresh();
                                  }
                                },
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Avis et retours'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<List<model.Feedback>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          final items = snap.data ?? [];
          final total = items.length;
          final avg = total == 0 ? 0.0 : items.map((e) => e.rating).reduce((a, b) => a + b) / total;

          // start the animation once data is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_animController.isAnimating && _animController.value == 0.0) {
              _animController.forward();
            }
          });

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildHeader(avg, total),
                SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[300]),
                          SizedBox(height: 12),
                          Text('Aucun avis pour le moment.', style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ),
                  )
                else ...items.map((f) => _buildFeedbackCard(f)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}
