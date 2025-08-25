import 'dart:math';
import 'low_pass_filter.dart';
import 'clasificador_de_datos.dart';
import 'fusion_y_acortamiento_datos.dart';
import 'conteopasostexteo.dart';
class DataProcessor {
  final ConteoPasosTexteando conteoPasos = ConteoPasosTexteando();
  final _acortaFusionaDatos = ProcesamientoEventos();
  List<double> accMagnitudeList = List.filled(50000, 0.0);
  List<double> gyroMagnitudeList = [];
  List<double> accMagnitudeListDesfasada = [];
  List<double> ventanaAccXYZ = [];
  List<double> ventanaAccXYZdesfasada = [];
  List<double> datosFiltrados = [];
  int ventanaTiempo = 52; // Tamaño de la ventana en muestras
  int lateralVentana = 26; // Lateral de la ventana (muestras a la izquierda y derecha)
  int indiceInicio = 0; // Índice de inicio para la ventana
  int index = 0;
  double umbralPico = 0.7;
  double umbralPicoSinFiltrar = 1.2; // Umbral para detección de picos
  double umbralValle = -0.4;
  double umbralValleSinFiltrar = -0.6; // Umbral para detección de cruces por cero  
  
  bool inicioAnalisis2 = false;
  bool inicioAnalisis3 = false;
  bool inicioAnalisis4 = false;
  bool inicioAnalisis5 = false;
  bool inicioAnalisis6 = false;
  bool inicioAnalisis7 = false;
  bool inicioAnalisis8 = false;
  bool inicioAnalisis9 = false;

  List<double> historialFiltrado = [];
  List<double> crucesPorCeroList = [];
  List<double> crucesPorCeroListFiltrado = [];
  List<double> picosList = [];
  List<double> picosListFiltrado = [];
  List<double> vallesList = [];
  List<double> vallesListFiltrado = [];
  List<double> unionCrucesPicosVallesList = [];
  List<double> unionCrucesPicosVallesListFiltrado = [];
  List<double> unionCrucesPicosVallesListTotal = [];
  List<double> unionCrucesPicosVallesListFiltradoTotal = [];

  List<List<double>> matrizordenada = [[],[],[]];
  List<List<double>> matrizordenada1 = [[],[],[]];
  List<List<double>> matrizordenada2 = [[],[],[]];
  List<double> unionordenadoList = [];
  List<double> unionordenadoList1 = [];
  List<double> unionordenadoList2 = [];
  List<double> unionordenadoListfil = [];
  List<double> unionordenadoListfil1 = [];
  List<double> unionordenadoListfil2 = [];
  List<double> unionordenadoListdef = [];
  List<double> unionordenadoListdef1 = [];
  List<double> unionordenadoListdef2 = [];
  List<List<double>> matrizUltimosDatos = List.generate(5, (_) => List.filled(4, 0.0));
  List<List<double>> matrizSecuenciasrevisar = [];
  List<double> unionFiltradorecortadoTotal = [];
  List<int> pasosPorVentana = [];
  List<double> tiempoDePasosList = [];
  List<List<double>> matrizordenadatotal = [[], [], []];

  
  void addAccelerometer(double magnitude, double frequency) {
    int inicio = indiceInicio == 0 ? 0 : lateralVentana;
    int fin = inicio + ventanaTiempo;  
    if (index <50000){
      accMagnitudeList[index] = magnitude;
      index++;
    }
    bool ready = (indiceInicio + ventanaTiempo + lateralVentana <= index);
    if (ready) {
      ventanaAccXYZ = accMagnitudeList.sublist(
        max(0, indiceInicio - lateralVentana),
        indiceInicio + ventanaTiempo + lateralVentana,
      );
      if (indiceInicio == 0) {
        List<double> inicioDesfase = [...List.filled(25, 0.0), ...ventanaAccXYZ];
        ventanaAccXYZdesfasada = inicioDesfase.sublist(
          max(0, indiceInicio - lateralVentana),
          indiceInicio + ventanaTiempo + lateralVentana,
        );
      } else {
        ventanaAccXYZdesfasada = accMagnitudeList.sublist(
          max(0, indiceInicio - lateralVentana - 25),
          indiceInicio + ventanaTiempo + lateralVentana - 25,
        );
      }
      accMagnitudeListDesfasada.addAll(ventanaAccXYZdesfasada.sublist(inicio, fin));
      inicioAnalisis2 = true;
      indiceInicio += ventanaTiempo;
    }
    if (inicioAnalisis2) {
      datosFiltrados = applyFirLowpassFilter(
        signal: ventanaAccXYZ,
        cutoffHz: 4,
        fs: frequency,
      );
      

      historialFiltrado.addAll(datosFiltrados.sublist(inicio, fin));
      
      inicioAnalisis2 = false;
      inicioAnalisis3 = true;
    }
    if (inicioAnalisis3) {
      crucesPorCeroList = AnalizadorDeSenales.crucesPorCero(ventanaAccXYZdesfasada.sublist(inicio,fin), ventanaTiempo, lateralVentana);
      crucesPorCeroListFiltrado = AnalizadorDeSenales.crucesPorCero(datosFiltrados.sublist(inicio,fin), ventanaTiempo, lateralVentana);
      inicioAnalisis3 = false;
      inicioAnalisis4 = true;
    }
    if (inicioAnalisis4) {
      picosList = AnalizadorDeSenales.deteccionPicos(ventanaAccXYZdesfasada.sublist(inicio,fin), umbralPicoSinFiltrar);
      picosListFiltrado = AnalizadorDeSenales.deteccionPicos(datosFiltrados.sublist(inicio,fin), umbralPico);
      inicioAnalisis4 = false;
      inicioAnalisis5 = true;
    }
    if (inicioAnalisis5) {
      vallesList = AnalizadorDeSenales.deteccionValles(ventanaAccXYZdesfasada.sublist(inicio,fin), umbralValleSinFiltrar);
      vallesListFiltrado = AnalizadorDeSenales.deteccionValles(datosFiltrados.sublist(inicio,fin), umbralValle);
      inicioAnalisis5 = false;
      inicioAnalisis6 = true;
    }
    if (inicioAnalisis6) {
      unionCrucesPicosVallesList = AnalizadorDeSenales.unionCrucesPicosValles(crucesPorCeroList, picosList, vallesList);
      unionCrucesPicosVallesListFiltrado = AnalizadorDeSenales.unionCrucesPicosValles(crucesPorCeroListFiltrado, picosListFiltrado, vallesListFiltrado);
      unionCrucesPicosVallesListTotal.addAll(unionCrucesPicosVallesList);
      unionCrucesPicosVallesListFiltradoTotal.addAll(unionCrucesPicosVallesListFiltrado);
      inicioAnalisis6 = false;
      inicioAnalisis7 = true;
    }
    if (inicioAnalisis7) {
      matrizordenada = _acortaFusionaDatos.matrizAcortada(unionCrucesPicosVallesListFiltrado, datosFiltrados.sublist(inicio,fin));
      matrizordenada1 = _acortaFusionaDatos.matrizAcortada(unionCrucesPicosVallesList, ventanaAccXYZdesfasada.sublist(inicio,fin));
      _acortaFusionaDatos.fusionMatricesAcortadas(unionCrucesPicosVallesList, ventanaAccXYZdesfasada.sublist(inicio,fin),unionCrucesPicosVallesListFiltrado, datosFiltrados.sublist(inicio,fin),matrizordenada2);
      unionordenadoListfil.addAll(matrizordenada[0]);
      unionordenadoListfil1.addAll(matrizordenada[1]);
      unionordenadoListfil2.addAll(matrizordenada[2]);
      unionordenadoList.addAll(matrizordenada1[0]);
      unionordenadoList1.addAll(matrizordenada1[1]);
      unionordenadoList2.addAll(matrizordenada1[2]);
      unionordenadoListdef.addAll(matrizordenada2[0]);
      unionordenadoListdef1.addAll(matrizordenada2[1]);
      unionordenadoListdef2.addAll(matrizordenada2[2]);
      inicioAnalisis7 = false;
      inicioAnalisis8 = true;
    }
    if (inicioAnalisis8){
      for (int i = 0; i < 3; i++) {
        matrizordenadatotal[i].addAll(matrizordenada2[i]);
      }
      inicioAnalisis8 = false;
      inicioAnalisis9 = true;
    }
    if (inicioAnalisis9) {
      conteoPasos.procesar(matrizordenada2, matrizUltimosDatos, matrizSecuenciasrevisar, unionFiltradorecortadoTotal,ventanaTiempo);
      pasosPorVentana.add(matrizUltimosDatos[3][1].toInt());
      for (int i = 0; i < matrizUltimosDatos[3][1]; i++) {
        tiempoDePasosList.add(matrizUltimosDatos[4][i]);
      }
      inicioAnalisis9 = false;
    }


  }
  
}
