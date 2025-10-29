class Reservation {
  int? id;
  final int userId;
  final String date;
  final String time;
  final int people;
  final String? notes;
  String status;

  Reservation({
    this.id,
    required this.userId,
    required this.date,
    required this.time,
    required this.people,
    this.notes,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'time': time,
      'guests': people,
      'notes': notes,
      'status': status,
    };
  }

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      userId: map['user_id'],
      date: map['date'],
      time: map['time'],
      people: map['guests'],
      notes: map['notes'],
      status: map['status'],
    );
  }
}
