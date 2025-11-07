import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/feedbacks.dart' as model;
import 'package:ilgabbiano/widgets/custom_app_bar.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  _FeedbackScreenState createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _rating = 0;
  late DatabaseHelper _dbHelper;
  int? _userId;
  model.Feedback? _existingFeedback;
  bool _isLoading = true;
  bool _isSubmitting = false;
  double _avgRating = 0.0;
  int _totalReviews = 0;
  List<Map<String, dynamic>> _allReviews = const [];

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
    final futures = <Future>[];
    if (_userId != null) {
      futures.add(_dbHelper.getFeedbackByUser(_userId!).then((feedback) {
        _existingFeedback = feedback;
        if (feedback != null) {
          _rating = feedback.rating.toDouble();
          _commentController.text = feedback.comment ?? '';
        }
      }));
    }
    futures.add(_dbHelper.getFeedbackAverage().then((m) {
      _avgRating = (m['average'] as double?) ?? 0.0;
      _totalReviews = (m['count'] as int?) ?? 0;
    }));
    futures.add(_dbHelper.getFeedbacksWithUsers().then((rows) {
      _allReviews = rows;
    }));
    await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      if (_userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('user_not_identified'))),
        );
        return;
      }
      if (_rating == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('select_rating'))),
        );
        return;
      }

      final feedback = model.Feedback(
        userId: _userId!,
        rating: _rating.toInt(),
        comment: _commentController.text,
      );

      setState(() => _isSubmitting = true);
      try {
        await _dbHelper.createOrUpdateFeedback(feedback);

        // Re-fetch updated feedback and refresh UI instead of navigating away
        final updated = await _dbHelper.getFeedbackByUser(_userId!);
        if (!mounted) return;
        setState(() {
          _existingFeedback = updated;
          if (updated != null) {
            _rating = updated.rating.toDouble();
            _commentController.text = updated.comment ?? '';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('thank_you_feedback'))),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  void _deleteFeedback() async {
    if (_userId == null || _existingFeedback == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('delete_feedback')),
        content: Text(AppLocalizations.of(context).t('delete_feedback_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).t('no'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context).t('yes'))),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteFeedback(_userId!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('complaint_deleted'))),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppLocalizations.of(context).t('rating_prompt'),
        actions: [
          if (_existingFeedback != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteFeedback,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Global average summary
                    _AverageHeader(avg: _avgRating, count: _totalReviews),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).t('rating_prompt'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() {
                              _rating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).t('comment_optional'),
                        hintText: AppLocalizations.of(context).t('comment_hint'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      child: _isSubmitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(_existingFeedback == null ? AppLocalizations.of(context).t('send') : AppLocalizations.of(context).t('update')),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Avis des clients', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ..._allReviews.map((row) {
                      final rating = (row['rating'] as int?) ?? 0;
                      final name = (row['user_name'] as String?) ?? 'Utilisateur';
                      final img = (row['user_profile_image'] as String?);
                      final comment = (row['comment'] as String?) ?? '';
                      return _ReviewCard(name: name, imagePath: img, rating: rating, comment: comment);
                    }).toList(),
                  ],
                ),
              ),
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
          Icon(Icons.star, color: Colors.amber, size: 36),
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

class _ReviewCard extends StatelessWidget {
  final String name;
  final String? imagePath;
  final int rating;
  final String comment;
  const _ReviewCard({required this.name, required this.imagePath, required this.rating, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: (imagePath != null && imagePath!.isNotEmpty)
                  ? (imagePath!.startsWith('http') ? NetworkImage(imagePath!) : FileImage(File(imagePath!)) as ImageProvider)
                  : null,
              child: (imagePath == null || imagePath!.isEmpty) ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16)),
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(comment),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
