class FriendRequest {
  final String id;
  final String senderId;
  final String senderUsername;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.createdAt,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> m) => FriendRequest(
    id: m['id'] as String,
    senderId: m['sender_id'] as String,
    senderUsername: m['sender_username'] as String,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}
