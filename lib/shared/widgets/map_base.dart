import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/theme.dart';

/// Reusable map widget wrapping flutter_map with OpenStreetMap tiles.
class MapBase extends StatelessWidget {
  final LatLng? center;
  final double zoom;
  final List<Polyline> polylines;
  final List<Marker> markers;
  final List<CircleMarker> circles;
  final MapController? mapController;
  final bool showCurrentLocation;

  const MapBase({
    super.key,
    this.center,
    this.zoom = 14.0,
    this.polylines = const [],
    this.markers = const [],
    this.circles = const [],
    this.mapController,
    this.showCurrentLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center ?? const LatLng(51.5074, -0.1278), // London default
        initialZoom: zoom,
      ),
      children: [
        // OpenStreetMap tiles (free, no API key)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.datacommons.app',
        ),

        // Polylines layer
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),

        // Circles layer
        if (circles.isNotEmpty) CircleLayer(circles: circles),

        // Markers layer
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Helper to create a speed-coloured polyline from GPS points.
Polyline speedColoredPolyline(
  List<LatLng> points,
  List<double> speeds, {
  double strokeWidth = 4.0,
}) {
  // For simplicity, colour the entire line by average speed.
  // A more advanced version would segment by speed.
  final avgSpeed = speeds.isEmpty
      ? 0.0
      : speeds.reduce((a, b) => a + b) / speeds.length;

  Color color;
  if (avgSpeed < 1.5) {
    color = AppTheme.success; // Walking
  } else if (avgSpeed < 5.0) {
    color = AppTheme.warning; // Running / cycling
  } else {
    color = AppTheme.primary; // Driving
  }

  return Polyline(
    points: points,
    color: color,
    strokeWidth: strokeWidth,
  );
}
