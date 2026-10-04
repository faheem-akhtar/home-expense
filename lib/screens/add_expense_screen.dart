import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/expense.dart';
import '../models/payment_method.dart';
import '../services/receipt_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

typedef _BucketChoice = ({String id, String name, String icon});

/// Quick entry (and edit) for an expense. Amount gets focus immediately, so
/// "+" → type amount → tap a bucket tile → Save.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.initialBucketId, this.existing});

  final String? initialBucketId;
  final Expense? existing;

  static Future<void> open(BuildContext context, {String? bucketId, Expense? existing}) {
    final state = context.read<AppState>();
    return Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: AddExpenseScreen(initialBucketId: bucketId, existing: existing),
      ),
    ));
  }

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _bucketId;
  PaymentMethod _method = PaymentMethod.primaryCard;
  File? _receipt;
  String? _existingReceiptUrl;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amount.text = e.amount.toString().replaceFirst(RegExp(r'\.0$'), '');
      _note.text = e.note;
      _bucketId = e.bucketId;
      _method = e.paymentMethod;
      _existingReceiptUrl = e.receiptUrl;
    } else {
      _bucketId = widget.initialBucketId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<_BucketChoice> _choices(AppState state) {
    final list = <_BucketChoice>[
      for (final s in state.statuses) (id: s.bucketId, name: s.name, icon: s.icon),
    ];
    final e = widget.existing;
    if (e != null && !list.any((c) => c.id == e.bucketId)) {
      list.insert(0, (id: e.bucketId, name: e.bucketName, icon: e.bucketIcon));
    }
    return list;
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (picked != null) setState(() => _receipt = File(picked.path));
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    final bucket = _choices(state).where((c) => c.id == _bucketId).firstOrNull;
    if (bucket == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a bucket')));
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final id = existing?.id ?? state.repo.newExpenseId();
      var receiptUrl = _existingReceiptUrl;
      if (_receipt != null) {
        receiptUrl = await ReceiptService.instance
            .upload(householdId: state.user.householdId, expenseId: id, file: _receipt!);
      } else if (existing?.receiptUrl != null && _existingReceiptUrl == null) {
        await ReceiptService.instance.delete(existing!.receiptUrl!);
      }

      final expense = Expense(
        id: id,
        amount: amount,
        bucketId: bucket.id,
        bucketName: bucket.name,
        bucketIcon: bucket.icon,
        paymentMethod: _method,
        note: _note.text.trim(),
        // Keep the original author and time when editing.
        userId: existing?.userId ?? state.user.uid,
        userName: existing?.userName ?? state.user.displayName,
        createdAt: existing?.createdAt ?? DateTime.now(),
        receiptUrl: receiptUrl,
        updatedByName: existing == null ? null : state.user.displayName,
      );
      // Not awaited: Firestore applies the write locally right away (so the
      // dashboard updates instantly) and syncs when online.
      state.repo.saveExpense(expense).catchError((Object e) {
        messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      });

      navigator.pop();
      _warnIfLow(state, messenger, expense);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Bucket dropped below 10% remaining → heads-up.
  void _warnIfLow(AppState state, ScaffoldMessengerState messenger, Expense saved) {
    if (saved.monthKey != state.monthKey) return;
    final status = state.statusFor(saved.bucketId);
    if (status == null || status.budget <= 0) return;
    final spentElsewhere = state.currentExpenses
        .where((e) => e.bucketId == saved.bucketId && e.id != saved.id)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final remaining = status.budget - spentElsewhere - saved.amount;
    if (remaining / status.budget < 0.10) {
      messenger.showSnackBar(SnackBar(
        content: Text(remaining < 0
            ? '${status.name} is over budget by ${aed(-remaining)}'
            : 'Only ${aed(remaining)} left in ${status.name}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final choices = _choices(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit expense' : 'Add expense'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amount,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(prefixText: 'AED ', hintText: '0'),
          ),
          const SizedBox(height: 20),
          Text('Bucket', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in choices)
                ChoiceChip(
                  avatar: Text(c.icon),
                  label: Text(c.name),
                  selected: c.id == _bucketId,
                  onSelected: (_) => setState(() => _bucketId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Paid with', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<PaymentMethod>(
            showSelectedIcon: false,
            segments: [
              for (final m in PaymentMethod.values)
                ButtonSegment(value: m, icon: Icon(m.icon), label: Text(m.label)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes / merchant (optional)',
              hintText: 'e.g. Playtomic, Nesto',
            ),
          ),
          if (receiptsEnabled) ...[
            const SizedBox(height: 20),
            _ReceiptPicker(
              file: _receipt,
              existingUrl: _existingReceiptUrl,
              onCamera: () => _pickReceipt(ImageSource.camera),
              onGallery: () => _pickReceipt(ImageSource.gallery),
              onRemove: () => setState(() {
                _receipt = null;
                _existingReceiptUrl = null;
              }),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.file,
    required this.existingUrl,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final File? file;
  final String? existingUrl;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget? preview = file != null
        ? Image.file(file!, height: 160, fit: BoxFit.cover)
        : existingUrl != null
            ? Image.network(existingUrl!, height: 160, fit: BoxFit.cover)
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt (optional)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (preview != null)
          Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: preview),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ],
          ),
      ],
    );
  }
}
