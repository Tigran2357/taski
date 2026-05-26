import 'package:flutter/material.dart';
import 'package:taski/services/auth_service.dart';

class NamePage extends StatefulWidget {
  /// Called after the name is saved, so the gate can re-check and move on.
  final VoidCallback onSaved;
  const NamePage({super.key, required this.onSaved});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _auth = AuthService();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.saveName(name);
      widget.onSaved();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not save your name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Almost there',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'What should we call you?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
