import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';

class EasyParkApp extends StatefulWidget {
  const EasyParkApp({super.key, this.router, this.auth});
  final GoRouter? router;
  final AuthController? auth;
  @override
  State<EasyParkApp> createState() => _EasyParkAppState();
}

class _EasyParkAppState extends State<EasyParkApp> {
  AuthController? _auth;
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    if (widget.router != null) {
      _router = widget.router!;
    } else {
      _auth = widget.auth ?? AuthController.platform();
      _router = createAppRouter(auth: _auth!);
      unawaited(_auth!.restore());
    }
  }

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    if (widget.auth == null) _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'EasyPark',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: _router,
  );
}
