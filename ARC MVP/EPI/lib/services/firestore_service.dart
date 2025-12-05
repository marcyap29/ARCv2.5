// Firestore helper (template)
// Uncomment and adapt if Firestore is needed.

// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class FirestoreService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Future<void> setData(String collection, String docId, Map<String, dynamic> data) {
//     return _firestore.collection(collection).doc(docId).set(data);
//   }
//
//   Future<DocumentSnapshot<Map<String, dynamic>>> getData(String collection, String docId) {
//     return _firestore.collection(collection).doc(docId).get();
//   }
// }
