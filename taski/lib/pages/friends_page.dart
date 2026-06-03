import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taski/models/folder_invite.dart';
import 'package:taski/models/friend_request.dart';
import 'package:taski/models/leaderboard_entry.dart';
import 'package:taski/services/friends_service.dart';
import 'package:taski/services/supabase_client.dart';
import 'package:taski/widgets/theme_toggle.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _service = FriendsService();
  bool _hasPending = false;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    try {
      final items = await _service.pending();
      if (!mounted) return;
      setState(() => _hasPending = items.isNotEmpty);
    } catch (_) {
      // Ignore; the Requests tab will reload on its own.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const ThemeToggleTap(
            child: Text(
              'Friends',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Add'),
              const Tab(text: 'Leaderboard'),
              Tab(
                child: Badge(
                  isLabelVisible: _hasPending,
                  backgroundColor: Colors.green,
                  smallSize: 8,
                  alignment: AlignmentDirectional.topEnd,
                  offset: const Offset(10, -2),
                  child: const Text('Requests'),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _AddFriendTab(),
            const _LeaderboardTab(),
            _RequestsTab(onPendingChanged: (n) {
              if (!mounted) return;
              setState(() => _hasPending = n > 0);
            }),
          ],
        ),
      ),
    );
  }
}

// =================== Add ===================

class _AddFriendTab extends StatefulWidget {
  const _AddFriendTab();
  @override
  State<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<_AddFriendTab> {
  final _service = FriendsService();
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _friendly(Object e) {
    if (e is PostgrestException) {
      final m = e.message;
      if (m.contains('user_not_found')) return 'No user with that username.';
      if (m.contains('self_request')) return 'You can\'t add yourself.';
      if (m.contains('already_friends')) return 'You\'re already friends.';
      if (m.contains('request_exists')) return 'Request already sent.';
    }
    return 'Could not send request. Try again.';
  }

  Future<void> _send() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Enter a username.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await _service.sendRequest(username);
      if (!mounted) return;
      _ctrl.clear();
      setState(() => _info = 'Request sent to "$username".');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add a friend by username',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: 'Username'),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_info != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_info!, style: const TextStyle(color: Colors.green)),
            ),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send request'),
          ),
        ],
      ),
    );
  }
}

// =================== Requests ===================

class _RequestsTab extends StatefulWidget {
  final void Function(int count) onPendingChanged;
  const _RequestsTab({required this.onPendingChanged});
  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  final _service = FriendsService();
  List<FriendRequest> _items = [];
  List<FolderInvite> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _total => _items.length + _invites.length;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.pending(),
        _service.pendingFolderInvites(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<FriendRequest>;
        _invites = results[1] as List<FolderInvite>;
      });
      widget.onPendingChanged(_total);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(FriendRequest r) async {
    await _service.accept(r.id);
    if (!mounted) return;
    setState(() => _items.remove(r));
    widget.onPendingChanged(_total);
  }

  Future<void> _decline(FriendRequest r) async {
    await _service.decline(r.id);
    if (!mounted) return;
    setState(() => _items.remove(r));
    widget.onPendingChanged(_total);
  }

  Future<void> _acceptInvite(FolderInvite inv) async {
    await _service.acceptFolderInvite(inv.id);
    if (!mounted) return;
    setState(() => _invites.remove(inv));
    widget.onPendingChanged(_total);
  }

  Future<void> _declineInvite(FolderInvite inv) async {
    await _service.declineFolderInvite(inv.id);
    if (!mounted) return;
    setState(() => _invites.remove(inv));
    widget.onPendingChanged(_total);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_total == 0) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('No incoming requests.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Folder invites first.
          for (final inv in _invites)
            Card(
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(
                  inv.folderName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${inv.senderUsername} invited you to this folder'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptInvite(inv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _declineInvite(inv),
                    ),
                  ],
                ),
              ),
            ),
          // Then friend requests.
          for (final r in _items)
            Card(
              child: ListTile(
                title: Text(
                  r.senderUsername,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('wants to be your friend'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _accept(r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _decline(r),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =================== Leaderboard ===================

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();
  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  final _service = FriendsService();
  String _range = 'day';
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.leaderboard(_range);
      if (!mounted) return;
      setState(() => _entries = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRemove(LeaderboardEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove friend ${entry.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.removeFriend(entry.userId);
    if (!mounted) return;
    setState(() => _entries.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('Day')),
              ButtonSegment(value: 'week', label: Text('Week')),
            ],
            selected: {_range},
            onSelectionChanged: (s) {
              setState(() => _range = s.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? const Center(child: Text('No data yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final isMe = e.userId == myId;
                      final card = Card(
                        color: isMe
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(
                            isMe ? '${e.username} (you)' : e.username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            '${e.completedCount} done',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                      // Long-press only on friends, not yourself.
                      return isMe
                          ? card
                          : GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => _confirmRemove(e),
                              child: card,
                            );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
