class Feedback {
  final int? id;
  final int userId;
  final int rating;
  final String? comment;

  Feedback({this.id, required this.userId, required this.rating, this.comment});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
    };
  }

  factory Feedback.fromMap(Map<String, dynamic> map) {
    return Feedback(
      id: map['id'],
      userId: map['user_id'],
      rating: map['rating'],
      comment: map['comment'],
    );
  }
}
