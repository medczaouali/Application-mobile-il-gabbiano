import 'dart:async';
import '../db/database_helper.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Timer? _timer;
  int? _userId;

  void start(int userId, {Duration interval = const Duration(seconds: 10)}) {
    _userId = userId;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_userId == null) return;
    final db = DatabaseHelper();
    try {
      // naive approach: get all complaints for user and check unread counts
      final complaints = await db.getComplaintsByUser(_userId!);
      for (final c in complaints) {
        try {
          final unread = await db.getUnreadMessagesCount(c.id!, _userId!);
          if (unread > 0) {
            _controller.add({'complaintId': c.id, 'unread': unread});
          }
        } catch (e) {
          // ignore individual complaint errors but continue polling other complaints
          continue;
        }
      }
    } catch (e) {
      // If DB is temporarily unavailable or a migration hasn't completed,
      // swallow the error to keep the timer running. The DB helper will
      // attempt migrations on open.
    }
  }
}
