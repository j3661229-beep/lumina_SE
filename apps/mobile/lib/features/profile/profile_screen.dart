import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_tokens.dart';
import '../../shared/widgets/shimmer_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving  = false;

  final _displayNameCtrl = TextEditingController();
  final _collegeCtrl     = TextEditingController();
  final _branchCtrl      = TextEditingController();
  final _yearCtrl        = TextEditingController();
  final _rollNumberCtrl  = TextEditingController();
  final _divisionCtrl    = TextEditingController();
  final _batchCtrl       = TextEditingController();
  final _budgetCtrl      = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _displayNameCtrl.dispose(); _collegeCtrl.dispose(); _branchCtrl.dispose();
    _yearCtrl.dispose(); _rollNumberCtrl.dispose(); _divisionCtrl.dispose();
    _batchCtrl.dispose(); _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient.instance.get<dynamic>('/profile');
      if (res != null && mounted) {
        _displayNameCtrl.text = res['displayName'] ?? '';
        _collegeCtrl.text     = res['college']     ?? '';
        _branchCtrl.text      = res['branch']      ?? '';
        _yearCtrl.text        = res['year']?.toString() ?? '';
        _rollNumberCtrl.text  = res['rollNumber']  ?? '';
        _divisionCtrl.text    = res['division']    ?? '';
        _batchCtrl.text       = res['batch']       ?? '';
        _budgetCtrl.text      = res['weeklyBudget']?.toString() ?? '2000.0';
      }
    } catch (e) { debugPrint('Profile load error: $e'); }
    finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeCtrl.forward();
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post('/profile/update', data: {
        'displayName':  _displayNameCtrl.text.trim(),
        'college':      _collegeCtrl.text.trim(),
        'branch':       _branchCtrl.text.trim(),
        'year':         _yearCtrl.text.trim(),
        'rollNumber':   _rollNumberCtrl.text.trim(),
        'division':     _divisionCtrl.text.trim(),
        'batch':        _batchCtrl.text.trim(),
        'weeklyBudget': _budgetCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Profile saved!', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/auth');
  }

  String get _initials {
    final name = _displayNameCtrl.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    final user   = Supabase.instance.client.auth.currentUser;
    final email  = user?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF1F5F9),
      body: _loading
          ? const ProfileShimmer()
          : CustomScrollView(
              slivers: [
                // ── Hero App Bar ─────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: isDark ? AppColors.darkBg : const Color(0xFF4F46E5),
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.rose.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.rose, size: 16),
                      ),
                      onPressed: () => _confirmSignOut(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E1B4B), const Color(0xFF080B1F)]
                              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Stack(children: [
                        // Decorative circle
                        Positioned(top: -30, right: -40,
                          child: Container(
                            width: 180, height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Colors.white.withOpacity(0.06), Colors.transparent])),
                          ),
                        ),
                        SafeArea(
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 16),
                                  // Avatar
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [AppColors.indigo, AppColors.violet],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.3), width: 3),
                                      boxShadow: [BoxShadow(
                                        color: AppColors.indigo.withOpacity(0.4),
                                        blurRadius: 20, offset: const Offset(0, 6))],
                                    ),
                                    child: Center(child: Text(_initials,
                                      style: const TextStyle(
                                        color: Colors.white, fontSize: 28,
                                        fontWeight: FontWeight.w800, fontFamily: 'Syne'))),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _displayNameCtrl.text.isEmpty
                                        ? 'Your Profile' : _displayNameCtrl.text,
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 18,
                                      fontWeight: FontWeight.w800, fontFamily: 'Syne')),
                                  const SizedBox(height: 4),
                                  Text(email,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6), fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                // ── Form ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FormSection(label: 'Personal Info', icon: Icons.person_outline_rounded),
                            const SizedBox(height: 12),
                            _ProfileField(ctrl: _displayNameCtrl, label: 'Display Name',
                              icon: Icons.badge_outlined, isDark: isDark),
                            const SizedBox(height: 12),
                            _ProfileField(ctrl: _collegeCtrl, label: 'College / University',
                              icon: Icons.account_balance_outlined, isDark: isDark),

                            const SizedBox(height: 20),
                            _FormSection(label: 'Academic Details', icon: Icons.school_outlined),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _ProfileField(
                                ctrl: _branchCtrl, label: 'Branch',
                                icon: Icons.menu_book_outlined, isDark: isDark)),
                              const SizedBox(width: 12),
                              Expanded(child: _ProfileField(
                                ctrl: _yearCtrl, label: 'Year',
                                icon: Icons.calendar_today_outlined,
                                isDark: isDark, isNumber: true)),
                            ]),
                            const SizedBox(height: 12),
                            _ProfileField(ctrl: _rollNumberCtrl, label: 'Roll Number',
                              icon: Icons.pin_outlined, isDark: isDark),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _ProfileField(
                                ctrl: _divisionCtrl, label: 'Division',
                                icon: Icons.class_outlined, isDark: isDark)),
                              const SizedBox(width: 12),
                              Expanded(child: _ProfileField(
                                ctrl: _batchCtrl, label: 'Batch',
                                icon: Icons.group_outlined, isDark: isDark)),
                            ]),

                            const SizedBox(height: 20),
                            _FormSection(label: 'Finance', icon: Icons.account_balance_wallet_outlined),
                            const SizedBox(height: 12),
                            _ProfileField(ctrl: _budgetCtrl, label: 'Weekly Budget (₹)',
                              icon: Icons.currency_rupee_rounded,
                              isDark: isDark, isNumber: true),

                            const SizedBox(height: 28),
                            // Save button
                            GestureDetector(
                              onTap: _saving ? null : _saveProfile,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: _saving
                                      ? null
                                      : const LinearGradient(
                                          colors: [AppColors.indigo, AppColors.violet],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                  color: _saving ? cs.onSurface.withOpacity(0.08) : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _saving
                                      ? null
                                      : [const BoxShadow(
                                          color: Color(0x556366F1),
                                          blurRadius: 20, offset: Offset(0, 6))],
                                ),
                                child: Center(
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: Colors.white))
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.save_rounded,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text('Save Changes',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15, fontFamily: 'Syne')),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.rose.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 18)),
          const SizedBox(width: 12),
          Text('Sign Out',
            style: TextStyle(color: cs.onSurface,
              fontWeight: FontWeight.w700, fontFamily: 'Syne', fontSize: 17)),
        ]),
        content: Text('Are you sure you want to sign out?',
          style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
              style: TextStyle(color: cs.onSurface.withOpacity(0.5)))),
          Container(
            decoration: BoxDecoration(
              color: AppColors.rose.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: TextButton(
              onPressed: () { Navigator.pop(ctx); _signOut(); },
              child: const Text('Sign Out',
                style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FormSection({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.indigo.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.indigo, size: 14),
      ),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(
        fontFamily: 'Syne', fontWeight: FontWeight.w700, fontSize: 13,
        color: cs.onSurface.withOpacity(0.8))),
    ]);
  }
}

// ── Profile form field ─────────────────────────────────────────────────────────
class _ProfileField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool isDark, isNumber;
  const _ProfileField({required this.ctrl, required this.label,
    required this.icon, required this.isDark, this.isNumber = false});

  @override
  State<_ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<_ProfileField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.indigo
              : (widget.isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFE2E8F0)),
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [const BoxShadow(
                color: Color(0x226366F1), blurRadius: 12, offset: Offset(0, 2))]
            : (!widget.isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))]
                : null),
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextFormField(
          controller: widget.ctrl,
          keyboardType: widget.isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _focused
                  ? AppColors.indigo
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.4)
                      : const Color(0xFF94A3B8)),
              fontSize: 12),
            prefixIcon: Icon(widget.icon,
              color: _focused
                  ? AppColors.indigo
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFF94A3B8)),
              size: 18),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 13),
          ),
        ),
      ),
    );
  }
}
