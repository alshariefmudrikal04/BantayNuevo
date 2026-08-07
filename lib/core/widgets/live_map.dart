import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../theme/app_colors.dart';

/// Free, no-API-key live map using OpenStreetMap.
/// Displays the current user's location and, when available,
/// the responder's location.
class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    required this.selfLat,
    required this.selfLng,
    required this.selfLabel,
    this.otherLat,
    this.otherLng,
    this.otherLabel,
  });

  final double selfLat;
  final double selfLng;
  final String selfLabel;

  final double? otherLat;
  final double? otherLng;
  final String? otherLabel;

  bool get hasOther => otherLat != null && otherLng != null;

  @override
  Widget build(BuildContext context) {
    final self = ll.LatLng(selfLat, selfLng);
    final other = hasOther ? ll.LatLng(otherLat!, otherLng!) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: self,
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'com.baranggaycaminonuevo.bantay_nuevo',
          ),

          if (other != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [self, other],
                  color: AppColors.teal,
                  strokeWidth: 4,
                ),
              ],
            ),

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
                color: Colors.black26,
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
          size: 28,
        ),
      ],
    );
  }
}