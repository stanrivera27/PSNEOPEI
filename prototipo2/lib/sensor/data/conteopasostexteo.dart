import 'fusion_y_acortamiento_datos.dart';

class ConteoPasosTexteando {
  final acortamientoDatos = ProcesamientoEventos();
  void procesar(
    List<List<double>> matrizOrdenada,
    List<List<double>> matrizUltimosDatos,
    List<List<double>> matrizSecuenciasRevisar,
    List<double> unionFiltradoRecortadoTotal,
    int ventanaTiempo,
  ) {
    if (matrizOrdenada.isEmpty || matrizOrdenada[0].isEmpty) return;

    final n = matrizOrdenada[0].length + 4;
    List<List<double>> matrizDatosExtendida = List.generate(3, (_) => List.filled(n, 0.0));

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        matrizDatosExtendida[j][i] = matrizUltimosDatos[j][i];
      }
    }

    for (int i = 4; i < n; i++) {
      for (int j = 0; j < 3; j++) {
        final indexOrigen = i - 4;
        if (indexOrigen < matrizOrdenada[j].length) {
          matrizDatosExtendida[j][i] = matrizOrdenada[j][indexOrigen];
        }
      }
    }

    final (simbolosFilt, magnitudesFilt, tiemposFilt) = acortamientoDatos.filtrarSimbolosCero(
      matrizDatosExtendida[0],
      matrizDatosExtendida[1],
      matrizDatosExtendida[2],
    );

    final matrizDatosAcortada = acortamientoDatos.procesarSimbolosConsecutivos(
      simbolosFilt,
      magnitudesFilt,
      tiemposFilt,
    );

    final totalFilas = matrizDatosAcortada[0].length;
    if (totalFilas < 4) {
      int faltan = 4 - totalFilas;
      for (int i = 0; i < 4; i++) {
        if (i < faltan) {
          matrizUltimosDatos[0][i] = 0;
          matrizUltimosDatos[1][i] = 0;
          matrizUltimosDatos[2][i] = 0;
        } else {
          int indice = i - faltan;
          matrizUltimosDatos[0][i] = matrizDatosAcortada[0][indice];
          matrizUltimosDatos[1][i] = matrizDatosAcortada[1][indice];
          matrizUltimosDatos[2][i] = (ventanaTiempo - matrizDatosAcortada[2][indice]) * -1;
        }
      }
    } else {
      for (int i = 0; i < 4; i++) {
        matrizUltimosDatos[0][i] = matrizDatosAcortada[0][totalFilas - 4 + i];
        matrizUltimosDatos[1][i] = matrizDatosAcortada[1][totalFilas - 4 + i];
        matrizUltimosDatos[2][i] = (ventanaTiempo - matrizDatosAcortada[2][totalFilas - 4 + i]) * -1;
      }
    }

    unionFiltradoRecortadoTotal.addAll(matrizDatosAcortada[0]);
    unionFiltradoRecortadoTotal.add(0.0);

    if (matrizDatosAcortada[0].length < 5) return;

    int filasM = matrizDatosAcortada[0].length - 4;
    int contadorPasos = 0;
    int indicadorPaso = matrizUltimosDatos[3][0].toInt();

    for (int i = 0; i < filasM; i++) {
      List<double> secuencia = [
        matrizDatosAcortada[0][i],
        matrizDatosAcortada[0][i + 1],
        matrizDatosAcortada[0][i + 2],
        matrizDatosAcortada[0][i + 3],
        matrizDatosAcortada[0][i + 4],
      ];

      matrizSecuenciasRevisar.add(List.from(secuencia));

      if (secuencia[0] == 1 && secuencia[2] == 1 && secuencia[4] == 1) {
        if ((secuencia[1] == 2 && secuencia[3] == 3) ||
            (secuencia[1] == 3 && secuencia[3] == 2)) {
          matrizUltimosDatos[3][3] =
              matrizDatosAcortada[2][i + 4] - matrizDatosAcortada[2][i];
          matrizUltimosDatos[4][contadorPasos] =
              matrizDatosAcortada[2][i + 4] - matrizDatosAcortada[2][i];

          if (secuencia[1] == 2 && secuencia[3] == 3) {
            if (indicadorPaso == 0) {
              indicadorPaso = 1;
              matrizUltimosDatos[3][0] = 1.0;
            }
            if (indicadorPaso == 1) contadorPasos++;
          }

          if (secuencia[1] == 3 && secuencia[3] == 2) {
            if (indicadorPaso == 0) {
              indicadorPaso = 2;
              matrizUltimosDatos[3][0] = 2.0;
            }
            if (indicadorPaso == 2) contadorPasos++;
          }
        }
      }
    }

    matrizUltimosDatos[3][1] = contadorPasos.toDouble();
    matrizUltimosDatos[3][2] += contadorPasos.toDouble();
  }
}
