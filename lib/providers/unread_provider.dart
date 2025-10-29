import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';

/// Tracks unread message counts for complaints for the current user.
class UnreadProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  // A global instance fallback to allow safe calls when Provider lookup fails
  // (e.g., during early startup or when widget contexts are outside the provider tree).
  static UnreadProvider? _globalInstance;

  UnreadProvider() {
    _globalInstance = this;
  }

  /// Global accessor for the provider instance. May be null if the provider
  /// hasn't been constructed yet.
  static UnreadProvider? get instance => _globalInstance;

  int? _userId;
  // complaintId -> unread count
  final Map<int, int> _counts = {};

  /// Initialize provider for a user and fetch current unread counts.
  Future<void> init(int userId) async {
    _userId = userId;
    await refreshAll();
  }

  /// Reset provider state (used on logout).
  void reset() {
    _userId = null;
    _counts.clear();
    notifyListeners();
  }

  /// Refresh unread counts for all complaints of the current user.
  Future<void> refreshAll() async {
    if (_userId == null) return;
    try {
      final complaints = await _db.getComplaintsByUser(_userId!);
      for (final c in complaints) {
        try {
          final cnt = await _db.getUnreadMessagesCount(c.id!, _userId!);
          _counts[c.id!] = cnt;
        } catch (e) {
          // If DB query fails (old DB or migration in progress), treat as 0
          _counts[c.id!] = 0;
        }
      }
      notifyListeners();
    } catch (e) {
      // ignore errors - keep previous counts
    }
  }

  /// Called when realtime events arrive. [event] is expected to contain
  /// keys 'complaintId' and 'unread'. We update cached counts accordingly.
  void onRealtimeEvent(Map<String, dynamic> event) {
    final id = event['complaintId'];
    final unread = event['unread'];
    if (id is int) {
      _counts[id] = (unread is int) ? unread : (_counts[id] ?? 0);
      notifyListeners();
    }
  }

  /// Get unread count for a single complaint.
  int getCountForComplaint(int? complaintId) {
    if (complaintId == null) return 0;
    return _counts[complaintId] ?? 0;
  }

  /// Total unread across all tracked complaints.
  int get totalUnread => _counts.values.fold(0, (p, e) => p + e);

  /// Mark a complaint as read locally (sets count to 0) and optionally refresh DB.
  Future<void> markComplaintRead(int complaintId, {bool refreshDb = false}) async {
    _counts[complaintId] = 0;
    notifyListeners();
    if (refreshDb && _userId != null) {
      await refreshAll();
    }
  }

  /// Safe static helper to mark a complaint read using the global instance
  /// if available. This avoids throwing LookupFailed when Provider isn't
  /// accessible from the current BuildContext.
  static Future<void> safeMarkComplaintRead(int complaintId, {bool refreshDb = false}) async {
    final inst = _globalInstance;
    if (inst != null) {
      await inst.markComplaintRead(complaintId, refreshDb: refreshDb);
    }
  }
}
