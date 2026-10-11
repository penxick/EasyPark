import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/state/load_controller.dart';
import '../../../core/state/load_state.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../map/parking.dart';
import '../../map/parking_map.dart';
import '../../parking/parking_details.dart';
import '../models/admin_map_request.dart';
import '../repositories/admin_parking_repository.dart';

class AdminParkingMapScreen extends StatefulWidget {
  const AdminParkingMapScreen({
    super.key,
    required this.repository,
    this.picker = false,
    this.initialPoint,
    this.tileProviderFactory,
  });
  final AdminParkingRepository repository;
  final bool picker;
  final LatLng? initialPoint;
  final TileProvider Function()? tileProviderFactory;
  @override
  State<AdminParkingMapScreen> createState() => _AdminParkingMapScreenState();
}

class _AdminParkingMapScreenState extends State<AdminParkingMapScreen> {
  final loader = LoadController<List<ParkingDetails>>();
  late bool selecting = widget.picker;
  late LatLng? point = widget.initialPoint;
  LatLng? focus;
  int mapVersion = 0;
  bool opening = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => loader.load(widget.repository.all);
  @override
  void dispose() {
    loader.dispose();
    super.dispose();
  }

  Future<void> openForm({Parking? parking}) async {
    if (opening) return;
    setState(() => opening = true);
    final result = await context.push<ParkingDetails>(
      parking == null
          ? '/admin/parkings/new'
          : '/admin/parkings/${parking.id}/edit',
      extra: AdminMapRequest(point: parking == null ? point : null),
    );
    if (!mounted) return;
    setState(() {
      opening = false;
      if (result != null) {
        focus = LatLng(result.parking.latitude, result.parking.longitude);
        selecting = false;
        point = null;
        mapVersion++;
      }
    });
    if (result != null) await reload();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  selecting ? 'Выберите точку на карте' : 'Карта парковок',
                  style: AppTypography.heading2,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (selecting)
                  const Text(
                    'Нажмите на карту. Координаты появятся в форме парковки.',
                  ),
                if (point != null && selecting)
                  Text(
                    'Latitude: ${point!.latitude.toStringAsFixed(6)} · Longitude: ${point!.longitude.toStringAsFixed(6)}',
                  ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!selecting)
                      AppButton(
                        label: '+ Добавить парковку',
                        onPressed: () => setState(() {
                          selecting = true;
                          point = null;
                        }),
                      ),
                    if (selecting)
                      AppButton(
                        label: widget.picker ? 'Выбрать точку' : 'Продолжить',
                        onPressed: point == null || opening
                            ? null
                            : () {
                                if (widget.picker) {
                                  if (context.canPop()) {
                                    context.pop(point);
                                  } else {
                                    context.go(
                                      '/admin/parkings/new',
                                      extra: AdminMapRequest(point: point),
                                    );
                                  }
                                } else {
                                  openForm();
                                }
                              },
                      ),
                    if (selecting)
                      AppButton(
                        label: 'Отмена',
                        variant: AppButtonVariant.outline,
                        onPressed: opening
                            ? null
                            : () {
                                if (widget.picker) {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/admin/parkings');
                                  }
                                } else {
                                  setState(() {
                                    selecting = false;
                                    point = null;
                                  });
                                }
                              },
                      ),
                    if (!widget.picker)
                      AppButton(
                        label: 'К списку парковок',
                        variant: AppButtonVariant.outline,
                        onPressed: () => context.go('/admin/parkings'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: (size.maxHeight - 180).clamp(360, 900).toDouble(),
            child: ListenableBuilder(
              listenable: loader,
              builder: (context, _) => switch (loader.state) {
                LoadSuccess<List<ParkingDetails>>(data: final data) =>
                  ParkingMap(
                    key: ValueKey(mapVersion),
                    parkings: data.map((p) => p.parking).toList(),
                    initialPoint: focus ?? widget.initialPoint,
                    selectedPoint: selecting ? point : null,
                    tileProviderFactory: widget.tileProviderFactory,
                    onPick: selecting
                        ? (value) => setState(() => point = value)
                        : null,
                    onSelect: (parking) => openForm(parking: parking),
                    onRefresh: reload,
                  ),
                LoadFailure<List<ParkingDetails>>(error: final error) =>
                  SingleChildScrollView(
                    child: AppErrorView(
                      message: error.message,
                      onRetry: reload,
                    ),
                  ),
                _ => const AppLoadingIndicator(),
              },
            ),
          ),
        ],
      ),
    ),
  );
}
