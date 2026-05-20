import 'package:flutter/material.dart';

import '../main.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 10),
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

