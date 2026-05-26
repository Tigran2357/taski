import 'package:flutter/material.dart';

/// Collects a start time and a finish duration, returning the resulting
/// (start, end) window via [Navigator.pop]. Returns null on cancel.
class TimerSetupDialog extends StatefulWidget {
  const TimerSetupDialog({super.key});

  @override
  State<TimerSetupDialog> createState() => _TimerSetupDialogState();
}

class _TimerSetupDialogState extends State<TimerSetupDialog> {
  bool _startNow = true;
  DateTime? _startAt;
  final _hoursCtrl = TextEditingController(text: '0');
  final _minutesCtrl = TextEditingController(text: '25');
  String? _error;

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final hours = int.tryParse(_hoursCtrl.text.trim()) ?? 0;
    final minutes = int.tryParse(_minutesCtrl.text.trim()) ?? 0;
    final duration = Duration(hours: hours, minutes: minutes);
    if (duration <= Duration.zero) {
      setState(() => _error = 'Set a finish time greater than zero.');
      return;
    }
    if (!_startNow && _startAt == null) {
      setState(() => _error = 'Pick a start date and time.');
      return;
    }
    final start = _startNow ? DateTime.now() : _startAt!;
    final end = start.add(duration);
    Navigator.pop(context, (start: start, end: end));
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start now'),
            value: _startNow,
            onChanged: (v) => setState(() => _startNow = v),
          ),
          if (!_startNow)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start at'),
              subtitle: Text(
                _startAt == null ? 'Pick date & time' : _fmt(_startAt!),
              ),
              trailing: const Icon(Icons.event),
              onTap: _pickStart,
            ),
          const SizedBox(height: 8),
          const Text('Finish within'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hoursCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hours'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Start')),
      ],
    );
  }
}
