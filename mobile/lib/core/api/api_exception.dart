enum ApiErrorKind {
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  network,
  timeout,
  invalidResponse,
  invalidRequest,
  unexpected,
}

class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode});

  final ApiErrorKind kind;
  final int? statusCode;

  String get message => switch (kind) {
    ApiErrorKind.unauthorized => 'Необходимо войти в аккаунт.',
    ApiErrorKind.forbidden => 'Недостаточно прав для этого действия.',
    ApiErrorKind.notFound => 'Запрошенные данные не найдены.',
    ApiErrorKind.validation => 'Проверьте введённые данные.',
    ApiErrorKind.server => 'Сервис временно недоступен. Попробуйте позже.',
    ApiErrorKind.network => 'Не удалось подключиться к серверу.',
    ApiErrorKind.timeout => 'Сервер не ответил вовремя. Попробуйте ещё раз.',
    ApiErrorKind.invalidResponse => 'Получен некорректный ответ сервера.',
    ApiErrorKind.invalidRequest => 'Не удалось подготовить запрос.',
    ApiErrorKind.unexpected => 'Не удалось выполнить действие.',
  };

  @override
  String toString() => 'ApiException(${kind.name}, statusCode: $statusCode)';
}
