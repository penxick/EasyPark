import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

class ParkingSessionCard extends StatefulWidget {
  const ParkingSessionCard({
    super.key,
    required this.reservation,
    required this.repository,
    this.place,
    this.onChanged,
  });
  final Reservation reservation;
  final ReservationRepository repository;
  final BookingContext? place;
  final ValueChanged<Reservation>? onChanged;
  @override
  State<ParkingSessionCard> createState() => _ParkingSessionCardState();
}

class _ParkingSessionCardState extends State<ParkingSessionCard>
    with WidgetsBindingObserver {
  late Reservation current = widget.reservation;
  final clock = Stopwatch()..start();
  Timer? timer;
  bool busy = false, refreshing = false;
  String? error;
  int ticks = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !TickerMode.of(context)) return;
      setState(() {});
      if (++ticks % 10 == 0 && current.active) unawaited(refresh());
    });
  }

  void accept(Reservation next) {
    if (!mounted) return;
    setState(() {
      current = next;
      clock.reset();
      error = null;
    });
    widget.onChanged?.call(next);
  }

  @override
  void didUpdateWidget(ParkingSessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation != widget.reservation) {
      current = widget.reservation;
      clock.reset();
    }
  }

  Future<void> refresh() async {
    if (refreshing || busy) return;
    refreshing = true;
    try {
      final items = await widget.repository.mine();
      final found = items.where((r) => r.id == current.id);
      if (found.isNotEmpty) accept(found.first);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Не удалось обновить состояние. Показаны последние данные.',
        );
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      accept(await widget.repository.finish(current.id));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    if (busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Отменить бронирование?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      accept(await widget.repository.cancel(current.id));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running =
        current.sessionState == 'PARKED' ||
        current.sessionState == 'WAITING_DEPARTURE';
    final seconds =
        current.elapsedSeconds + (running ? clock.elapsed.inSeconds : 0);
    String two(int n) => n.toString().padLeft(2, '0');
    final rate =
        int.tryParse(
          (current.hourlyRateSnapshot ?? '0.00').replaceAll('.', ''),
        ) ??
        0;
    final cents = (rate * seconds + 1800) ~/ 3600;
    String money(String? value) =>
        '${(value ?? '0.00').replaceAll('.', ',')} ₽';
    final status = switch (current.sessionState) {
      'WAITING_ARRIVAL' => 'Ожидаем прибытия автомобиля',
      'PARKED' => 'Парковка активна',
      'WAITING_DEPARTURE' =>
        'Ожидаем подтверждения выезда — таймер продолжается',
      'FINISHED' => 'Парковка завершена',
      _ => 'Бронирование отменено',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.place?.parking.name ?? 'Парковка · сессия №${current.id}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Место ${widget.place?.space.code ?? current.parkingSpaceId} · ${money(current.hourlyRateSnapshot)}/час',
            ),
            Text(status),
            if (current.actualStartTime != null)
              Text('Начало: ${reservationTime(current.actualStartTime!)}'),
            if (current.actualStartTime != null)
              Text(
                '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            if (current.plannedMinutes != null)
              Text(
                'План: ${current.plannedMinutes} мин · ${money(current.preliminaryPrice)}',
              ),
            Text(
              current.finalPrice != null
                  ? 'Итоговая стоимость: ${money(current.finalPrice)}'
                  : 'Текущая стоимость: ${cents ~/ 100},${two(cents % 100)} ₽',
            ),
            Text(
              'Способ оплаты: ${current.paymentMethod == 'SBP' ? 'СБП' : 'Банковская карта'}',
            ),
            const Text('Демонстрационная оплата. Деньги не списываются.'),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (current.sessionState == 'PARKED')
              FilledButton(
                onPressed: busy ? null : finish,
                child: const Text('Завершить парковку'),
              ),
            if (current.sessionState == 'WAITING_ARRIVAL')
              OutlinedButton(
                onPressed: busy ? null : cancel,
                child: const Text('Отменить бронирование'),
              ),
            if (current.active)
              TextButton(
                onPressed: busy ? null : refresh,
                child: const Text('Обновить состояние'),
              ),
          ],
        ),
      ),
    );
  }
}
