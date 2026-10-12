import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/load_controller.dart';
import '../../core/state/load_state.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/theme/app_tokens.dart';
import 'parking.dart';
import 'parking_map.dart';
import 'parking_repository.dart';
import 'parking_summary.dart';
import 'parking_navigation.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
    this.tileProviderFactory,
    this.navigation,
  });
  final ParkingRepository repository;
  final TileProvider Function()? tileProviderFactory;
  final ParkingNavigation? navigation;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _loader = LoadController<List<Parking>>();
  late final _navigation = widget.navigation ?? ParkingNavigation();
  LatLng? _location;
  DrivingRoute? _route;
  bool _locating = false;
  String? _navigationError;
  int _navigationGeneration = 0;
  int _locationVersion = 0;

  Future<void> _locate([Parking? destination]) async {
    if (_locating) return;
    final generation = ++_navigationGeneration;
    setState(() {
      _locating = true;
      _navigationError = null;
      _route = null;
    });
    try {
      final point = await _navigation.locate();
      if (!mounted || generation != _navigationGeneration) return;
      setState(() {
        _location = point;
        _locationVersion++;
      });
      if (destination != null) {
        final route = await _navigation.route(
          point,
          LatLng(destination.latitude, destination.longitude),
        );
        if (!mounted || generation != _navigationGeneration) return;
        setState(() => _route = route);
      }
    } catch (e) {
      if (mounted && generation == _navigationGeneration) {
        setState(
          () => _navigationError = e is NavigationFailure
              ? e.message
              : 'Не удалось получить местоположение. Повторите попытку.',
        );
      }
    } finally {
      if (mounted && generation == _navigationGeneration) {
        setState(() => _locating = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => unawaited(_loader.load(widget.repository.fetchAll));
  @override
  void dispose() {
    _loader.dispose();
    _navigationGeneration++;
    if (widget.navigation == null) _navigation.dispose();
    super.dispose();
  }

  Future<void> _select(Parking parking) async {
    final details = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
        maxWidth: 672,
      ),
      backgroundColor: AppColors.surface,
      builder: (context) => ParkingSummary(
        parking: parking,
        onDetails: () => Navigator.pop(context, true),
        onRoute: () {
          Navigator.pop(context);
          unawaited(_locate(parking));
        },
      ),
    );
    if (details == true && mounted) context.push('/parking/${parking.id}');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _loader,
    builder: (context, _) => switch (_loader.state) {
      LoadSuccess<List<Parking>>(data: final parkings)
          when parkings.isNotEmpty =>
        Column(
          children: [
            if (_locating)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Определение местоположения и загрузка…'),
              ),
            if (_navigationError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_navigationError!),
              ),
            if (_route != null || _locating)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_route != null)
                    Text(
                      '${(_route!.distance / 1000).toStringAsFixed(1)} км · ≈ ${(_route!.duration / 60).ceil()} мин',
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _navigationGeneration++;
                      _route = null;
                      _locating = false;
                    }),
                    child: const Text('Скрыть маршрут'),
                  ),
                ],
              ),
            Expanded(
              child: ParkingMap(
                parkings: parkings,
                userControls: true,
                onLocate: _locating ? null : () => unawaited(_locate()),
                userPoint: _location,
                locationVersion: _locationVersion,
                routePoints: _route?.points ?? const [],
                onSelect: (parking) => unawaited(_select(parking)),
                onRefresh: _refresh,
                tileProviderFactory: widget.tileProviderFactory,
              ),
            ),
          ],
        ),
      LoadSuccess<List<Parking>>() => Center(
        child: SingleChildScrollView(
          padding: AppSpacing.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Парковки пока не найдены.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Обновить', onPressed: _refresh),
            ],
          ),
        ),
      ),
      LoadFailure<List<Parking>>(error: final error) => Center(
        child: SingleChildScrollView(
          child: AppErrorView(message: error.message, onRetry: _refresh),
        ),
      ),
      _ => const Center(
        child: AppLoadingIndicator(label: 'Загрузка парковок…'),
      ),
    },
  );
}
