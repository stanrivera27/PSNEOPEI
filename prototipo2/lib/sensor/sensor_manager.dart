import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../sensor/data/sensor_processor.dart';

class SensorManager {
  // Datos del sensor
  final DataProcessor dataProcessor;
  double accX = 0.0, accY = 0.0, accZ = 0.0;
  double accMagnitude = 0.0;
  double gyroX = 0.0, gyroY = 0.0, gyroZ = 0.0;
  double gyroMagnitude = 0.0;
  double frequency = 0;
  bool isRunning = false;
  int sampleCount = 0;


  final Duration sensorInterval = const Duration(milliseconds: 20);
  StreamSubscription<AccelerometerEvent>? _accSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  late Timer _timer;

  // 👉 Callback para notificar a la UI
  final VoidCallback onUpdate;

  SensorManager({required this.onUpdate,required this.dataProcessor}) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isRunning) {
        frequency = sampleCount.toDouble();
        sampleCount = 0;
        onUpdate(); // 👉 Llama a setState()
      }
    });
  }

  void startSensors() {
    _accSubscription = accelerometerEventStream(samplingPeriod: sensorInterval).listen(
      (event) {
        accX = event.x;
        accY = event.y;
        accZ = event.z;
        accMagnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.81;
        dataProcessor.addAccelerometer(accMagnitude, frequency);
        sampleCount++;
        onUpdate();
      },
    );

    _gyroSubscription = gyroscopeEventStream(samplingPeriod: sensorInterval).listen(
      (event) {
        gyroX = event.x;
        gyroY = event.y;
        gyroZ = event.z;
        gyroMagnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        onUpdate();
      },
    );
  }

  void stopSensors() {
    _accSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accSubscription = null;
    _gyroSubscription = null;
  }

  void toggleSensors() {
    if (isRunning) {
      stopSensors();
    } else {
      dataProcessor.gyroMagnitudeList.clear();
      dataProcessor.accMagnitudeListDesfasada.clear();
      dataProcessor.historialFiltrado.clear();
      dataProcessor.indiceInicio = 0;
      dataProcessor.index = 0;
      dataProcessor.unionCrucesPicosVallesListTotal.clear();
      dataProcessor.unionCrucesPicosVallesListFiltradoTotal.clear();
      dataProcessor.matrizordenada.clear();
      dataProcessor.matrizordenada1.clear();
      dataProcessor.matrizordenada2.clear();
      dataProcessor.unionordenadoList.clear();
      dataProcessor.unionordenadoList1.clear();
      dataProcessor.unionordenadoListfil.clear();
      dataProcessor.unionordenadoListfil1.clear();
      dataProcessor.unionordenadoListfil2.clear();
      dataProcessor.unionordenadoListdef.clear();
      dataProcessor.unionordenadoListdef1.clear();
      dataProcessor.unionordenadoListdef2.clear();
      dataProcessor.matrizSecuenciasrevisar.clear();
      dataProcessor.unionFiltradorecortadoTotal.clear();
      dataProcessor.pasosPorVentana.clear();
      dataProcessor.tiempoDePasosList.clear();
      dataProcessor.matrizUltimosDatos = List.generate(5, (_) => List.filled(4, 0.0));
      dataProcessor.matrizordenadatotal = [[], [], []];
      
      startSensors();
    }
    isRunning = !isRunning;
    onUpdate();
  }

  void dispose() {
    _timer.cancel();
    stopSensors();
  }
}
