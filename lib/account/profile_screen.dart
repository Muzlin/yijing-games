import 'package:flutter/material.dart';

import '../online/nickname_dialog.dart';
import '../ui/theme.dart';
import 'account_manager.dart';
import 'account_models.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editNick(BuildContext context) async {
    final user = AccountManager.instance.user;
    if (user == null) return;
    final nick = await showNicknameDialog(context, user.nick);
    if (nick == null || !context.mounted) return;
    try {
      await AccountManager.instance.updateNick(nick);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('游戏名称已更新')),
      );
    } on AccountException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _rebindBiometric(BuildContext context) async {
    final manager = AccountManager.instance;
    if (!manager.isLoggedIn) return;
    final ok = await manager.enableBiometric();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '指纹已重新绑定'
            : (manager.error ?? '重新绑定失败')),
      ),
    );
  }

  Future<void> _toggleBiometric(BuildContext context) async {
    final manager = AccountManager.instance;
    if (!manager.isLoggedIn) return;
    if (manager.biometricEnabled) {
      await manager.disableBiometric();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关闭指纹一键登录')),
      );
    } else {
      final ok = await manager.enableBiometric();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '已开启指纹一键登录，下次启动可用指纹进入'
              : (manager.error ?? '开启失败')),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出账号？'),
        content: Text(
          AccountManager.instance.biometricEnabled
              ? '退出后仍可用指纹一键登录。如需彻底关闭指纹，请先在个人中心关闭「指纹一键登录」。'
              : '退出后需要重新登录才能联机对战，本地人机对局不受影响。',
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消',
                style: TextStyle(color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AccountManager.instance.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: AccountManager.instance,
            builder: (context, _) {
              final manager = AccountManager.instance;
              final user = manager.user;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _RoundButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            const Text(
                              '个人中心',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 2,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        if (user == null)
                          _LoggedOutCard(
                            onLogin: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                          )
                        else ...[
                          Center(
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF2E4A42), Color(0xFF101C1E)],
                                ),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.12),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                user.nick.isEmpty ? '?' : user.nick.substring(0, 1),
                                style: const TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            user.nick,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: _RatingChip(rating: user.rating),
                          ),
                          const SizedBox(height: 24),
                          _StatsRow(
                            wins: user.wins,
                            losses: user.losses,
                            draws: user.draws,
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              children: [
                                _InfoRow(
                                  icon: Icons.phone_iphone_rounded,
                                  label: '手机号',
                                  value: user.maskedPhone,
                                ),
                                const Divider(height: 22),
                                _InfoRow(
                                  icon: Icons.fingerprint_rounded,
                                  label: '账号 ID',
                                  value: user.uid,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BiometricTile(
                            enabled: manager.biometricEnabled,
                            available: manager.biometricAvailable,
                            onChanged: () => _toggleBiometric(context),
                            onRebind: () => _rebindBiometric(context),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _editNick(context),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('修改游戏名称'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gold,
                                side: BorderSide(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.45),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => _logout(context),
                            child: const Text(
                              '退出登录',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Text(
                          '账号系统与联机服务使用手机号 + 密码登录，'
                          '密码经 PBKDF2 加密后存储，不会明文保存。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.6,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoggedOutCard extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoggedOutCard({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 34, color: AppColors.gold),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有登录',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '登录后可以和在线玩家匹配对弈，\n保存你的游戏名称与战绩。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF231A08),
              ),
              child: const Text('登录 / 注册'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final int rating;

  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            '$rating',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'ELO',
            style: TextStyle(fontSize: 9, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _BiometricTile extends StatelessWidget {
  final bool enabled;
  final bool available;
  final VoidCallback onChanged;
  final VoidCallback onRebind;

  const _BiometricTile({
    required this.enabled,
    required this.available,
    required this.onChanged,
    required this.onRebind,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = !available
        ? '此设备不支持指纹或未录入指纹'
        : enabled
            ? '已开启 · 下次打开 App 可用指纹进入'
            : '开启后可用 Touch ID / 指纹一键登录';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? AppColors.gold.withValues(alpha: 0.4)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              size: 20,
              color: available
                  ? AppColors.gold
                  : AppColors.muted.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '指纹一键登录',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (enabled && available)
            IconButton(
              onPressed: onRebind,
              tooltip: '重新绑定指纹',
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.muted),
            ),
          Switch(
            value: enabled,
            onChanged: available ? (_) => onChanged() : null,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.55),
            activeThumbColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int wins;
  final int losses;
  final int draws;

  const _StatsRow({
    required this.wins,
    required this.losses,
    required this.draws,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _stat('胜', wins, AppColors.success),
          _divider(),
          _stat('负', losses, AppColors.danger),
          _divider(),
          _stat('和', draws, AppColors.muted),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface.withValues(alpha: 0.72),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 17, color: AppColors.ivory),
      ),
    );
  }
}
