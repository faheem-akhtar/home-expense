import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bucket.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import 'bucket_form.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final household = state.household;
    final buckets = state.buckets;
    final templateTotal = buckets.fold<double>(0, (s, b) => s + b.budget);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            title: Text('Buckets', style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('Monthly total ${aed(templateTotal)}. '
                'Changes apply to this month and every month after.'),
            trailing: IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () => _edit(context, state, null),
            ),
          ),
          if (buckets.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) => _reorder(state, from, to),
              children: [
                for (var i = 0; i < buckets.length; i++)
                  ListTile(
                    key: ValueKey(buckets[i].id),
                    leading: Text(buckets[i].icon, style: const TextStyle(fontSize: 24)),
                    title: Text(buckets[i].name),
                    subtitle: Text(aed(buckets[i].budget)),
                    onTap: () => _edit(context, state, buckets[i]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, state, buckets[i]),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Carry over unspent balances'),
            subtitle: const Text(
                'On the 1st, money left in a bucket is added to next month. Off = start fresh.'),
            value: household?.carryOver ?? false,
            onChanged: household == null ? null : state.repo.setCarryOver,
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(state.user.displayName),
            subtitle: Text(state.user.email),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Household code'),
            subtitle: SelectableText(state.user.householdId),
            trailing: const Icon(Icons.copy),
            onTap: () {
              Clipboard.setData(ClipboardData(text: state.user.householdId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied. Your partner enters it when setting up.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: AuthService.instance.signOut,
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppState state, Bucket? existing) async {
    final nextOrder = state.buckets.isEmpty ? 0 : state.buckets.last.order + 1;
    final bucket = await showBucketForm(
      context,
      id: existing?.id ?? state.repo.newBucketId(),
      order: existing?.order ?? nextOrder,
      existing: existing,
    );
    if (bucket != null) state.repo.saveBucket(bucket, currentMonthKey: state.monthKey);
  }

  void _reorder(AppState state, int from, int to) {
    final list = [...state.buckets];
    list.insert(to, list.removeAt(from));
    for (var i = 0; i < list.length; i++) {
      final b = list[i];
      if (b.order == i) continue;
      state.repo.saveBucket(
        Bucket(id: b.id, name: b.name, icon: b.icon, budget: b.budget, order: i),
        currentMonthKey: state.monthKey,
      );
    }
  }

  Future<void> _delete(BuildContext context, AppState state, Bucket bucket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${bucket.name}?'),
        content: const Text('It is removed from this month onward. '
            'Expenses already logged stay in history and reports.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) state.repo.deleteBucket(bucket.id, currentMonthKey: state.monthKey);
  }
}
