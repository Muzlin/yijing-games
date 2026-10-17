import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';
import 'account_manager.dart';
import 'account_models.dart';

class LoginScreen extends StatefulWidget {
  final bool startInRegister;

  const LoginScreen({super.key, this.startInRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _register = widget.startInRegister;
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _nick = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    final password = _password.text;
    final nick = _nick.text.trim();
    if (phone.length < 6 || phone.length > 20) {
      setState(() => _error = '请输入 6-20 位手机号');
      return;
    }
    if (password.length < 6 || password.length > 64) {
      setState(() => _error = '密码需 6-64 位');
      return;
    }
    if (_register && (nick.length < 2 || nick.length > 12)) {
      setState(() => _error = '游戏名称需 2-12 个字符');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = _register
          ? await AccountManager.instance.register(
              phone: phone,
              password: password,
              nick: nick,
            )
          : await AccountManager.instance.login(
              phone: phone,
              password: password,
            );
      if (!mounted) return;
      Navigator.pop(context, user);
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '登录失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                        Text(
                          _register ? '创建账号' : '账号登录',
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A4240), Color(0xFF101C1E)],
                          ),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 34, color: AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _register ? '加入弈境' : '欢迎回来',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _register
                          ? '注册后即可与在线玩家对弈'
                          : '登录后联机匹配、保存昵称与战绩',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ModeToggle(
                      register: _register,
                      onChanged: (value) => setState(() {
                        _register = value;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    _Field(
                      controller: _phone,
                      icon: Icons.phone_iphone_rounded,
                      hint: '手机号',
                      keyboardType: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _password,
                      icon: Icons.lock_outline_rounded,
                      hint: '密码（至少 6 位）',
                      obscure: _obscure,
                      trailing: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 19,
                          color: AppColors.muted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 12),
                      _Field(
                        controller: _nick,
                        icon: Icons.badge_outlined,
                        hint: '游戏名称（联机时显示）',
                        formatters: [
                          LengthLimitingTextInputFormatter(12),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF231A08),
                          disabledBackgroundColor:
                              AppColors.gold.withValues(alpha: 0.4),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF231A08),
                                ),
                              )
                            : Text(_register ? '注册并登录' : '登录'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '先以游客身份逛逛',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '账号仅用于联机对战、昵称与战绩，密码经加密存储。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.5,
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
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool register;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.register, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment('登录', !register, () => onChanged(false)),
          ),
          Expanded(
            child: _segment('注册', register, () => onChanged(true)),
          ),
        ],
      ),
    );
  }

  Widget _segment(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.gold : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
        prefixIcon: Icon(icon, size: 19, color: AppColors.muted),
        suffixIcon: trailing,
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
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
