import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading_indicator.dart';
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
  final _hours = TextEditingController(text: '1');
  final _minutePart = TextEditingController(text: '0');
  String _mode = 'PLANNED', _payment = 'CARD';
  int get _minutes =>
      (int.tryParse(_hours.text) ?? -10000) * 60 +
      (int.tryParse(_minutePart.text) ?? -10000);
  bool get _validTime =>
      _minutes >= 1 &&
      _minutes <= 1440 &&
      (int.tryParse(_minutePart.text) ?? -1) >= 0 &&
      (int.tryParse(_minutePart.text) ?? 60) < 60;
  @override
  void dispose() {
    _hours.dispose();
    _minutePart.dispose();
    super.dispose();
  }

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
    if (!_uncertain && _mode == 'PLANNED' && !_validTime) {
      setState(
        () => _error =
            'Введите время от 1 минуты до 24 часов; минуты — от 0 до 59.',
      );
      return;
    }
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
        final result = await widget.repository.createSession(
          place.space.id,
          _mode,
          _payment,
          _minutes,
        );
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

  String _price(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} ₽';

  Widget _modeCard(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) => Material(
    color: _mode == value ? const Color(0xFFEFF6FF) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: _mode == value ? AppColors.primary : AppColors.border,
        width: 2,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _busy || _uncertain ? null : () => setState(() => _mode = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        child: Column(
          children: [
            Icon(
              icon,
              color: _mode == value
                  ? AppColors.primary
                  : AppColors.mutedForeground,
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
  Widget _timeInput(
    TextEditingController controller,
    String label,
    String key,
  ) => TextField(
    key: ValueKey(key),
    controller: controller,
    enabled: !_busy && !_uncertain,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(2),
    ],
    textAlign: TextAlign.center,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
    ),
    onChanged: (_) => setState(() {}),
  );
  Widget _paymentOption(String value, String label, IconData icon) =>
      OutlinedButton(
        onPressed: _busy || _uncertain
            ? null
            : () => setState(() => _payment = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                _payment == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label)),
            ],
          ),
        ),
      );

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Бронирование места'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Закрыть',
            onPressed: _busy ? null : _back,
            icon: const Icon(Icons.close),
          ),
        ],
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
                        Text(
                          'Место ${place.space.code} · ${place.parking.pricePerHour.toStringAsFixed(2)} ₽/час',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _modeCard(
                                'PLANNED',
                                'Запланировать',
                                'Задать время заранее',
                                Icons.access_time,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _modeCard(
                                'METERED',
                                'По счётчику',
                                'Платите за факт',
                                Icons.timer_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_mode == 'PLANNED') ...[
                          const Text(
                            'Планируемое время парковки',
                            style: AppTypography.title,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _timeInput(
                                  _hours,
                                  'Часы',
                                  'booking-hours',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _timeInput(
                                  _minutePart,
                                  'Минуты',
                                  'booking-minutes',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              children: [
                                const Text('Предварительная стоимость'),
                                Text(
                                  _validTime
                                      ? _price(
                                          ((place.parking.pricePerHour * 100)
                                                          .round() *
                                                      _minutes +
                                                  30) ~/
                                              60,
                                        )
                                      : '—',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              border: Border.all(
                                color: const Color(0xFFFCD34D),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Как это работает',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'После подтверждения прибытия запустится счётчик времени. Вы увидите его на главном экране. Когда выедете — нажмите «Завершить» и подтвердите демонстрационную оплату фактически проведённого времени.',
                                  style: TextStyle(color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        const Text('Способ оплаты', style: AppTypography.title),
                        const SizedBox(height: 8),
                        _paymentOption(
                          'CARD',
                          'Банковская карта',
                          Icons.credit_card,
                        ),
                        const SizedBox(height: 8),
                        _paymentOption('SBP', 'СБП', Icons.phone_android),
                        const SizedBox(height: 12),
                        const Text(
                          'Оплата демонстрационная. Деньги не списываются. Таймер начнётся только после подтверждения прибытия.',
                          style: AppTypography.small,
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
                              : _mode == 'PLANNED'
                              ? 'Оплатить и забронировать'
                              : 'Начать парковку',
                          loading: _busy,
                          onPressed: place.space.selectable && !_blocked
                              ? () => _submit(place)
                              : null,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _busy ? null : _back,
                          child: const Text('Отмена'),
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
