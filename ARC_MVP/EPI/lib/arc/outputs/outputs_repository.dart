// lib/arc/outputs/outputs_repository.dart
//
// Phase 5a: Firestore read/write for Outputs (users/{userId}/outputs/{itemId}).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/services/firebase_auth_service.dart';

import 'outputs_models.dart';

class OutputsRepository {
  OutputsRepository._();
  static final OutputsRepository instance = OutputsRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _outputsCol(String userId) {
    return _firestore.collection('users').doc(userId).collection('outputs');
  }

  Future<String> _currentUserId() async {
    final uid = FirebaseAuthService.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('User not signed in');
    return uid;
  }

  /// Save or update an output item. If [item].id is empty, creates a new doc.
  Future<OutputItem> save(OutputItem item) async {
    final userId = await _currentUserId();
    final col = _outputsCol(userId);
    final data = item.toFirestore();

    if (item.id.isEmpty) {
      final ref = await col.add(data);
      return OutputItem.fromFirestore(ref.id, data);
    }
    await col.doc(item.id).set(data, SetOptions(merge: true));
    return item;
  }

  /// Update only userTags for an item.
  Future<void> updateUserTags(String itemId, List<String> userTags) async {
    final userId = await _currentUserId();
    await _outputsCol(userId).doc(itemId).update({'userTags': userTags});
  }

  /// Delete an output item.
  Future<void> delete(String itemId) async {
    final userId = await _currentUserId();
    await _outputsCol(userId).doc(itemId).delete();
  }

  /// Stream all output items for the current user.
  Stream<List<OutputItem>> streamItems() async* {
    final userId = await _currentUserId();
    yield* _outputsCol(userId).snapshots().map((snap) {
      return snap.docs
          .map((d) => OutputItem.fromFirestore(d.id, d.data()))
          .toList();
    });
  }

  /// One-time fetch of all output items.
  Future<List<OutputItem>> getItems() async {
    final userId = await _currentUserId();
    final snap = await _outputsCol(userId).get();
    return snap.docs
        .map((d) => OutputItem.fromFirestore(d.id, d.data()))
        .toList();
  }

  /// Get a single item by id.
  Future<OutputItem?> getItem(String itemId) async {
    final userId = await _currentUserId();
    final doc = await _outputsCol(userId).doc(itemId).get();
    if (doc.data() == null) return null;
    return OutputItem.fromFirestore(doc.id, doc.data()!);
  }
}
