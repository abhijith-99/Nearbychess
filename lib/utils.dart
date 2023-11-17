// utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> updateInGameState(bool isInGame) async {
  try {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    await users.doc(userId).update({'inGame': isInGame});
  } catch (e) {
    print('Error updating inGame status: $e');
  }
}
