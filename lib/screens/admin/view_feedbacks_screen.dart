import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/feedbacks.dart' as model;
import 'package:ilgabbiano/models/user.dart';

class ViewFeedbacksScreen extends StatefulWidget {
  @override
  _ViewFeedbacksScreenState createState() => _ViewFeedbacksScreenState();
}

class _ViewFeedbacksScreenState extends State<ViewFeedbacksScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _feedbacksFuture;

  @override
  void initState() {
    super.initState();
    _feedbacksFuture = _loadFeedbacks();
  }

  Future<List<Map<String, dynamic>>> _loadFeedbacks() async {
    final feedbacks = await _dbHelper.getFeedback();
    final List<Map<String, dynamic>> feedbackDetails = [];
    for (var feedback in feedbacks) {
      final user = await _dbHelper.getUserById(feedback.userId);
      feedbackDetails.add({'feedback': feedback, 'user': user});
    }
    return feedbackDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Avis des Clients')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _feedbacksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucun avis pour le moment.'));
          }
          final feedbackItems = snapshot.data!;
          return ListView.builder(
            itemCount: feedbackItems.length,
            itemBuilder: (context, index) {
              final model.Feedback feedback = feedbackItems[index]['feedback'];
              final User? user = feedbackItems[index]['user'];
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  leading: user?.profileImage != null && user!.profileImage!.isNotEmpty
                      ? CircleAvatar(
                          backgroundColor: Colors.transparent,
              backgroundImage: user.profileImage!.startsWith('http')
                ? CachedNetworkImageProvider(user.profileImage!) as ImageProvider
                : FileImage(File(user.profileImage!)),
                        )
                      : CircleAvatar(child: Text(user?.name.isNotEmpty == true ? user!.name[0] : '?')),
                  title: Text(user?.name ?? 'Utilisateur inconnu'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < feedback.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        )),
                      ),
                      if (feedback.comment != null && feedback.comment!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(feedback.comment!),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
