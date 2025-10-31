
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LocationData? _currentLocation;
  final Location _location = Location();
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final locationData = await _location.getLocation();
      setState(() {
        _currentLocation = locationData;
        if (_currentLocation != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: LatLng(
                _currentLocation!.latitude!,
                _currentLocation!.longitude!,
              ),
              infoWindow: const InfoWindow(title: 'Current Location'),
            ),
          );
        }
      });
    } catch (e, s) {
      developer.log('Error getting location', error: e, stackTrace: s, name: 'my_app.map');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マップ'),
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentLocation!.latitude!,
                  _currentLocation!.longitude!,
                ),
                zoom: 15,
              ),
              markers: _markers,
            ),
    );
  }
}
