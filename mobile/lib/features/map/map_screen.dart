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

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
    this.tileProviderFactory,
  });
  final ParkingRepository repository;
  final TileProvider Function()? tileProviderFactory;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _loader = LoadController<List<Parking>>();
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => unawaited(_loader.load(widget.repository.fetchAll));
  @override
  void dispose() {
    _loader.dispose();
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
        ParkingMap(
          parkings: parkings,
          onSelect: (parking) => unawaited(_select(parking)),
          onRefresh: _refresh,
          tileProviderFactory: widget.tileProviderFactory,
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
