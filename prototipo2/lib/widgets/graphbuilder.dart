import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphBuilder {
  // Método que construye los puntos del gráfico
  List<FlSpot> getGraphData(List<double> data) {
    return List.generate(
      data.length,
      (index) => FlSpot(index.toDouble(), data[index]),
    );
  }

  // Método que retorna el widget del gráfico
  Widget buildGraph(List<double> data, {Color color = Colors.blue}) {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: getGraphData(data),
              isCurved: false,
              dotData: const FlDotData(show: false),
              color: color,
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: const FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),

          /// 🔽 Habilita el tooltip interactivo
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    'x: ${spot.x.toStringAsFixed(2)}\ny: ${spot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              // Opcional: puedes hacer algo con los toques aquí
            },
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

}
