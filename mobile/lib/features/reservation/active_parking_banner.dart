import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

class ActiveParkingBanner extends StatefulWidget {
  const ActiveParkingBanner({super.key, required this.repository});
  final ReservationRepository repository;
  @override
  State<ActiveParkingBanner> createState() => _ActiveParkingBannerState();
}

class _ActiveParkingBannerState extends State<ActiveParkingBanner> {
  Reservation? active;
  final clock = Stopwatch()..start();
  Timer? timer;
  int ticks = 0;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !TickerMode.of(context)) return;
      if (active != null) setState(() {});
      if (++ticks % 10 == 0) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    try {
      final items = (await widget.repository.mine()).where(
        (r) => r.active && r.mode != null,
      );
      if (mounted) {
        setState(() {
          active = items.isEmpty ? null : items.first;
          clock.reset();
        });
      }
    } catch (_) {
      /* Existing reservation screen exposes retry and API errors. */
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = active;
    if (r == null) return const SizedBox.shrink();
    final seconds =
        r.elapsedSeconds +
        (r.actualStartTime != null ? clock.elapsed.inSeconds : 0);
    String two(int n) => n.toString().padLeft(2, '0');
    return Material(
      color: const Color(0xFFEFF6FF),
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(
          r.actualStartTime == null
              ? 'Ожидаем автомобиль'
              : 'Парковка ${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}',
        ),
        subtitle: const Text('Открыть активную парковку'),
        onTap: () => context.go('/reservations'),
      ),
    );
  }
}
