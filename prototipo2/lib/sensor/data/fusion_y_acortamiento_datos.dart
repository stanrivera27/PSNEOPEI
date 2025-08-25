class ProcesamientoEventos {
  
  /// Devuelve la matriz acortada con procesamiento completo
  List<List<double>> matrizAcortada(
      List<double> unionCrucesPicosVallesList, List<double> ventana) {
    List<double> indices =
        List.generate(unionCrucesPicosVallesList.length, (index) => index.toDouble());

    final (simbolosFiltrados, magnitudesFiltradas, tiemposFiltrados) =
        filtrarSimbolosCero(unionCrucesPicosVallesList, ventana, indices);

    final datosProcesados =
        procesarSimbolosConsecutivos(simbolosFiltrados, magnitudesFiltradas, tiemposFiltrados);

    return _filtrarCrucesConsecutivos(datosProcesados);
  }

  /// Elimina los ceros
  (List<double>, List<double>, List<double>) filtrarSimbolosCero(
      List<double> simbolosList, List<double> magnitudesList, List<double> tiemposList) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltradas = <double>[];
    final tiemposFiltrados = <double>[];

    for (int i = 0; i < simbolosList.length; i++) {
      if (simbolosList[i] != 0) {
        simbolosFiltrados.add(simbolosList[i]);
        magnitudesFiltradas.add(magnitudesList[i]);
        tiemposFiltrados.add(tiemposList[i]);
      }
    }

    return (simbolosFiltrados, magnitudesFiltradas, tiemposFiltrados);
  }

  /// Procesa símbolos consecutivos para reducir duplicados
  List<List<double>> procesarSimbolosConsecutivos(
      List<double> simbolosFiltrados,
      List<double> magnitudesFiltradas,
      List<double> tiemposFiltrados) {
    final datosProcesados = [
      <double>[], // símbolos
      <double>[], // magnitudes
      <double>[], // tiempos
    ];

    int? simboloActual;
    double? mejorMagnitud;
    double? mejorTiempo;

    for (int i = 0; i < simbolosFiltrados.length; i++) {
      final simbolo = simbolosFiltrados[i].toInt();
      final magnitud = magnitudesFiltradas[i];
      final tiempo = tiemposFiltrados[i];

      if (simbolo != simboloActual) {
        if (simboloActual != null && simboloActual != 1) {
          datosProcesados[0].add(simboloActual.toDouble());
          datosProcesados[1].add(mejorMagnitud!);
          datosProcesados[2].add(mejorTiempo!);
        }

        simboloActual = simbolo;

        if (simbolo == 1) {
          datosProcesados[0].add(1.0);
          datosProcesados[1].add(magnitud);
          datosProcesados[2].add(tiempo);
          simboloActual = null;
        } else {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        }
      } else {
        if (simbolo == 2 && magnitud > mejorMagnitud!) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        } else if (simbolo == 3 && magnitud < mejorMagnitud!) {
          mejorMagnitud = magnitud;
          mejorTiempo = tiempo;
        }
      }
    }

    if (simboloActual != null && simboloActual != 1) {
      datosProcesados[0].add(simboloActual.toDouble());
      datosProcesados[1].add(mejorMagnitud!);
      datosProcesados[2].add(mejorTiempo!);
    }

    return datosProcesados;
  }

  /// Filtra los cruces consecutivos, dejando solo casos válidos
  List<List<double>> _filtrarCrucesConsecutivos(List<List<double>> datosCrudos) {
    final simbolosFiltrados = <double>[];
    final magnitudesFiltrados = <double>[];
    final tiemposFiltrados = <double>[];

    int i = 0;
    while (i < datosCrudos[0].length) {
      final simbolo = datosCrudos[0][i];

      if (simbolo == 1) {
        int count = 1;
        while (i + count < datosCrudos[0].length && datosCrudos[0][i + count] == 1) {
          count++;
        }

        if (count == 2) {
          simbolosFiltrados.add(1.0);
          magnitudesFiltrados.add(datosCrudos[1][i]);
          tiemposFiltrados.add(datosCrudos[2][i]);
        } else {
          for (int k = 0; k < count; k++) {
            simbolosFiltrados.add(1.0);
            magnitudesFiltrados.add(datosCrudos[1][i + k]);
            tiemposFiltrados.add(datosCrudos[2][i + k]);
          }
        }
        i += count;
      } else {
        simbolosFiltrados.add(simbolo);
        magnitudesFiltrados.add(datosCrudos[1][i]);
        tiemposFiltrados.add(datosCrudos[2][i]);
        i++;
      }
    }

    return [simbolosFiltrados, magnitudesFiltrados, tiemposFiltrados];
  }

  /// Fusiona dos matrices acortadas: original y filtrada
  void fusionMatricesAcortadas(
    List<double> unionCrucesPicosVallesList,
    List<double> ventana,
    List<double> unionCrucesPicosVallesListFiltrado,
    List<double> ventanaFiltrada,
    List<List<double>> matrizAcortadaOrdenada,
  ) {
    final matrizOriginal = matrizAcortada(unionCrucesPicosVallesList, ventana);
    final matrizFiltrada = matrizAcortada(unionCrucesPicosVallesListFiltrado, ventanaFiltrada);

    final simbolosFusionados = <double>[];
    final magnitudesFusionadas = <double>[];
    final tiemposFusionados = <double>[];

    final mapaTemporalOriginal = <double, int>{};
    for (int i = 0; i < matrizOriginal[0].length; i++) {
      mapaTemporalOriginal[matrizOriginal[2][i]] = i;
    }

    for (int i = 0; i < matrizFiltrada[0].length; i++) {
      final simbolo = matrizFiltrada[0][i];
      final tiempoFiltrado = matrizFiltrada[2][i];

      if (simbolo == 1) {
        simbolosFusionados.add(1.0);
        magnitudesFusionadas.add(matrizFiltrada[1][i]);
        tiemposFusionados.add(matrizFiltrada[2][i]);
        continue;
      }

      if (simbolo == 2 || simbolo == 3) {
        double? mejorTiempo;
        double mejorDistancia = 5.1;

        for (final tiempoOriginal in mapaTemporalOriginal.keys) {
          if (matrizOriginal[0][mapaTemporalOriginal[tiempoOriginal]!] == simbolo) {
            final distancia = (tiempoOriginal - tiempoFiltrado).abs();
            if (distancia <= 5 && distancia < mejorDistancia) {
              mejorDistancia = distancia;
              mejorTiempo = tiempoOriginal;
            }
          }
        }

        if (mejorTiempo != null) {
          final idx = mapaTemporalOriginal[mejorTiempo]!;
          simbolosFusionados.add(simbolo);
          magnitudesFusionadas.add(matrizOriginal[1][idx]);
          tiemposFusionados.add(matrizOriginal[2][idx]);
        } else {
          simbolosFusionados.add(simbolo);
          magnitudesFusionadas.add(matrizFiltrada[1][i]);
          tiemposFusionados.add(tiempoFiltrado);
        }
      }
    }

    matrizAcortadaOrdenada
      ..clear()
      ..add(simbolosFusionados)
      ..add(magnitudesFusionadas)
      ..add(tiemposFusionados);
  }
}
