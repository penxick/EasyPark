import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'reservation.dart';
import 'reservation_repository.dart';

class ReservationCard extends StatefulWidget {
  const ReservationCard({
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
  State<ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends State<ReservationCard> {
  late Reservation _reservation = widget.reservation;
  bool _busy = false, _confirming = false;
  String? _error;
  @override
  void didUpdateWidget(ReservationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservation != widget.reservation) {
      _reservation = widget.reservation;
    }
  }

  Future<void> _cancel() async {
    if (_busy || _confirming) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить бронирование?'),
        content: const Text(
          'После отмены место станет доступно другим водителям, если оно свободно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.cancel(_reservation.id);
      if (!mounted) return;
      setState(() => _reservation = updated);
      widget.onChanged?.call(updated);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 409
              ? 'Бронирование уже завершено. Обновите список.'
              : e.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.place?.parking.name ?? 'Бронирование №${_reservation.id}',
          style: AppTypography.title,
        ),
        const SizedBox(height: 8),
        Text(
          'Место ${widget.place?.space.code ?? '#${_reservation.parkingSpaceId}'}',
        ),
        Text(
          _reservation.statusLabel,
          style: const TextStyle(color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text('Начало: ${reservationTime(_reservation.startTime)}'),
        Text('Окончание: ${reservationTime(_reservation.endTime)}'),
        Text('Стоимость: ${rubles(_reservation.totalPrice)}'),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.destructive)),
        ],
        if (_reservation.active) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Отменить бронирование',
            variant: AppButtonVariant.outline,
            loading: _busy,
            onPressed: _cancel,
          ),
        ],
      ],
    ),
  );
}
