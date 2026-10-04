import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ReceiptService {
  ReceiptService._();
  static final instance = ReceiptService._();

  final _storage = FirebaseStorage.instance;

  Future<String> upload({
    required String householdId,
    required String expenseId,
    required File file,
  }) async {
    final ref = _storage.ref('households/$householdId/receipts/$expenseId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> delete(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Best-effort: a missing receipt shouldn't block deleting an expense.
    }
  }
}
