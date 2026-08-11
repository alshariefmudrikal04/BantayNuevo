
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../theme/app_colors.dart';
import '../config/barangay_boundary.dart';

/// Free, no-API-key live map — OpenStreetMap tiles via flutter_map.
///
/// Shows the current user's position always, and a responder's position
/// once available (SOS accepted). Auto-fits bounds to keep both markers visible.
class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    required this.selfLat,
    required this.selfLng,
    required this.selfLabel,
    this.otherLat,
    this.otherLng,
    this.otherLabel,
    this.showBoundary = false,
  });

  final double selfLat;
  final double selfLng;
  final String selfLabel;

  final double? otherLat;
  final double? otherLng;
  final String? otherLabel;

  /// Draws caminoNuevoBoundary as an outline over the map.
  ///
  /// This is for visual reference only and does not affect the actual
  /// geofence check.
  final bool showBoundary;

  bool get _hasOther => otherLat != null && otherLng != null;

  @override
  Widget build(BuildContext context) {
    final self = ll.LatLng(selfLat, selfLng);

    final other = _hasOther
        ? ll.LatLng(otherLat!, otherLng!)
        : null;

    // FIX:
    // LatLngBounds comes from flutter_map, so don't use ll.LatLngBounds.
    final bounds = other != null
        ? LatLngBounds.fromPoints([self, other])
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: self,
          initialZoom: 15,

          // Automatically fit both markers when a responder exists.
          initialCameraFit: bounds != null
              ? CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(48),
                )
              : null,
        ),

        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'com.baranggaycaminonuevo.bantay_nuevo',
          ),

          // Barangay boundary
          if (showBoundary)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: caminoNuevoBoundary,
                  color: AppColors.navy.withOpacity(0.07),
                  borderColor: AppColors.navy,
                  borderStrokeWidth: 2,
                ),
              ],
            ),

          // Line between user and responder
          if (other != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [self, other],
                  color: AppColors.teal,
                  strokeWidth: 3,
                ),
              ],
            ),

          // Map markers
          MarkerLayer(
            markers: [
              Marker(
                point: self,
                width: 90,
                height: 60,
                child: _PinLabel(
                  label: selfLabel,
                  color: AppColors.urgent,
                  icon: Icons.person_pin_circle,
                ),
              ),

              if (other != null)
                Marker(
                  point: other,
                  width: 90,
                  height: 60,
                  child: _PinLabel(
                    label: otherLabel ?? 'Responder',
                    color: AppColors.teal,
                    icon: Icons.shield,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinLabel extends StatelessWidget {
  const _PinLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Icon(
          icon,
          color: color,
          size: 26,
        ),
      ],
    );
  }
}
