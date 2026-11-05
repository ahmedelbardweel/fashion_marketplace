import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Shared sheet layout for customer confirmations and results.
class CustomerActionSheet extends StatelessWidget {
  const CustomerActionSheet({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AppBottomSheetScaffold(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
            child: title!,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        content,
        for (final action in actions) ...[
          const SizedBox(height: AppSpacing.sm),
          action,
        ],
      ],
    ),
  );
}
