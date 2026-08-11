import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../config/barangay_boundary.dart';

/// Result of checking one GPS point against the barangay boundary.
class GeofenceResult {
  const GeofenceResult({required this.insidePolygon, required this.distanceToEdgeMeters});

  /// True if the point is strictly inside the traced polygon.
  final bool insidePolygon;

  /// Distance in meters from the point to the nearest polygon edge.
  /// 0 when insidePolygon is true.
  final double distanceToEdgeMeters;

  /// The practical answer to use everywhere: inside the shape outright,
  /// OR close enough that GPS drift is the more likely explanation than
  /// the person actually being outside — see boundaryBufferMeters.
  bool get withinBoundary => insidePolygon || distanceToEdgeMeters <= boundaryBufferMeters;
}

/// Checks a lat/lng against caminoNuevoBoundary (or a custom polygon, e.g.
/// in a test). This is the one function report/SOS submission calls.
GeofenceResult checkBarangayBoundary(double lat, double lng, {List<LatLng>? polygon}) {
  final boundary = polygon ?? caminoNuevoBoundary;
  final point = LatLng(lat, lng);
  final inside = _isPointInPolygon(point, boundary);
  final distance = inside ? 0.0 : _distanceToPolygonMeters(point, boundary);
  return GeofenceResult(insidePolygon: inside, distanceToEdgeMeters: distance);
}

/// Ray-casting algorithm: draws an imaginary horizontal ray from the point
/// out to the right, and counts how many polygon edges it crosses. Odd
/// number of crossings = inside, even = outside. Standard, well-tested
/// approach for this — no need to reach for a mapping/geo package just
/// for this one check.
bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    final intersects = ((pi.latitude > point.latitude) != (pj.latitude > point.latitude)) &&
        (point.longitude <
            (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) / (pj.latitude - pi.latitude) +
                pi.longitude);
    if (intersects) inside = !inside;
  }
  return inside;
}

/// Shortest distance from the point to any edge of the polygon, in
/// meters. Barangay-scale areas are small enough that projecting lat/lng
/// onto a local flat plane (anchored at the query point) and doing plain
/// 2D point-to-segment geometry is accurate to well under a meter of
/// error — nowhere near enough to matter next to a 30m GPS buffer, and
/// far simpler than exact spherical geometry.
double _distanceToPolygonMeters(LatLng point, List<LatLng> polygon) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLng = 111320.0 * math.cos(point.latitude * math.pi / 180);

  _Local toLocal(LatLng p) => _Local(
        (p.longitude - point.longitude) * metersPerDegreeLng,
        (p.latitude - point.latitude) * metersPerDegreeLat,
      );

  final origin = _Local(0, 0); // the point itself, in its own local frame
  var minDistance = double.infinity;

  for (var i = 0; i < polygon.length - 1; i++) {
    final a = toLocal(polygon[i]);
    final b = toLocal(polygon[i + 1]);
    final d = _distancePointToSegment(origin, a, b);
    if (d < minDistance) minDistance = d;
  }
  return minDistance;
}

double _distancePointToSegment(_Local p, _Local a, _Local b) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final lengthSquared = abx * abx + aby * aby;
  if (lengthSquared == 0) return _distance(p, a); // a and b are the same point

  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final closest = _Local(a.x + t * abx, a.y + t * aby);
  return _distance(p, closest);
}

double _distance(_Local p1, _Local p2) => math.sqrt(math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2));

class _Local {
  const _Local(this.x, this.y);
  final double x;
  final double y;
}
