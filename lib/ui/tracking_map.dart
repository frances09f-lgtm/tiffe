import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Approximate centres of the kitchen's delivery areas. These are area
/// centres, not exact addresses, and the map says so.
const areaCentres = <String, LatLng>{
  'Kothrud': LatLng(18.5074, 73.8077),
  'Baner': LatLng(18.5590, 73.7868),
  'Aundh': LatLng(18.5580, 73.8075),
  'Wakad': LatLng(18.5975, 73.7600),
  'Viman Nagar': LatLng(18.5679, 73.9143),
};
const puneCentre = LatLng(18.5204, 73.8567);

/// Delivery map: OpenStreetMap tiles, the delivery-area pin, and a clearly
/// labelled DEMO delivery partner that moves smoothly toward the pin.
/// The rider position is simulated. There is no real rider GPS yet.
class TrackingMap extends StatefulWidget {
  final String area;
  final String? kitchenStatus; // real order status, if an order is active
  final String? etaText; // real kitchen-set ETA, if any
  /// Tests switch this off so pumpAndSettle can finish.
  static bool animateDemo = true;
  const TrackingMap({
    super.key,
    required this.area,
    this.kitchenStatus,
    this.etaText,
  });
  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 45),
    value: .55,
  );

  @override
  void initState() {
    super.initState();
    if (TrackingMap.animateDemo) ctl.repeat();
  }

  LatLng get pin => areaCentres[widget.area] ?? puneCentre;

  List<LatLng> get route {
    final p = pin;
    return [
      LatLng(p.latitude + .0105, p.longitude - .0085),
      LatLng(p.latitude + .0105, p.longitude - .0020),
      LatLng(p.latitude + .0040, p.longitude - .0020),
      LatLng(p.latitude + .0040, p.longitude + .0000),
      p,
    ];
  }

  LatLng at(double t) {
    final r = route;
    final lens = <double>[];
    var total = 0.0;
    for (var i = 0; i < r.length - 1; i++) {
      final d = const Distance().as(LengthUnit.Meter, r[i], r[i + 1]);
      lens.add(d);
      total += d;
    }
    var left = t.clamp(0.0, 1.0) * total;
    for (var i = 0; i < lens.length; i++) {
      if (left <= lens[i]) {
        final f = lens[i] == 0 ? 0.0 : left / lens[i];
        return LatLng(
          r[i].latitude + (r[i + 1].latitude - r[i].latitude) * f,
          r[i].longitude + (r[i + 1].longitude - r[i].longitude) * f,
        );
      }
      left -= lens[i];
    }
    return r.last;
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF202D24) : Colors.white;
    final p = pin;
    final bounds = LatLngBounds.fromPoints(route);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: ctl,
                  builder: (context, _) {
                    final rider = at(ctl.value);
                    return FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: bounds,
                          padding: const EdgeInsets.fromLTRB(48, 70, 48, 70),
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.ambi.tiffe',
                          maxNativeZoom: 19,
                          tileProvider: TrackingMap.animateDemo
                              ? null
                              : NetworkTileProvider(
                                  cachingProvider:
                                      const DisabledMapCachingProvider(),
                                ),
                          errorTileCallback: (tile, error, stack) {},
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: route,
                              strokeWidth: 4,
                              color: const Color(0xFFFF8843),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: p,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                size: 44,
                                color: Color(0xFF9E4300),
                              ),
                            ),
                            Marker(
                              point: rider,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF012D1D),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.two_wheeler,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: const Color(0xCCFFFFFF),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10, color: Color(0xFF1A1C1E)),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: Color(0xFFFF8843)),
                        SizedBox(width: 6),
                        Text(
                          'Demo delivery preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1C1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: AnimatedBuilder(
              animation: ctl,
              builder: (context, _) {
                final meters = const Distance().as(
                  LengthUnit.Meter,
                  at(ctl.value),
                  p,
                );
                final km = (meters / 1000).toStringAsFixed(1);
                final mins = math.max(1, (meters / 250).round());
                final real = widget.kitchenStatus;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDBCB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        real == null
                            ? 'DEMO PREVIEW'
                            : 'ORDER: ${real.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: .6,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF783100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arriving',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: dark
                            ? const Color(0xFFA8D4A5)
                            : const Color(0xFF012D1D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$km km away - about $mins min (demo)',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The delivery partner on this map is a simulated demo and the pin marks the centre of ${widget.area.isEmpty ? 'your area' : widget.area}, not your exact door. '
                      'Real live rider location is coming later.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: dark
                            ? const Color(0xFFAEB9AE)
                            : const Color(0xFF738074),
                      ),
                    ),
                    if (widget.etaText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.etaText!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
