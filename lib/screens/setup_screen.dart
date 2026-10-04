import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// First-run profile: pick a display name, then create a household or join
/// your partner's with their household code.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _household = TextEditingController(text: 'Our Home');
  final _code = TextEditingController();
  bool _join = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (_join && _code.text.trim().isEmpty) {
      setState(() => _error = 'Enter the household code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_join) {
        await AuthService.instance.joinHousehold(displayName: _name.text.trim(), code: _code.text);
      } else {
        await AuthService.instance
            .createHousehold(displayName: _name.text.trim(), name: _household.text.trim());
      }
    } catch (e) {
      setState(() => _error = _join ? 'Could not join. Check the code and try again.' : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _household.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: AuthService.instance.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              helperText: 'Shown in the history, e.g. "Faheem added AED 120"',
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('New household')),
              ButtonSegment(value: true, label: Text('Join partner')),
            ],
            selected: {_join},
            onSelectionChanged: (s) => setState(() => _join = s.first),
          ),
          const SizedBox(height: 16),
          if (_join)
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Household code',
                helperText: 'Your partner can find it under Settings',
              ),
            )
          else
            TextField(
              controller: _household,
              decoration: const InputDecoration(labelText: 'Household name'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_join ? 'Join' : 'Create'),
          ),
        ],
      ),
    );
  }
}
