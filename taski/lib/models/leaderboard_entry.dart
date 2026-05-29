class LeaderboardEntry {
  final String userId;
  final String username;
  final int completedCount;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.completedCount,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
    userId: m['user_id'] as String,
    username: m['username'] as String,
    completedCount: (m['completed_count'] as num).toInt(),
  );
}
