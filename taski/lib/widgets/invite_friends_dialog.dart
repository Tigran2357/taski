import 'package:flutter/material.dart';
import 'package:taski/models/friend.dart';
import 'package:taski/services/friends_service.dart';
import 'package:taski/services/supabase_client.dart';

/// Lists the user's friends with an Invite button each, for adding them to a
/// public folder. Shown right after creating a public folder, and from a
/// folder's dropdown menu later on.
class InviteFriendsDialog extends StatefulWidget {
  final String folderId;
  const InviteFriendsDialog({super.key, required this.folderId});

  @override
  State<InviteFriendsDialog> createState() => _InviteFriendsDialogState();
}

class _InviteFriendsDialogState extends State<InviteFriendsDialog> {
  final _service = FriendsService();
  List<Friend> _friends = [];
  bool _loading = true;
  final Set<String> _invited = {}; // already have a pending invite
  final Set<String> _members = {}; // already in the folder

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Friends + who's already a member + who already has a pending invite.
      final friends = await _service.myFriends();
      final memberRows = await supabase
          .from('folder_members')
          .select('user_id')
          .eq('folder_id', widget.folderId);
      final inviteRows = await supabase
          .from('folder_invites')
          .select('receiver_id')
          .eq('folder_id', widget.folderId)
          .eq('status', 'pending');
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _members
          ..clear()
          ..addAll((memberRows as List).map((r) => r['user_id'] as String));
        _invited
          ..clear()
          ..addAll(
            (inviteRows as List).map((r) => r['receiver_id'] as String),
          );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite(Friend f) async {
    setState(() => _invited.add(f.userId));
    try {
      await _service.inviteToFolder(widget.folderId, f.username);
    } catch (e) {
      if (!mounted) return;
      setState(() => _invited.remove(f.userId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite friends'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _friends.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No friends yet. Add some from the Friends page.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final f in _friends)
                    ListTile(
                      title: Text(f.username),
                      trailing: _members.contains(f.userId)
                          ? const Text(
                              'Member',
                              style: TextStyle(color: Colors.grey),
                            )
                          : _invited.contains(f.userId)
                          ? const Text(
                              'Invited',
                              style: TextStyle(color: Colors.green),
                            )
                          : TextButton(
                              onPressed: () => _invite(f),
                              child: const Text('Invite'),
                            ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
