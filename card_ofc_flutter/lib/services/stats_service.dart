class StatsService {
  static final StatsService _instance = StatsService._();
  factory StatsService() => _instance;
  StatsService._();

  int gamesPlayed = 0;
  int gamesWon = 0;
  int totalScore = 0;
  int fantasylandCount = 0;
  int scoopCount = 0;
  int foulCount = 0;

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed * 100 : 0;

  void recordGameResult({
    required bool won,
    required int score,
    required int fantasylands,
    required int scoops,
    required int fouls,
  }) {
    gamesPlayed++;
    if (won) gamesWon++;
    totalScore += score;
    fantasylandCount += fantasylands;
    scoopCount += scoops;
    foulCount += fouls;
  }

  Map<String, dynamic> toMap() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'winRate': winRate.toStringAsFixed(1),
        'totalScore': totalScore,
        'fantasylandCount': fantasylandCount,
        'scoopCount': scoopCount,
        'foulCount': foulCount,
      };
}
