import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:taski/models/leaderboard_entry.dart';

/// End-of-week celebration: how many tasks you completed last week, last week's
/// leaderboard, and a confetti burst on open.
class WeeklySummaryDialog extends StatefulWidget {
  final int myCount;
  final List<LeaderboardEntry> entries;
  final String? myId;
  const WeeklySummaryDialog({
    super.key,
    required this.myCount,
    required this.entries,
    required this.myId,
  });

  @override
  State<WeeklySummaryDialog> createState() => _WeeklySummaryDialogState();
}

class _WeeklySummaryDialogState extends State<WeeklySummaryDialog> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top5 = widget.entries.take(5).toList();
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Text(
                  '${widget.myCount} Tasks',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('completed!', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                const Text(
                  "this week's Leaderboard",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (top5.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No activity last week.'),
                  )
                else
                  ...List.generate(top5.length, (i) {
                    final e = top5[i];
                    final isMe = e.userId == widget.myId;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(
                        isMe ? '${e.username} (you)' : e.username,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text('${e.completedCount}'),
                    );
                  }),
              ],
            ),
          ),
        ),
        // Confetti bursts outward from the top center.
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          maxBlastForce: 20,
          minBlastForce: 8,
          emissionFrequency: 0.05,
          numberOfParticles: 25,
          gravity: 0.25,
          colors: const [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
            Colors.amber,
          ],
        ),
      ],
    );
  }
}
