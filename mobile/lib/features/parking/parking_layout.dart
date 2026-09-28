import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import 'parking_space.dart';

String spaceStatusLabel(SpaceStatus status) => switch (status) {
  SpaceStatus.free => 'Свободно',
  SpaceStatus.occupied => 'Занято',
  SpaceStatus.reserved => 'Забронировано',
  SpaceStatus.unavailable => 'Недоступно',
};
Color spaceStatusColor(SpaceStatus status) => switch (status) {
  SpaceStatus.free => AppColors.free,
  SpaceStatus.occupied => AppColors.occupied,
  SpaceStatus.reserved => AppColors.reserved,
  SpaceStatus.unavailable => AppColors.mutedForeground,
};

class ParkingLayout extends StatefulWidget {
  const ParkingLayout({super.key, required this.spaces, this.onBook});
  final List<ParkingSpace> spaces;
  final ValueChanged<ParkingSpace>? onBook;
  @override
  State<ParkingLayout> createState() => _ParkingLayoutState();
}

class _ParkingLayoutState extends State<ParkingLayout> {
  final _transform = TransformationController();
  int? _selected;
  bool _initialized = false;
  double _fit = 1;
  @override
  void didUpdateWidget(covariant ParkingLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.spaces.any((s) => s.id == _selected && s.selectable)) {
      _selected = null;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final cellWidth = math.max(80.0, 80 * textScale);
    final cellHeight = math.max(48.0, 40 * textScale);
    // Coordinates describe the diagram, not fixed positions in the screen UI.
    final maxX = widget.spaces.fold(0.0, (v, s) => math.max(v, s.x));
    final maxY = widget.spaces.fold(0.0, (v, s) => math.max(v, s.y));
    final xScale = cellWidth / 80, yScale = (cellHeight + 8) / 50;
    final canvasWidth = math.max(600.0 * xScale, (maxX + 100) * xScale);
    final canvasHeight = math.max(350.0 * yScale, (maxY + 60) * yScale);
    return LayoutBuilder(
      builder: (context, constraints) {
        _fit = textScale > 1.3
            ? 1
            : (constraints.maxWidth / canvasWidth).clamp(.1, 1);
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _transform.value = Matrix4.diagonal3Values(_fit, _fit, 1);
            }
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final status in SpaceStatus.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: spaceStatusColor(status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(spaceStatusLabel(status))),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Перемещайте и масштабируйте схему. Выбрать можно только свободное место.',
              style: TextStyle(color: AppColors.bodySecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Свободно: ${widget.spaces.where((s) => s.selectable).length} из ${widget.spaces.length}',
                    style: AppTypography.title,
                  ),
                ),
                IconButton(
                  tooltip: 'Сбросить масштаб',
                  onPressed: () =>
                      _transform.value = Matrix4.diagonal3Values(_fit, _fit, 1),
                  icon: const Icon(LucideIcons.locateFixed),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: SizedBox(
                height: 360,
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: .1,
                  maxScale: 3,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: canvasWidth,
                    height: canvasHeight,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0xFFF3F4F6)),
                        ),
                        Positioned(
                          left: 250 * xScale,
                          top: 0,
                          width: 100 * xScale,
                          height: canvasHeight,
                          child: const ColoredBox(color: Color(0xFFD1D5DB)),
                        ),
                        for (final space in widget.spaces)
                          Positioned(
                            left: space.x * xScale,
                            top: space.y * yScale,
                            width: cellWidth,
                            height: cellHeight,
                            child: Semantics(
                              label:
                                  'Место ${space.code}, ${spaceStatusLabel(space.displayStatus)}',
                              button: true,
                              enabled: space.selectable,
                              selected: _selected == space.id,
                              child: Tooltip(
                                message:
                                    '${space.code}: ${spaceStatusLabel(space.displayStatus)}',
                                child: Material(
                                  color: spaceStatusColor(space.displayStatus),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    side: BorderSide(
                                      color: _selected == space.id
                                          ? AppColors.primary
                                          : Colors.white,
                                      width: _selected == space.id ? 3 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    key: ValueKey('space-${space.id}'),
                                    onTap: space.selectable
                                        ? () => setState(
                                            () => _selected = space.id,
                                          )
                                        : null,
                                    child: Center(
                                      child: ExcludeSemantics(
                                        child: Text(
                                          space.code,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                space.displayStatus ==
                                                    SpaceStatus.reserved
                                                ? AppColors.foreground
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selected != null)
              AppCard(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Выбрано место ${widget.spaces.firstWhere((s) => s.id == _selected).code}',
                    style: AppTypography.title,
                  ),
                ),
              ),
            if (_selected != null && widget.onBook != null) ...[
              const SizedBox(height: 12),
              AppButton(
                label: 'Забронировать',
                onPressed: () => widget.onBook!(
                  widget.spaces.firstWhere((s) => s.id == _selected),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
