import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';
import 'auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _isLoading  = false;
  bool _isLogin    = true;
  bool _obscurePass = true;
  String? _error;

  late AnimationController _bgCtrl;
  late AnimationController _cardCtrl;
  late Animation<double>   _bgAnim;
  late Animation<Offset>   _cardSlide;
  late Animation<double>   _cardFade;

  @override
  void initState() {
    super.initState();
    _bgCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bgAnim   = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _emailAuth() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      if (!_isLogin) {
        try {
          await ApiClient.instance.post('/auth/register', data: {
            'email': email, 'password': pass,
            'displayName': email.split('@')[0],
          });
        } on DioException catch (e) {
          final serverMsg = e.response?.data?['error'] as String?;
          if (e.response?.statusCode != 409)
            throw Exception(serverMsg ?? 'Registration failed. Check connection.');
        }
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      } else {
        try {
          await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
        } on AuthException catch (authErr) {
          throw Exception(authErr.message);
        } catch (netErr) {
          if (netErr.toString().contains('SocketException') ||
              netErr.toString().contains('hostname') ||
              netErr.toString().contains('Failed host lookup')) {
            final Map<String, dynamic> res = await ApiClient.instance
                .post('/auth/signin', data: {'email': email, 'password': pass});
            final accessToken = res['accessToken'] as String;
            await Supabase.instance.client.auth.setSession(accessToken);
          } else { rethrow; }
        }
      }
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendly(String raw) {
    raw = raw.replaceAll('Exception: ', '');
    if (raw.contains('Invalid login credentials') || raw.contains('invalid_credentials'))
      return 'Wrong email or password.';
    if (raw.contains('rate limit') || raw.contains('429'))
      return 'Too many attempts. Wait 60s and try again.';
    if (raw.contains('already registered') || raw.contains('already exists'))
      return 'Email already registered. Try Sign In.';
    if (raw.contains('SocketException') || raw.contains('hostname') || raw.contains('connection'))
      return 'Network error. Make sure you\'re on the same WiFi.';
    if (raw.contains('Email not confirmed'))
      return 'Account not confirmed. Create a new account.';
    return raw;
  }

  Future<void> _googleAuth() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.lumina://login-callback/',
      );
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF050714) : const Color(0xFF4F46E5),
      body: Stack(
        children: [
          // ── Animated background orbs ────────────────────────────────────
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => Stack(children: [
              Positioned(
                top: -60 + (_bgAnim.value * 30),
                left: -80 + (_bgAnim.value * 20),
                child: _BgOrb(size: 320,
                  color: AppColors.violet.withOpacity(isDark ? 0.25 : 0.35)),
              ),
              Positioned(
                bottom: 100 - (_bgAnim.value * 40),
                right: -60 + (_bgAnim.value * 25),
                child: _BgOrb(size: 260,
                  color: AppColors.cyan.withOpacity(isDark ? 0.12 : 0.2)),
              ),
              Positioned(
                top: size.height * 0.4 + (_bgAnim.value * 20),
                left: size.width * 0.6,
                child: _BgOrb(size: 200,
                  color: AppColors.indigo.withOpacity(isDark ? 0.2 : 0.3)),
              ),
            ]),
          ),

          // Mesh dots
          Positioned.fill(child: CustomPaint(painter: _AuthMeshPainter())),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: Column(children: [
                    const SizedBox(height: 48),

                    // Logo
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.indigo, AppColors.violet],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.indigo.withOpacity(0.5),
                            blurRadius: 28, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 18),

                    // Brand
                    const Text('Lumina', style: TextStyle(
                      fontFamily: 'Syne', fontSize: 40, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1)),
                    const SizedBox(height: 8),
                    Text(
                      'Your proactive engineering sidekick',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
                    ),
                    const SizedBox(height: 36),

                    // ── Auth card ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xE6111430)
                            : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white.withOpacity(0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                            blurRadius: 40, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(children: [
                              _AuthTab(label: 'Sign In', selected: _isLogin,
                                isDark: isDark,
                                onTap: () => setState(() { _isLogin = true; _error = null; })),
                              _AuthTab(label: 'Sign Up', selected: !_isLogin,
                                isDark: isDark,
                                onTap: () => setState(() { _isLogin = false; _error = null; })),
                            ]),
                          ),
                          const SizedBox(height: 22),

                          // Email field
                          _GlowField(
                            ctrl: _emailCtrl,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            isDark: isDark,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          _GlowField(
                            ctrl: _passCtrl,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            isDark: isDark,
                            obscure: _obscurePass,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: isDark
                                    ? Colors.white.withOpacity(0.4)
                                    : const Color(0xFF64748B),
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                            onSubmitted: (_) => _emailAuth(),
                          ),

                          // Error
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.rose.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.rose, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!,
                                  style: const TextStyle(
                                    color: AppColors.rose, fontSize: 12, height: 1.4))),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Primary CTA
                          GestureDetector(
                            onTap: _isLoading ? null : _emailAuth,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [AppColors.indigo, AppColors.violet],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight),
                                color: _isLoading
                                    ? Colors.white.withOpacity(0.1)
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.indigo.withOpacity(0.45),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6)),
                                      ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white))
                                    : Text(
                                        _isLogin ? 'Sign In' : 'Create Account',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          fontFamily: 'Syne',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Divider
                          Row(children: [
                            Expanded(child: Divider(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFFE2E8F0))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.35)
                                      : const Color(0xFF94A3B8))),
                            ),
                            Expanded(child: Divider(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFFE2E8F0))),
                          ]),
                          const SizedBox(height: 14),

                          // Google
                          GestureDetector(
                            onTap: _isLoading ? null : _googleAuth,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 12,
                                          offset: const Offset(0, 2)),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('G',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF4285F4),
                                      fontFamily: 'Syne',
                                    )),
                                  const SizedBox(width: 10),
                                  Text('Continue with Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.8)
                                          : const Color(0xFF374151),
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text('Lumina · Built for students, by engineers',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11)),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background orb ─────────────────────────────────────────────────────────────
class _BgOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _BgOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _AuthMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing)
      for (double y = 0; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.0, paint);
  }
  @override bool shouldRepaint(_) => false;
}

// ── Auth tab ───────────────────────────────────────────────────────────────────
class _AuthTab extends StatelessWidget {
  final String label;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _AuthTab({required this.label, required this.selected,
    required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.indigo, AppColors.violet],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [const BoxShadow(
                  color: Color(0x336366F1), blurRadius: 10, offset: Offset(0, 3))]
              : null,
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13,
            fontFamily: 'Syne',
            color: selected
                ? Colors.white
                : (isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF94A3B8)),
          )),
      ),
    ),
  );
}

// ── Glow text field ────────────────────────────────────────────────────────────
class _GlowField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isDark, obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  const _GlowField({
    required this.ctrl, required this.label, required this.icon,
    required this.isDark, this.obscure = false, this.keyboardType,
    this.suffixIcon, this.onSubmitted,
  });

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused ? AppColors.indigo : Colors.transparent;
    final bgColor = widget.isDark
        ? Colors.white.withOpacity(_focused ? 0.08 : 0.05)
        : (const Color(0xFFF8FAFC));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.indigo
              : (widget.isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFE2E8F0)),
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [const BoxShadow(
                color: Color(0x336366F1), blurRadius: 12, offset: Offset(0, 2))]
            : null,
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.ctrl,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _focused
                  ? AppColors.indigo
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.4)
                      : const Color(0xFF94A3B8)),
              fontSize: 13,
            ),
            prefixIcon: Icon(widget.icon,
              color: _focused
                  ? AppColors.indigo
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.35)
                      : const Color(0xFF94A3B8)),
              size: 19),
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
