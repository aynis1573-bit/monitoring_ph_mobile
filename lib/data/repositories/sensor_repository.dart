import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_sensor_service.dart';

class SensorData {
  final dynamic ph;
  final dynamic deviceId;
  final dynamic location;
  final Timestamp? timestamp;

  SensorData({
    required this.ph,
    required this.deviceId,
    required this.location,
    required this.timestamp,
  });
}

class SensorRepository {
  final FirebaseSensorService service;

  SensorRepository(this.service);

  Stream<List<SensorData>> watchSensorData() {
    return service.watchSensorData().map((snapshot) {
      return snapshot.docs.map((document) {
        final data = document.data();

        return SensorData(
          ph: data['ph'],
          deviceId: data['deviceId'],
          location: data['location'],
          timestamp: data['timestamp'] is Timestamp
              ? data['timestamp'] as Timestamp
              : null,
        );
      }).toList();
    });
  }
}