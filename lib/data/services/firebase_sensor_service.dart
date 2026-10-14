import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseSensorService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSensorData() {
    return _firestore
        .collection('ph-activity')
        .orderBy('timestamp', descending: true)
        .limit(60)
        .snapshots();
  }
}