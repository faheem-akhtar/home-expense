import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> authChanges() => _auth.authStateChanges();

  Stream<AppUser?> profile(String uid) =>
      _db.collection('users').doc(uid).snapshots().map(AppUser.fromDoc);

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  static const _defaultBuckets = [
    ('Groceries', '🛒', 2500),
    ('Sports & Padel', '🎾', 800),
    ('Dining', '🍽️', 1000),
    ('Retail & Shopping', '🛍️', 1000),
    ('Fuel', '⛽', 600),
  ];

  /// Creates a household with starter buckets. The household id doubles as
  /// the code the partner enters to join.
  Future<void> createHousehold({required String displayName, required String name}) async {
    final user = _auth.currentUser!;
    final ref = _db.collection('households').doc();
    await ref.set({
      'name': name,
      'members': [user.uid],
      'carryOver': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final batch = _db.batch();
    for (var i = 0; i < _defaultBuckets.length; i++) {
      final (bName, icon, budget) = _defaultBuckets[i];
      batch.set(ref.collection('buckets').doc(), {
        'name': bName,
        'icon': icon,
        'budget': budget,
        'order': i,
        'archived': false,
      });
    }
    batch.set(_db.collection('users').doc(user.uid), {
      'displayName': displayName,
      'householdId': ref.id,
      'email': user.email,
    });
    await batch.commit();
  }

  Future<void> joinHousehold({required String displayName, required String code}) async {
    final user = _auth.currentUser!;
    await _db.collection('households').doc(code.trim()).update({
      'members': FieldValue.arrayUnion([user.uid]),
    });
    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'householdId': code.trim(),
      'email': user.email,
    });
  }
}
