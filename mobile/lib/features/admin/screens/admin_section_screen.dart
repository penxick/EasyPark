import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/ui_kit.dart';

class AdminSectionScreen extends StatelessWidget {
  const AdminSectionScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.page,
    child: AppCard(
      title: title,
      description: 'Раздел пока недоступен',
      child: AppButton(
        label: 'На главную',
        onPressed: () => context.go('/admin'),
        variant: AppButtonVariant.outline,
      ),
    ),
  );
}
