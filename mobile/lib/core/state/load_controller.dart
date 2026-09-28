import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import 'load_state.dart';

class LoadController<T> extends ChangeNotifier {
  LoadState<T> _state = LoadIdle<T>();
  LoadState<T> get state => _state;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load(Future<T> Function() operation) async {
    if (_disposed) return;
    final generation = ++_generation;
    _state = LoadInProgress<T>();
    notifyListeners();
    LoadState<T> result;
    try {
      result = LoadSuccess(await operation());
    } catch (error) {
      result = LoadFailure(
        error is ApiException
            ? error
            : const ApiException(ApiErrorKind.unexpected),
      );
    }
    if (!_disposed && generation == _generation) {
      _state = result;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
