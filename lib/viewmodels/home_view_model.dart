import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/sensor_repository.dart';

class HomeViewModel extends ChangeNotifier {
  final SensorRepository repository;

  HomeViewModel(this.repository) {
    _listenToSensorData();
  }

  List<SensorData> sensorData = [];

  bool isLoading = true;
  String? errorMessage;

  StreamSubscription<List<SensorData>>? _subscription;

  void _listenToSensorData() {
    _subscription = repository.watchSensorData().listen(
      (data) {
        isLoading = false;
        errorMessage = null;

        sensorData = data;

        notifyListeners();
      },
      onError: (error) {
        isLoading = false;
        errorMessage = error.toString();

        notifyListeners();
      },
    );
  }

  SensorData? get latestData {
    if (sensorData.isEmpty) {
      return null;
    }

    return sensorData.first;
  }

  String get waktuTerakhir {
    final timestamp = latestData?.timestamp;

    if (timestamp == null) {
      return '-';
    }

    final dateTime = timestamp.toDate().toLocal();

    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}