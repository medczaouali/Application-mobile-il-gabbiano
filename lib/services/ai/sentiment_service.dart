import 'dart:math';

class SentimentResult {
  final String label; // 'positive' | 'neutral' | 'negative'
  final double score; // -1.0 .. 1.0
  final int priority; // 0 low, 1 medium, 2 high (for sorting)

  const SentimentResult({required this.label, required this.score, required this.priority});
}

class SentimentService {
  static final List<String> _negativeWordsList = [
    // English
    'bad','terrible','awful','horrible','disgusting','angry','furious','worst','hate','problem','issue','complaint','delay','late','dirty','cold','raw','rude','slow','never','again','broken','refund','scam','cheat','liar','liars','disappointed','disappointing','unacceptable','noisy','smell','stink','disgust','cold','burnt','overcooked',
    // French
    'mauvais','horrible','terrible','dégoûtant','énervé','furieux','pire','haine','problème','retard','sale','froid','cru','impoli','lent','jamais','remboursement','arnaque','menteur','menteurs','déçu','décevant','inacceptable','bruyant','odeur','pue','brûlé','trop cuit',
    // Italian
    'cattivo','terribile','orribile','schifoso','arrabbiato','furioso','peggio','odio','problema','ritardo','sporco','freddo','crudo','maleducato','lento','mai','rimborso','truffa','bugiardo','deluso','deludente','inaccettabile','rumoroso','puzza','bruciato','scotto',
    // Spanish/Portuguese (basic)
    'malo','terrible','horrible','asqueroso','enojado','furioso','peor','odio','problema','retraso','sucio','frio','crudo','grosero','lento','reembolso','estafa','mentiroso','decepcionado','inaceptable','ruidoso','apestoso','queimado','cru','lento',
    // German (basic)
    'schlecht','schrecklich','furchtbar','ekelhaft','wütend','zornig','schlimmste','hasse','problem','verspätung','schmutzig','kalt','roh','unhöflich','langsam','nie','rückerstattung','betrug','lügner','enttäuscht','inakzeptabel','laut','stinkt','verbrannt','zerkocht',
  ];
  static final Set<String> _negativeWords = _negativeWordsList.toSet();

  static final List<String> _urgentWordsList = [
    // English
    'now','immediately','asap','urgent','right now','at once','straight away',
    // French
    'maintenant','immédiatement','urgent','tout de suite','au plus vite','rapidement',
    // Italian
    'adesso','subito','urgente','immediatamente','al più presto',
    // Spanish/Portuguese
    'ahora','inmediatamente','urgente','ya','de inmediato','lo antes posible','agora','imediatamente',
    // German
    'jetzt','sofort','dringend','unverzüglich',
  ];
  static final Set<String> _urgentWords = _urgentWordsList.toSet();

  SentimentResult analyze(String text) {
    if (text.trim().isEmpty) return const SentimentResult(label: 'neutral', score: 0.0, priority: 0);

    final lower = text.toLowerCase();

    // Heuristics
    final exclamations = RegExp(r'!').allMatches(text).length;
    final allCapsWords = RegExp(r'\b[A-ZÄÖÜ]{3,}\b').allMatches(text).length;
    final words = RegExp(r"[\p{L}']+", unicode: true).allMatches(lower).map((m) => m.group(0)!).toList();
    int negHits = 0;
    int urgentHits = 0;
    for (final w in words) {
      if (_negativeWords.contains(w)) negHits++;
      if (_urgentWords.contains(w)) urgentHits++;
    }

    // Base score from negative hits
    double score = 0.0;
    score -= min(1.0, negHits / 5.0);

    // Penalize exclamation and caps
    score -= min(0.6, exclamations * 0.1);
    score -= min(0.4, allCapsWords * 0.1);

    // Urgency increases priority (without making score more negative than -1)
    final urgencyBoost = min(0.3, urgentHits * 0.15);
    score = max(-1.0, score - urgencyBoost * 0.0); // keep sentiment unchanged, urgency tracked via priority only

    String label;
    if (score <= -0.35) {
      label = 'negative';
    } else if (score >= 0.35) {
      label = 'positive';
    } else {
      label = 'neutral';
    }

    // Priority: negative and/or urgent => higher
    int priority = 0;
    if (label == 'negative') priority = 1;
    if (label == 'negative' && (exclamations >= 2 || negHits >= 2 || urgentHits >= 1)) priority = 2;

    return SentimentResult(label: label, score: score, priority: priority);
  }
}
