class Friend {
  final String userId;
  final String username;

  Friend({required this.userId, required this.username});

  factory Friend.fromMap(Map<String, dynamic> m) => Friend(
    userId: m['user_id'] as String,
    username: m['username'] as String,
  );
}
