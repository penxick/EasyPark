import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/app_top_bar.dart';
import 'reservation.dart';
import 'reservation_card.dart';
import 'reservation_repository.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.parkingId,
    required this.spaceId,
    required this.repository,
  });
  final String parkingId, spaceId;
  final ReservationRepository repository;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late Future<BookingContext> _place;
  int _minutes = 60;
  bool _busy = false, _uncertain = false, _blocked = false;
  String? _error;
  Reservation? _result;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _place = widget.repository.contextFor(widget.parkingId, widget.spaceId);
  }

  Future<void> _submit(BookingContext place) async {
    if (_busy || _blocked || _result != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_uncertain) {
        final found = (await widget.repository.mine()).where(
          (r) => r.parkingSpaceId == place.space.id && r.active,
        );
        if (!mounted) return;
        setState(() {
          _result = found.isEmpty ? null : found.first;
          _uncertain = false;
        });
      } else {
        final result = await widget.repository.create(place.space.id, _minutes);
        if (mounted) setState(() => _result = result);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 409 || e.statusCode == 404) {
          _blocked = true;
          _error =
              'Место больше недоступно. Вернитесь к схеме и выберите другое.';
        } else if (e.kind == ApiErrorKind.validation ||
            e.kind == ApiErrorKind.invalidRequest ||
            e.kind == ApiErrorKind.unauthorized ||
            e.kind == ApiErrorKind.forbidden) {
          _error = e.message;
        } else {
          _uncertain = true;
          _error =
              'Не удалось подтвердить результат. Проверьте бронирования перед повторной попыткой.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/parking/${widget.parkingId}/spaces');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppTopBar(
        title: 'Бронирование места',
        onBack: _busy ? null : _back,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<BookingContext>(
          future: _place,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: SingleChildScrollView(
                  child: AppErrorView(
                    message: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Не удалось загрузить место.',
                    onRetry: () => setState(_load),
                  ),
                ),
              );
            }
            final place = snapshot.data;
            if (place == null) {
              return const Center(
                child: AppLoadingIndicator(label: 'Загрузка места…'),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_result != null) ...[
                        Text(
                          _result!.status == 'CANCELLED'
                              ? 'Бронирование отменено'
                              : 'Бронирование подтверждено',
                          style: AppTypography.heading2,
                        ),
                        const SizedBox(height: 16),
                        ReservationCard(
                          reservation: _result!,
                          repository: widget.repository,
                          place: place,
                          onChanged: (result) =>
                              setState(() => _result = result),
                        ),
                        const SizedBox(height: 16),
                        AppButton(label: 'К схеме парковки', onPressed: _back),
                      ] else ...[
                        const Text('Выберите длительность парковки'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                place.parking.name,
                                style: AppTypography.title,
                              ),
                              Text('Место ${place.space.code}'),
                              Text('Тариф: ${place.parking.formattedPrice}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Длительность', style: AppTypography.title),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in {
                              30: '30 минут',
                              60: '1 час',
                              120: '2 часа',
                              180: '3 часа',
                            }.entries)
                              ChoiceChip(
                                selectedColor: const Color(0xFFEFF6FF),
                                side: BorderSide(
                                  color: _minutes == entry.key
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: _minutes == entry.key ? 2 : 1,
                                ),
                                label: Text(entry.value),
                                selected: _minutes == entry.key,
                                onSelected: _busy || _uncertain
                                    ? null
                                    : (_) =>
                                          setState(() => _minutes = entry.key),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Стоимость: ${rubles(((place.parking.pricePerHour * 100).round() * _minutes / 60).round() / 100)}',
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Бронирование начнётся сразу после подтверждения. Итоговую стоимость рассчитает сервер.',
                        ),
                        if (!place.space.selectable)
                          const Text(
                            'Место больше недоступно. Выберите другое.',
                            style: TextStyle(color: AppColors.destructive),
                          ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.destructive,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(
                          label: _uncertain
                              ? 'Проверить бронирования'
                              : 'Подтвердить бронирование',
                          loading: _busy,
                          onPressed: place.space.selectable && !_blocked
                              ? () => _submit(place)
                              : null,
                          fullWidth: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
