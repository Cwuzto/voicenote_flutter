import 'package:flutter/material.dart';

class AppSheetAction<T> {
  const AppSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final String? subtitle;
  final bool destructive;
  final bool selected;
}

Future<T?> showAppOptionSheet<T>({
  required BuildContext context,
  required String title,
  String? description,
  required List<AppSheetAction<T>> actions,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDCE8FA)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: actions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    final foregroundColor = action.destructive
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A);
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context, action.value),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: action.selected
                              ? const Color(0xFFEAF2FF)
                              : const Color(0xFFF8FBFF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: action.selected
                                ? colorScheme.primary.withValues(alpha: 0.28)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: action.selected
                                    ? Colors.white
                                    : const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                action.icon ??
                                    (action.destructive
                                        ? Icons.delete_outline_rounded
                                        : Icons.check_circle_outline_rounded),
                                color: action.selected
                                    ? colorScheme.primary
                                    : foregroundColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: foregroundColor,
                                    ),
                                  ),
                                  if (action.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      action.subtitle!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (action.selected)
                              Icon(
                                Icons.check_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Xac nhan',
  String cancelLabel = 'Huy',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final accent = destructive
          ? const Color(0xFFDC2626)
          : const Color(0xFF1565FF);
      return AlertDialog(
        scrollable: true,
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon ??
                (destructive
                    ? Icons.delete_outline_rounded
                    : Icons.help_outline_rounded),
            color: accent,
            size: 26,
          ),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: destructive ? const Color(0xFFDC2626) : accent,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
