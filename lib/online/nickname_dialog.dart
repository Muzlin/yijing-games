import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';

/// Edits the nickname shown to online opponents.
Future<String?> showNicknameDialog(
  BuildContext context,
  String initial,
) async {
  final controller = TextEditingController(text: initial);
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Row(
              children: [
                Icon(Icons.badge_rounded, size: 20, color: AppColors.gold),
                SizedBox(width: 8),
                Text('你的游戏名称'),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '联机对局和排行榜中会显示这个名字。',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 12,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(12),
                    ],
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '例如：清风棋客',
                      hintStyle: const TextStyle(color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      counterStyle: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                    onSubmitted: (_) {
                      final value = controller.text.trim();
                      if (value.length < 2) {
                        setState(() => error = '名称至少 2 个字符');
                        return;
                      }
                      Navigator.pop(context, value);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '取消',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.length < 2) {
                    setState(() => error = '名称至少 2 个字符');
                    return;
                  }
                  Navigator.pop(context, value);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF231A08),
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
