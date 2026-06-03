class FolderInvite {
  final String id;
  final String folderId;
  final String folderName;
  final String senderUsername;
  final DateTime createdAt;

  FolderInvite({
    required this.id,
    required this.folderId,
    required this.folderName,
    required this.senderUsername,
    required this.createdAt,
  });

  factory FolderInvite.fromMap(Map<String, dynamic> m) => FolderInvite(
    id: m['id'] as String,
    folderId: m['folder_id'] as String,
    folderName: m['folder_name'] as String,
    senderUsername: m['sender_username'] as String,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}
