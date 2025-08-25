import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const DStarMapApp());
}

class DStarMapApp extends StatelessWidget {
  const DStarMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba plano D* Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home:  MapScreen(),
    );
  }
}
 