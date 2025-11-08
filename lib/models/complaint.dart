
class Complaint {
  int? id;
  int userId;
  String message;
  String status;
  String category;
  String? createdAt;
  String? updatedAt;

  Complaint({
    this.id,
    required this.userId,
    required this.message,
    this.status = 'pending',
    this.category= 'Autre',
    this.createdAt,
    this.updatedAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'message': message,
      'status': status,
      'category': category,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Complaint.fromMap(Map<String, dynamic> map) {
    return Complaint(
      id: map['id'],
      userId: map['user_id'],
      message: map['message'],
      status: map['status'],
      category: map['category'],
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
