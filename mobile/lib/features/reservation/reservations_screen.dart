import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/state/load_controller.dart';
import '../../core/state/load_state.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'reservation_card.dart';
import 'reservation_repository.dart';
import 'reservation.dart';
import '../../core/theme/app_tokens.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key, required this.repository});
  final ReservationRepository repository;
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with WidgetsBindingObserver {
  final _loader = LoadController<List<ReservationEntry>>();
  ReservationCategory _category = ReservationCategory.active;
  final Map<int, Reservation> _updates = {};
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() => unawaited(_loader.load(widget.repository.history));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_visible) _refresh();
    _visible = visible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ReservationCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    selectedColor: const Color(0xFFEFF6FF),
                    side: BorderSide(
                      color: _category == category
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Обновить бронирования',
              variant: AppButtonVariant.outline,
              onPressed: _refresh,
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: _loader,
              builder: (context, _) {
                final state = _loader.state;
                if (state is LoadFailure<List<ReservationEntry>>) {
                  return AppErrorView(
                    message: 'Не удалось загрузить бронирования.',
                    onRetry: _refresh,
                  );
                }
                if (state is! LoadSuccess<List<ReservationEntry>>) {
                  return const AppLoadingIndicator(
                    label: 'Загрузка бронирований…',
                  );
                }
                final items = state.data
                    .map(
                      (entry) => ReservationEntry(
                        _updates[entry.reservation.id] ?? entry.reservation,
                        entry.place,
                      ),
                    )
                    .where((entry) => entry.reservation.category == _category)
                    .toList();
                if (items.isEmpty) {
                  return Text(
                    _category.emptyMessage,
                    textAlign: TextAlign.center,
                  );
                }
                return Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ReservationCard(
                          key: ValueKey(item.reservation.id),
                          reservation: item.reservation,
                          repository: widget.repository,
                          place: item.place,
                          onChanged: (reservation) => setState(() {
                            _updates[reservation.id] = reservation;
                          }),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
