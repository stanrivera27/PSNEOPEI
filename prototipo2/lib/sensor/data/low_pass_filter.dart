import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';

/// Filtro FIR pasabajas
List<double> applyFirLowpassFilter({
  required List<double> signal,
  required double cutoffHz,
  required double fs,
  int numTaps = 50,
}) {
  double nyq = fs / 2;
  double normalCutoff = cutoffHz / nyq;

  // Coeficientes del filtro
  Array b = firwin(numTaps, Array([normalCutoff]));

  // Aplicar filtro
  Array filtered = lfilter(b, Array([1.0]), Array(signal));

  return filtered.toList();
}
