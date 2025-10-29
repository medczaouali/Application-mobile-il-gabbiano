import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool isClient;
  final bool isBanned;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.isClient = false,
    this.isBanned = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
