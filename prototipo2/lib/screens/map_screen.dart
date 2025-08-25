import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/node.dart';
import 'dart:math';
import '../algorithms/d_star_lite.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;

//para trabajar con .json
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/poi.dart';

//para unificar con cesar
import '../sensor/data/conteopasostexteo.dart';
import '../sensor/sensor_manager.dart';
import '../sensor/data/sensor_processor.dart';
import '../widgets/graphbuilder.dart';
import '../sensor/guardar/savedata.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Nuevas variables
  LatLng? startPoint; //punto de inicio
  LatLng? goalPoint; //punto destino
  bool selectingStart = true; //bandera para seleccionar el punto de inicio o destino
  // Nuevas variables
  // final int numRows = 800; //filas
  // final int numCols = 800; //columnas
  // Cambio para grilla cuadrada sin deformar mapa
  // Tamaño de la grilla (filas fijas, columnas se calculan)
  static const int kNumRows = 400;
  late int numRows;   // = kNumRows (se asigna en _recomputeGridMetrics)
  late int numCols;   // se calcula para que las celdas sean cuadradas
  late double latStep; // tamaño de celda en latitud
  late double lngStep; // tamaño de celda en longitud (igual a latStep)

  void _recomputeGridMetrics() {
    numRows = kNumRows;

    final latSpan = endBounds.latitude - startBounds.latitude;
    final lngSpan = endBounds.longitude - startBounds.longitude;

    // Hacemos celdas cuadradas usando el paso de latitud
    latStep = latSpan / numRows;
    lngStep = latStep;

    // Ajustamos columnas para cubrir el ancho sin salirnos del plano
    numCols = (lngSpan / lngStep).floor(); // usa floor para no pasar el borde o .round() para cubrir hasta endBounds
  }

  //para seguir posicion  
  LatLng? _currentPosition;// Posición a  actual del usuario (fijada al seleccionar el inicio)
  
  double _deviceAngle = 0.0; //angulo de rotacion en radianes
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  AccelerometerEvent? _accelData;
  MagnetometerEvent? _magData;
  
  late List<List<Node>> grid;
  
  Set<Point<int>> obstacles = {};

  final MapController _mapController = MapController();
  // Aquí se almacenará la ruta calculada
  List<LatLng> path = [];

  LatLng startBounds = LatLng(6.241, -75.589); // esquina inferior izquierda
  LatLng endBounds = LatLng(6.242, -75.587); // esquina superior derecha

  List<POI> pointsOfInterest = []; // Todos los POIs desde el JSON
  List<POI> visiblePOIs = []; //Lista de POIS cercanos a la ruta

  //Proyecto cesar
  late final SensorManager _sensorManager;
  late final DataProcessor _dataProcessor;
  final GraphBuilder _graphBuilder = GraphBuilder();
  bool showgraph = false;

  //para cuadros de texto
  final int _stepCount = 0;
  final double _distanceMeters = 0.0;
  final bool _isCountingSteps = false;

  @override
  void initState() {
    super.initState();
    _recomputeGridMetrics();
    grid = List.generate(
      numRows,
      (row) => List.generate(numCols, (col) => Node(row: row, col: col)),
    );
    loadObstacles(); //llama a cargar obstaculos
    loadPOIsFromJson(); //llama a cargar POIS

    //Proyecto Cesar
    _dataProcessor = DataProcessor();
    _sensorManager = SensorManager(onUpdate: _onSensorDataUpdate,dataProcessor: _dataProcessor);  // Pasamos el callback
  }

  //Proyecto Cesar
  @override
  void dispose() {
    _sensorManager.dispose();
    super.dispose();
  }
  // Esta función se llama cada vez que hay una actualización en los sensores
  void _onSensorDataUpdate() {
    setState(() {});  // Llamamos a setState para redibujar la UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planta 3 FIET - PSNEOPEC'),
      ),
      body: Stack(
        children: [
          RepaintBoundary(
          child : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (startBounds.latitude + endBounds.latitude) / 2,
                (startBounds.longitude + endBounds.longitude) / 2,
              ),
              initialZoom: 18,
              onTap: (tapPosition, latlng) {
                if (selectingStart) {
                  setState(() {
                    startPoint = latlng;
                    selectingStart = false;
                    _currentPosition = latlng;
                  });
                  _startCompassTracking();
                } else {
                  setState(() {
                    goalPoint = latlng;
                    selectingStart = true;
                  });
                  if (startPoint != null) {
                    Future.microtask(() => calculatePath());
                  }
                }
              },
              onLongPress: (tapPosition, latlng) {
                toggleObstacle(latlng);
              },
            ),
            children: [
              // Imagen del plano
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(startBounds, endBounds),
                    opacity: 1,
                    imageProvider: AssetImage('assets/planta1.jpg'),
                  ),
                ],
              ),

              // Marcadores (puntos start, goal y posicion)
              MarkerLayer(
                markers: [
                  if (startPoint != null)
                    Marker(
                      point: startPoint!,
                      width: 40,
                      height: 40,
                      child:  const Icon(Icons.location_on, color: Colors.green, size: 50,),
                    ),
                  if (goalPoint != null)
                    Marker(
                      point: goalPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: Colors.red, size: 50,),
                    ),

                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: RepaintBoundary(
                        child: Transform.rotate(
                          angle: -_deviceAngle, // rota según orientación apuntando siempre al norte
                          child: Icon(
                            Icons.navigation, // ícono de flecha estilo brújula
                            color: Colors.blue,
                            size: 48,
                          ),
                        ),
                      )
                      
                    ),

                ],
              ),

              PolygonLayer(
                polygons: [
                  for (int row = 0; row < numRows; row++)
                    for (int col = 0; col < numCols; col++)
                      Polygon(
                        points: getCellPolygon(row, col),
                        //borderColor: Colors.purple.withOpacity(0.3),
                        //borderStrokeWidth: 0.3,
                        color: Colors.transparent,
                      ),
                  if (startPoint != null)
                    Polygon(
                      points: getCellPolygon(
                        latLngToGrid(startPoint!).x,
                        latLngToGrid(startPoint!).y,
                      ),
                      borderColor: Colors.green,
                      //color: Colors.green.withOpacity(0.3),
                      //borderStrokeWidth: 2,
                    ),
                  if (goalPoint != null)
                    Polygon(
                      points: getCellPolygon(
                        latLngToGrid(goalPoint!).x,
                        latLngToGrid(goalPoint!).y,
                      ),
                      borderColor: Colors.red,
                      //color: Colors.red.withOpacity(0.3),
                      //borderStrokeWidth: 2,
                    ),
                ],
              ),

              //bloquear y desbloquear celdas
              MarkerLayer(
                markers: obstacles.map((point) {
                  final node = grid[point.x][point.y];
                  final latlng = gridToLatLng(node);
                  return Marker(
                    point: latlng,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        //color: Colors.black.withOpacity(0.5), //color bloqueos contorno nodo
                        shape: BoxShape.rectangle,
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Polilínea (ruta)
              PolylineLayer(
                polylineCulling: false,
                polylines: [
                  Polyline(
                    points: path.length > 1 ? path : [],
                    //color: Colors.blue,
                    strokeWidth: 4.0,
                  ),
                  ...buildGridLines(), //dibuja la grilla
                ],
              ),

              //para dibujar los obtaculos
              // Mostrar obstáculos como cuadros grises
              MarkerLayer(
                markers: obstacles.map((point) {
                  final latlng = gridToLatLng(Node(row: point.x, col: point.y));
                  return Marker(
                    width: 4,
                    height: 4,
                    point: latlng,
                    child: Container(color: Colors.red),
                  );
                }).toList(),
              ),

              // MarkerLayer(
              //   markers: obstacles.map((point) {
              //     final node = grid[point.x][point.y];
              //     final latlng = gridToLatLng(node);
              //     return Marker(
              //       point: latlng,
              //       width: 20,
              //       height: 20,
              //       child: Container(
              //         decoration: BoxDecoration(
              //           //color: Colors.black.withOpacity(0.5), //color bloequeos punto nodo
              //           shape: BoxShape.rectangle,
              //         ),
              //       ),
              //     );
              //   }).toList(),
              // ),

              MarkerLayer(
                markers: visiblePOIs.map((poi) {
                  final node = grid[poi.cell.x][poi.cell.y];
                  final latlng = gridToLatLng(node);
                  return Marker(
                    point: latlng,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(poi.name),
                            content: Text(poi.description),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: AnimatedPOIIcon(),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

          // Cuadros de texto y botón en la parte superior izquierda
          Positioned(
            top: 5,
            left: 0,
            child: Column(    
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pasos: $_stepCount',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Distancia: ${_distanceMeters.toStringAsFixed(2)} m',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isCountingSteps ? null : ConteoPasosTexteando.new , //_startCountingSteps
                  icon: const Icon(Icons.directions_walk),
                  label: const Text("Iniciar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            startPoint = null;
            goalPoint = null;
            path = [];
            selectingStart = true;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Point<int> latLngToGrid(LatLng point) {
    final row = ((point.latitude - startBounds.latitude) / latStep).floor();
    final col = ((point.longitude - startBounds.longitude) / lngStep).floor();

    return Point(row.clamp(0, numRows - 1), col.clamp(0, numCols - 1));
  }

  LatLng gridToLatLng(Node node) {
    final lat = startBounds.latitude + node.row * latStep + latStep / 2;
    final lng = startBounds.longitude + node.col * lngStep + lngStep / 2;

    return LatLng(
      lat, lng
    );
  }

  List<LatLng> getCellPolygon(int row, int col) {
    final  north = startBounds.latitude + row * latStep;
    final south = north + latStep;
    final west = startBounds.longitude + col * lngStep;
    final east = west + lngStep;
    return [
      LatLng(north, west),
      LatLng(north, east),
      LatLng(south, east),
      LatLng(south, west),
    ];
  }

  void calculatePath() {
    if (startPoint != null && goalPoint != null) {
      final startCell = latLngToGrid(startPoint!);
      final goalCell = latLngToGrid(goalPoint!);

      // Validación: si inicio y meta están en la misma celda, no calcular ruta
      if (startCell == goalCell) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Selecciona un destino diferente al inicio')),
        );
        return;
      }
      final startNode = grid[startCell.x][startCell.y];
      final goalNode = grid[goalCell.x][goalCell.y];

      for (final obs in obstacles) {
        grid[obs.x][obs.y].walkable = false;
      }

      final dStar = DStarLite(grid: grid, start: startNode, goal: goalNode);
      final nodePath = dStar.computeShortestPath();
      print("Ruta encontrada: ${nodePath.length} nodos");

      // [setState(() {
      //   path   = nodePath.map(gridToLatLng).toList();
      // });]
      print('Start cell: $startCell');
      print('Goal cell: $goalCell');

      setState(() {
        path = nodePath.map((node) => gridToLatLng(node)).toList();
      });

      final routeCells = nodePath.map((n) => Point(n.row, n.col)).toList();

      setState(() {
        visiblePOIs = pointsOfInterest.where((poi) {
          return isPOINearRoute(poi.cell, routeCells);
        }).toList();
      });
    }
  }

  List<Polyline> buildGridLines() {
    final List<Polyline> lines = [];

    final endGridLat = startBounds.latitude + numRows * latStep;
    final endGridLng = startBounds.longitude +  numCols * lngStep;
    
    // Líneas horizontales
    for (int r = 0; r <= numRows; r++) {
      final lat = startBounds.latitude + r * latStep;
      lines.add(
        Polyline(
          points: [LatLng(lat, startBounds.longitude), LatLng(lat, endGridLng)],
          color: Colors.black,
          strokeWidth: 0.5, 
        )
      );
    }

    // Líneas verticales
    for (int j = 0; j <= numCols; j++) {
     final lng = startBounds.longitude + j * lngStep;
     lines.add(
      Polyline(
        points: [LatLng(startBounds.latitude, lng), LatLng(endGridLat, lng)],
        color: Colors.black,
        strokeWidth: 0.5,
      )
     );
    }

    return lines;
  }

  void toggleObstacle(LatLng latlng) async {
    final cell = latLngToGrid(latlng);

    setState(() {
      if (obstacles.contains(cell)) {
        // Desbloquear
        obstacles.remove(cell);
        grid[cell.x][cell.y].walkable = true;
      } else {
        // Bloquear
        obstacles.add(cell);
        grid[cell.x][cell.y].walkable = false;
      }
    });

    await saveObstacles();
  }

  //para trabajar con .json
  Future<void> saveObstacles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/obstacles.json');

    final data = obstacles.map((p) => {'x': p.x, 'y': p.y}).toList();
    await file.writeAsString(jsonEncode(data));

    print('Obstáculos guardados en: ${file.path}');
  }

  Future<void> loadObstacles() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/obstacles.json');

    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(contents);

      setState(() {
        for (var json in decoded) {
          final p = Point<int>(json['x'], json['y']);
          obstacles.add(p);
          //grid[p.x][p.y].walkable = false;
        }
      });

      print('Obstáculos cargados desde: ${file.path}');
    }
  }

  //para trabajar con shared preferences
  // [Future<void> saveObstacles() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final encoded = obstacles.map((p) => '${p.x},${p.y}').toList();
  //   await prefs.setStringList('obstacles', encoded);
  // }]

  // Future<void> loadObstacles() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final encoded = prefs.getStringList('obstacles') ?? [];
  //   setState(() {
  //     for (var e in encoded) {
  //       final parts = e.split(',');
  //       final p = Point(int.parse(parts[0]), int.parse(parts[1]));
  //       obstacles.add(p);
  //       grid[p.x][p.y].walkable = false;

  //     }
  //   });
  // }

  //para cargar POIS desde archivo JSON
  Future<void> loadPOIsFromJson() async {
    final String jsonString = await rootBundle.loadString('assets/pois.json');
    final List<dynamic> jsonList = json.decode(jsonString);

    setState(() {
      pointsOfInterest = jsonList.map((json) => POI.fromJson(json)).toList();
    });
  }

  //Para filtrar los POIS cercanos a la ruta calculada
  bool isPOINearRoute(Point<int> poiCell, List<Point<int>> routeCells,
      {int distance = 2}) {
    for (var cell in routeCells) {
      if ((poiCell.x - cell.x).abs() <= distance &&
          (poiCell.y - cell.y).abs() <= distance) {
        return true;
      }
    }
    return false;
  }

  //para seguir la orientacion tipo brijula
  void _startCompassTracking() {
    //_accelSub = accelerometerEvents().listen((AccelerometerEvent event) asi estaba XD
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      _accelData = event;
      _updateDeviceAngle();
    });

    _magSub = magnetometerEventStream().listen((MagnetometerEvent event) {
      _magData = event;
      _updateDeviceAngle();
    });
  }

  void _updateDeviceAngle() {
    if (_accelData == null || _magData == null) return;

    final ax = _accelData!.x;
    final ay = _accelData!.y;
    final az = _accelData!.z;

    final mx = _magData!.x;
    final my = _magData!.y;
    final mz = _magData!.z;

    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    final normM = math.sqrt(mx * mx + my * my + mz * mz);

    if (normA == 0 || normM == 0) return;

    final axn = ax / normA;
    final ayn = ay / normA;
    final azn = az / normA;

    final mxn = mx / normM;
    final myn = my / normM;
    final mzn = mz / normM;

    final hx = myn * azn - mzn * ayn;
    final hy = mzn * axn - mxn * azn;
    final hz = mxn * ayn - myn * axn;

    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH == 0.0) return;

    final hxNorm = hx / normH;
    final hyNorm = hy / normH;

    final angle = math.atan2(hyNorm, hxNorm); // ángulo en radianes

    setState(() {
      _deviceAngle = angle;
    });
  }

}

class AnimatedPOIIcon extends StatefulWidget {
  const AnimatedPOIIcon({super.key});

  @override
  _AnimatedPOIIconState createState() => _AnimatedPOIIconState();
}

//para animacion de icono de POI
class _AnimatedPOIIconState extends State<AnimatedPOIIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.3).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      )),
      child: const Icon(Icons.info, color: Colors.deepPurpleAccent, size: 28),
    );
  }

  //ejemplo para conteo de pasos, cambiar por logica de cesar
  
}
