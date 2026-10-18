import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'account_manager.dart';
import 'login_screen.dart';

/// Shows a one-tap fingerprint lock screen when biometric quick login is on.
class BiometricGate extends StatefulWidget {
  final Widget child;

  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _busy = false;
  String? _message;

  Future<void> _fingerprint() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await AccountManager.instance.biometricLogin();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _message = AccountManager.instance.error ?? '指纹验证未通过';
      }
    });
  }

  Future<void> _passwordLogin() async {
    final user = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (user != null && mounted) {
      AccountManager.instance.unlock();
    }
  }

  void _guest() {
    AccountManager.instance.logout();
    AccountManager.instance.unlock();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccountManager.instance,
      builder: (context, _) {
        final manager = AccountManager.instance;
        if (!manager.locked) return widget.child;
        return PopScope(
          canPop: false,
          child: Scaffold(
            body: PageBackground(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
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
                                      AppColors.gold.withValues(alpha: 0.14),
                                  blurRadius: 36,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 54,
                              color: _busy
                                  ? AppColors.gold.withValues(alpha: 0.5)
                                  : AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            '指纹一键登录',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            manager.user == null
                                ? '验证指纹以进入弈境棋牌'
                                : '你好，${manager.user!.nick}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _fingerprint,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF231A08),
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint_rounded,
                                      size: 22),
                              label: Text(_busy ? '正在验证…' : '验证指纹进入'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: const Color(0xFF231A08),
                              ),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          if (!manager.biometricAvailable) ...[
                            const SizedBox(height: 12),
                            const Text(
                              '此设备暂不支持指纹，请使用密码登录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: _busy ? null : _passwordLogin,
                            child: const Text(
                              '使用密码登录',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ivory,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _guest,
                            child: const Text(
                              '以游客身份进入',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '指纹数据只保存在设备的安全芯片中，'
                            '弈境不会读取或上传你的指纹。',
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
