import 'package:taski/models/folder_invite.dart';
import 'package:taski/models/friend.dart';
import 'package:taski/models/friend_request.dart';
import 'package:taski/models/leaderboard_entry.dart';
import 'package:taski/services/supabase_client.dart';

/// Thin wrapper around the friend-related RPCs. Each call goes through a
/// security-definer Postgres function so other users' rows in `users` are
/// never exposed directly to the client.
class FriendsService {
  Future<void> sendRequest(String username) async {
    await supabase.rpc(
      'send_friend_request',
      params: {'p_username': username},
    );
  }

  Future<List<FriendRequest>> pending() async {
    final rows = await supabase.rpc('pending_friend_requests');
    return (rows as List)
        .map((r) => FriendRequest.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> accept(String id) async {
    await supabase.rpc('accept_friend_request', params: {'p_id': id});
  }

  Future<void> decline(String id) async {
    await supabase.rpc('decline_friend_request', params: {'p_id': id});
  }

  Future<void> removeFriend(String userId) async {
    await supabase.rpc('remove_friend', params: {'p_user_id': userId});
  }

  /// [range] = 'day' or 'week'.
  Future<List<LeaderboardEntry>> leaderboard(String range) async {
    final rows = await supabase.rpc('leaderboard', params: {'p_range': range});
    return (rows as List)
        .map((r) => LeaderboardEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ---------------- Public-folder invites ----------------

  Future<List<Friend>> myFriends() async {
    final rows = await supabase.rpc('my_friends');
    return (rows as List)
        .map((r) => Friend.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> inviteToFolder(String folderId, String username) async {
    await supabase.rpc(
      'invite_to_folder',
      params: {'p_folder_id': folderId, 'p_username': username},
    );
  }

  Future<List<FolderInvite>> pendingFolderInvites() async {
    final rows = await supabase.rpc('pending_folder_invites');
    return (rows as List)
        .map((r) => FolderInvite.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptFolderInvite(String id) async {
    await supabase.rpc('accept_folder_invite', params: {'p_id': id});
  }

  Future<void> declineFolderInvite(String id) async {
    await supabase.rpc('decline_folder_invite', params: {'p_id': id});
  }
}
