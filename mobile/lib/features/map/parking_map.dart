import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import 'parking.dart';

class ParkingMap extends StatefulWidget {
  const ParkingMap({
    super.key,
    required this.parkings,
    required this.onSelect,
    required this.onRefresh,
    this.tileProviderFactory,
    this.onPick,
    this.selectedPoint,
    this.initialPoint,
  });
  final List<Parking> parkings;
  final ValueChanged<Parking> onSelect;
  final VoidCallback onRefresh;
  final TileProvider Function()? tileProviderFactory;
  final ValueChanged<LatLng>? onPick;
  final LatLng? selectedPoint, initialPoint;
  @override
  State<ParkingMap> createState() => _ParkingMapState();
}

class _ParkingMapState extends State<ParkingMap> {
  final _map = MapController();
  bool _tileError = false;
  int _tileGeneration = 0;
  late TileProvider _tiles;
  @override
  void initState() {
    super.initState();
    _tiles = _provider();
  }

  TileProvider _provider() =>
      widget.tileProviderFactory?.call() ?? NetworkTileProvider();
  List<LatLng> get _points =>
      widget.parkings.map((p) => LatLng(p.latitude, p.longitude)).toList();
  CameraFit get _fit => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints([
      ..._points,
      if (widget.selectedPoint != null) widget.selectedPoint!,
      if (_points.isEmpty && widget.selectedPoint == null)
        widget.initialPoint ?? const LatLng(56.01, 92.87),
    ]),
    padding: const EdgeInsets.all(64),
    maxZoom: 15,
  );
  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _failedTile() {
    if (_tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  Future<void> _attribution() async {
    try {
      if (await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Report only a user-facing message. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть ссылку OpenStreetMap.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: SizedBox(
        height: constraints.maxHeight < 360 ? 360 : constraints.maxHeight,
        child: _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) => Column(
    children: [
      if (_tileError)
        Material(
          color: AppColors.blueLight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Не удалось загрузить фон карты.',
                    style: AppTypography.small,
                  ),
                ),
                IconButton(
                  tooltip: 'Повторить загрузку карты',
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () => setState(() {
                    _tileError = false;
                    _tileGeneration++;
                    _tiles = _provider();
                  }),
                ),
              ],
            ),
          ),
        ),
      Expanded(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter:
                    widget.initialPoint ??
                    (_points.isEmpty
                        ? const LatLng(56.01, 92.87)
                        : _points.first),
                initialZoom: 15,
                initialCameraFit: widget.initialPoint == null ? _fit : null,
                onTap: widget.onPick == null
                    ? null
                    : (_, point) => widget.onPick!(
                        LatLng(
                          point.latitude.clamp(-90, 90),
                          ((point.longitude + 180) % 360) - 180,
                        ),
                      ),
                minZoom: 2,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  key: ValueKey(_tileGeneration),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.easypark.easypark',
                  tileProvider: _tiles,
                  maxNativeZoom: 19,
                  panBuffer: 0,
                  errorTileCallback: (_, _, _) => _failedTile(),
                ),
                MarkerLayer(
                  markers: [
                    for (final parking in widget.parkings)
                      Marker(
                        point: LatLng(parking.latitude, parking.longitude),
                        width: 48,
                        height: 48,
                        child: Semantics(
                          button: true,
                          label: '${parking.name}, ${parking.formattedPrice}',
                          child: Tooltip(
                            message: parking.name,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              elevation: 3,
                              child: InkWell(
                                key: ValueKey('parking-marker-${parking.id}'),
                                customBorder: const CircleBorder(),
                                onTap: () => widget.onPick != null
                                    ? widget.onPick!(
                                        LatLng(
                                          parking.latitude,
                                          parking.longitude,
                                        ),
                                      )
                                    : widget.onSelect(parking),
                                child: const Center(
                                  child: ExcludeSemantics(
                                    child: Icon(
                                      LucideIcons.parkingMeter,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.selectedPoint != null)
                      Marker(
                        point: widget.selectedPoint!,
                        width: 48,
                        height: 48,
                        child: const IgnorePointer(
                          child: Icon(
                            Icons.location_pin,
                            key: ValueKey('selected-parking-point'),
                            size: 48,
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                elevation: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Показать все парковки',
                      icon: const Icon(LucideIcons.locateFixed),
                      onPressed: () => _map.fitCamera(_fit),
                    ),
                    IconButton(
                      tooltip: 'Обновить парковки',
                      icon: const Icon(LucideIcons.refreshCw),
                      onPressed: widget.onRefresh,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      Material(
        color: AppColors.surface,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => unawaited(_attribution()),
            child: const Text(
              '© OpenStreetMap contributors',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}
