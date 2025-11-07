import 'dart:math';

enum ModerationAction { safe, review, block }

class ModerationResult {
  final ModerationAction action;
  final int severity; // 0..6
  const ModerationResult(this.action, this.severity);
}

/// Lightweight, offline heuristics for basic text moderation.
/// Can later be swapped or extended with a cloud service.
class ContentModerationService {
  static final _badWords = <String>{
    // EN/FR/IT/ES/DE/PT common profanity (light list; not exhaustive)
    'fuck', 'shit', 'bitch', 'asshole', 'bastard',
    'pute', 'merde', 'connard', 'enculé',
    'cazzo', 'stronzo', 'merda',
    'mierda', 'gilipollas',
    'scheiße', 'arschloch',
  'porra', 'caralho',
  };

  static final _aggressiveTone = RegExp(r"(!{3,}|\b(stupid|idiot|hate)\b)", caseSensitive: false);
  static final _emojiSpam = RegExp(r"[\u{1F600}-\u{1F64F}]{4,}", unicode: true);

  Future<ModerationResult> moderateText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return const ModerationResult(ModerationAction.safe, 0);

    final lower = t.toLowerCase();
    int severity = 0;

    // profanity
    for (final w in _badWords) {
      if (lower.contains(w)) {
        severity = max(severity, 4);
      }
    }

    // aggressive tone / shouting
    if (_aggressiveTone.hasMatch(lower)) {
      severity = max(severity, 3);
    }

    // emoji spam
    if (_emojiSpam.hasMatch(t)) {
      severity = max(severity, 2);
    }

    if (severity >= 4) return const ModerationResult(ModerationAction.block, 4);
    if (severity >= 2) return ModerationResult(ModerationAction.review, severity);
    return const ModerationResult(ModerationAction.safe, 0);
  }
}
