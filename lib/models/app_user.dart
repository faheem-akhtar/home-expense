import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.householdId,
    required this.email,
  });

  final String uid;
  final String displayName;
  final String householdId;
  final String email;

  static AppUser? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null || m['householdId'] == null) return null;
    return AppUser(
      uid: doc.id,
      displayName: m['displayName'] as String? ?? 'Me',
      householdId: m['householdId'] as String,
      email: m['email'] as String? ?? '',
    );
  }
}
