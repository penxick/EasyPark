import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/state/load_controller.dart';
import '../../core/state/load_state.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_button.dart';
import 'parking_space.dart';
import 'parking_spaces_repository.dart';
import 'parking_layout.dart';

class ParkingLayoutScreen extends StatefulWidget {
  const ParkingLayoutScreen({
    super.key,
    required this.parkingId,
    required this.repository,
  });
  final String parkingId;
  final ParkingSpacesRepository repository;
  @override
  State<ParkingLayoutScreen> createState() => _ParkingLayoutScreenState();
}

class _ParkingLayoutScreenState extends State<ParkingLayoutScreen> {
  final _loader = LoadController<List<ParkingSpace>>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ParkingLayoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parkingId != widget.parkingId) _load();
  }

  void _load() => unawaited(
    _loader.load(() => widget.repository.fetchAll(widget.parkingId)),
  );
  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'Парковочные места',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/parking/${widget.parkingId}');
        }
      },
      actions: [
        IconButton(
          tooltip: 'Обновить места',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: _loader,
        builder: (context, _) => switch (_loader.state) {
          LoadSuccess<List<ParkingSpace>>(data: final spaces)
              when spaces.isNotEmpty =>
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ParkingLayout(
                    spaces: spaces,
                    onBook: (space) async {
                      await context.push(
                        '/parking/${widget.parkingId}/book/${space.id}',
                      );
                      if (mounted) _load();
                    },
                  ),
                ),
              ),
            ),
          LoadSuccess<List<ParkingSpace>>() => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'На этой парковке пока нет мест.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppButton(label: 'Обновить', onPressed: _load),
                ],
              ),
            ),
          ),
          LoadFailure<List<ParkingSpace>>(error: final error) => Center(
            child: SingleChildScrollView(
              child: AppErrorView(
                title: error.kind == ApiErrorKind.notFound
                    ? 'Парковка не найдена'
                    : 'Не удалось загрузить места',
                message: error.message,
                onRetry: error.kind == ApiErrorKind.invalidRequest
                    ? null
                    : _load,
              ),
            ),
          ),
          _ => const Center(
            child: AppLoadingIndicator(label: 'Загрузка мест…'),
          ),
        },
      ),
    ),
  );
}
