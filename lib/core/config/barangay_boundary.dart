import 'package:latlong2/latlong.dart';

/// Camino Nuevo, Zamboanga City — traced boundary.
///
/// Sourced from a manual trace in Google My Maps (exported as KML,
/// converted from KML's lng,lat order to LatLng(lat, lng) here). Verified
/// against PhilAtlas's independently reported barangay center point
/// (6.9188, 122.0753), which falls correctly inside this polygon.
///
/// To retrace or adjust this boundary later: mymaps.google.com → draw a
/// line following the boundary → export KML → the <coordinates> tag gives
/// "lng,lat,0" triples, in the OPPOSITE order LatLng() expects — swap them
/// when copying in, same as was done here.
const List<LatLng> caminoNuevoBoundary = [
  LatLng(6.920997, 122.071872),
  LatLng(6.9218916, 122.0788994),
  LatLng(6.9135841, 122.0797148),
  LatLng(6.9105273, 122.0748547),
  LatLng(6.9099628, 122.0732453),
  LatLng(6.9117308, 122.0726767),
  LatLng(6.9128279, 122.0724621),
  LatLng(6.9159858, 122.0726231),
  LatLng(6.920997, 122.071872), // closes the polygon back to the start
];

/// GPS drift buffer, in meters. Phone GPS is commonly off by 5–20+
/// meters, worse indoors or between tall buildings. Without a buffer,
/// someone standing right at the real-world boundary line could get
/// incorrectly flagged as outside it purely from GPS noise. This adds a
/// small forgiving margin around the polygon rather than a razor-sharp
/// cutoff. Tune this after real-device testing near the actual edge.
const double boundaryBufferMeters = 30;
