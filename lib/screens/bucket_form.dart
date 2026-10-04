import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bucket.dart';

const _icons = [
  '🛒', '🎾', '🍽️', '🛍️', '⛽', '🏠', '💡', '🚗', '🎬', '✈️',
  '🏥', '💊', '👶', '🐶', '🎁', '📚', '☕', '💇', '📱', '💰',
];

/// Returns the edited bucket, or null if cancelled.
Future<Bucket?> showBucketForm(
  BuildContext context, {
  required String id,
  required int order,
  Bucket? existing,
}) {
  return showModalBottomSheet<Bucket>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BucketForm(id: id, order: order, existing: existing),
  );
}

class _BucketForm extends StatefulWidget {
  const _BucketForm({required this.id, required this.order, this.existing});

  final String id;
  final int order;
  final Bucket? existing;

  @override
  State<_BucketForm> createState() => _BucketFormState();
}

class _BucketFormState extends State<_BucketForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _budget = TextEditingController(
    text: widget.existing?.budget.toString().replaceFirst(RegExp(r'\.0$'), ''),
  );
  late String _icon = widget.existing?.icon ?? _icons.first;

  void _submit() {
    final name = _name.text.trim();
    final budget = double.tryParse(_budget.text.replaceAll(',', ''));
    if (name.isEmpty || budget == null || budget < 0) return;
    Navigator.pop(
      context,
      Bucket(id: widget.id, name: name, icon: _icon, budget: budget, order: widget.order),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'New bucket' : 'Edit bucket',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final icon in _icons)
                ChoiceChip(
                  label: Text(icon, style: const TextStyle(fontSize: 18)),
                  selected: icon == _icon,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _icon = icon),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Monthly budget', prefixText: 'AED '),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }
}
