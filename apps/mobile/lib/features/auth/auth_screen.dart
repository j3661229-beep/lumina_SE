import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import 'auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  String? _error;

  Future<void> _emailAuth() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      if (!_isLogin) {
        // ── SIGN UP ──
        // Step 1: backend creates user with email auto-confirmed (service role)
        try {
          await ApiClient.instance.post('/auth/register', data: {
            'email': email,
            'password': pass,
            'displayName': email.split('@')[0],
          });
        } on DioException catch (e) {
          final serverMsg = e.response?.data?['error'] as String?;
          // 409 = already exists → just proceed to sign in
          if (e.response?.statusCode != 409) {
            throw Exception(serverMsg ?? 'Registration failed. Check connection.');
          }
        }
        // Step 2: sign in directly with Supabase (email is confirmed, session valid)
        await Supabase.instance.client.auth.signInWithPassword(
          email: email, password: pass,
        );
      } else {
        // ── SIGN IN ──
        // Try direct Supabase first (works when internet is available)
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: email, password: pass,
          );
        } on AuthException catch (authErr) {
          // Rethrow auth errors (wrong password, etc.) — don't fall back
          throw Exception(authErr.message);
        } catch (netErr) {
          // Network error? Fall back to backend proxy (college WiFi mode)
          if (netErr.toString().contains('SocketException') ||
              netErr.toString().contains('hostname') ||
              netErr.toString().contains('Failed host lookup')) {
            final Map<String, dynamic> res = await ApiClient.instance.post(
              '/auth/signin', data: { 'email': email, 'password': pass },
            );
            // We got tokens from proxy — need to inject full session
            // Use recoverSession with concatenated token string (Supabase Flutter v2)
            final accessToken = res['accessToken'] as String;
            final refreshToken = res['refreshToken'] as String;
            await Supabase.instance.client.auth.setSession(accessToken);
            // Store refresh token in local prefs for manual refresh later
          } else {
            rethrow;
          }
        }
      }
      // GoRouter listens to onAuthStateChange → auto-navigates to /home
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
      return 'Network error. Backend: 10.10.53.131:3000\nMake sure you\'re on the same WiFi.';
    if (raw.contains('Email not confirmed'))
      return 'Account not confirmed. Create a new account or contact support.';
    return raw;
  }

  Future<void> _googleAuth() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.lumina://login-callback/',
      );
      // GoRouter's onAuthStateChange listener will auto-navigate to /home
      // when the deep link comes back and session is established
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6), cs.surface],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                // Logo
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20, offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 44),
                ),
                const SizedBox(height: 20),
                Text('Lumina', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Your proactive engineering sidekick',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 40),

                // Auth card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Tabs
                    Row(children: [
                      Expanded(child: _TabBtn(label: 'Sign In', selected: _isLogin,
                        onTap: () => setState(() { _isLogin = true; _error = null; }))),
                      Expanded(child: _TabBtn(label: 'Sign Up', selected: !_isLogin,
                        onTap: () => setState(() { _isLogin = false; _error = null; }))),
                    ]),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      obscureText: true,
                      onSubmitted: (_) => _emailAuth(),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _emailAuth,
                      child: _isLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isLogin ? 'Sign In' : 'Create Account'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _googleAuth,
                      icon: const Icon(Icons.g_mobiledata, size: 22),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Theme.of(context).colorScheme.outline,
        )),
      ),
    );
  }
}
