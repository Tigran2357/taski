class FolderEvent {
  final String id;
  final String folderId;
  final String username;
  final String type; // 'joined' | 'left'
  final DateTime? createdAt;

  FolderEvent({
    required this.id,
    required this.folderId,
    required this.username,
    required this.type,
    this.createdAt,
  });

  String get label => type == 'left' ? '$username left' : '$username joined';

  factory FolderEvent.fromMap(Map<String, dynamic> m) => FolderEvent(
    id: m['id'] as String,
    folderId: m['folder_id'] as String,
    username: m['username'] as String,
    type: m['type'] as String,
    createdAt: m['created_at'] == null
        ? null
        : DateTime.parse(m['created_at'] as String).toLocal(),
  );
}
