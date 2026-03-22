import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import '../models/location_zone.dart';
import '../services/location_manager.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _cameraCenter = const LatLng(28.6139, 77.2090); // Default to New Delhi
  final TextEditingController _nameController = TextEditingController();
  double _radius = 100.0;
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  void _initializeRenderer() {
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = false;
      mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
    }
  }

  void _onSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the silent zone.')),
      );
      return;
    }

    final newZone = LocationZone(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      latitude: _cameraCenter.latitude,
      longitude: _cameraCenter.longitude,
      radiusInMeters: _radius,
    );

    await LocationManager.addZone(newZone);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<Iterable<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.isEmpty) return const [];
    
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'LocationRingerApp/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Search Error: $e');
    }
    return const [];
  }

  void _goToPlace(Map<String, dynamic> place) async {
    final lat = double.parse(place['lat'].toString());
    final lon = double.parse(place['lon'].toString());
    final position = LatLng(lat, lon);

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: position, zoom: 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Search & Select'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onSave,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Map Layer
          GoogleMap(
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: _cameraCenter,
              zoom: 14.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              setState(() {
                _isMapReady = true;
              });
              _controller.complete(controller);
            },
            onCameraMove: (CameraPosition position) {
              setState(() {
                _cameraCenter = position.target;
              });
            },
            circles: {
              Circle(
                circleId: const CircleId('zone_radius'),
                center: _cameraCenter,
                radius: _radius,
                fillColor: Colors.blueAccent.withOpacity(0.2),
                strokeColor: Colors.blueAccent,
                strokeWidth: 2,
              ),
            },
          ),
          
          // 2. Center Pin (Static crosshair)
          const Positioned(
            child: Icon(
              Icons.location_pin,
              size: 48,
              color: Colors.redAccent,
            ),
          ),
          
          // 3. Search Autocomplete Bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => option['display_name'] ?? '',
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.length < 3) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return await _searchPlaces(textEditingValue.text);
              },
              onSelected: (Map<String, dynamic> selection) {
                FocusScope.of(context).unfocus(); // Close keyboard
                _goToPlace(selection);
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                return Card(
                  color: const Color(0xFF1E1E1E),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Search for a city or place...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            onEditingComplete: onEditingComplete,
                          ),
                        ),
                        if (controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              controller.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 250,
                        maxWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.white70),
                            title: Text(
                              option['display_name'] ?? '',
                              style: const TextStyle(color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              onSelected(option);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Card(
              color: const Color(0xFF1E1E1E),
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Location Name (e.g. School)',
                        border: UnderlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text("Radius:", style: TextStyle(color: Colors.grey)),
                        Expanded(
                          child: Slider(
                            value: _radius,
                            min: 50,
                            max: 1000,
                            divisions: 19,
                            label: '${_radius.round()}m',
                            onChanged: (value) {
                              setState(() {
                                _radius = value;
                              });
                            },
                          ),
                        ),
                        Text('${_radius.round()}m', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
