import 'dart:async';

import 'package:easypark/core/api/api_exception.dart';
import 'package:easypark/core/state/load_controller.dart';
import 'package:easypark/core/state/load_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle -> loading -> success and retry after failure', () async {
    final controller = LoadController<int>();
    addTearDown(controller.dispose);
    expect(controller.state, isA<LoadIdle<int>>());
    final task = Completer<int>();
    final loading = controller.load(() => task.future);
    expect(controller.state, isA<LoadInProgress<int>>());
    task.complete(42);
    await loading;
    expect((controller.state as LoadSuccess<int>).data, 42);
    await controller.load(
      () async => throw const ApiException(ApiErrorKind.network),
    );
    expect(
      (controller.state as LoadFailure<int>).error.kind,
      ApiErrorKind.network,
    );
    await controller.load(() async => 7);
    expect((controller.state as LoadSuccess<int>).data, 7);
  });

  test('an older result cannot replace a newer result', () async {
    final controller = LoadController<int>();
    addTearDown(controller.dispose);
    final old = Completer<int>();
    final pending = controller.load(() => old.future);
    await controller.load(() async => 2);
    old.complete(1);
    await pending;
    expect((controller.state as LoadSuccess<int>).data, 2);
  });

  test(
    'disposed controller ignores pending results and future loads',
    () async {
      final controller = LoadController<int>();
      final task = Completer<int>();
      var notifications = 0;
      controller.addListener(() => notifications++);
      final pending = controller.load(() => task.future);
      controller.dispose();
      task.complete(1);
      await pending;
      await controller.load(() async => fail('must not run after dispose'));
      expect(notifications, 1);
    },
  );

  test('unexpected errors produce a safe message', () async {
    final controller = LoadController<int>();
    addTearDown(controller.dispose);
    await controller.load(
      () async => throw StateError('private implementation details'),
    );
    final error = (controller.state as LoadFailure<int>).error;
    expect(error.kind, ApiErrorKind.unexpected);
    expect(error.message, isNot(contains('private')));
  });
}
