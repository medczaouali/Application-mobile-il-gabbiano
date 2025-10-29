import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/feedbacks.dart' as model;
import 'package:ilgabbiano/widgets/custom_app_bar.dart';

class FeedbackScreen extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
    if (_userId != null) {
      final feedback = await _dbHelper.getFeedbackByUser(_userId!);
      setState(() {
        _existingFeedback = feedback;
        if (feedback != null) {
          _rating = feedback.rating.toDouble();
          _commentController.text = feedback.comment ?? '';
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
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
                    Text(
                      AppLocalizations.of(context).t('rating_prompt'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 18),
                    ),
                    SizedBox(height: 10),
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
                    SizedBox(height: 20),
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
                    SizedBox(height: 20),
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
                  ],
                ),
              ),
            ),
    );
  }
}
