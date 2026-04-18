import 'package:flutter/material.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _loading = true;
  bool _saving = false;

  final _displayNameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _rollNumberCtrl = TextEditingController();
  final _divisionCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient.instance.get<dynamic>('/profile');
      if (res != null) {
        _displayNameCtrl.text = res['displayName'] ?? '';
        _collegeCtrl.text = res['college'] ?? '';
        _branchCtrl.text = res['branch'] ?? '';
        _yearCtrl.text = res['year']?.toString() ?? '';
        _rollNumberCtrl.text = res['rollNumber'] ?? '';
        _divisionCtrl.text = res['division'] ?? '';
        _batchCtrl.text = res['batch'] ?? '';
        _budgetCtrl.text = res['weeklyBudget']?.toString() ?? '2000.0';
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post('/profile/update', data: {
        'displayName': _displayNameCtrl.text.trim(),
        'college': _collegeCtrl.text.trim(),
        'branch': _branchCtrl.text.trim(),
        'year': _yearCtrl.text.trim(),
        'rollNumber': _rollNumberCtrl.text.trim(),
        'division': _divisionCtrl.text.trim(),
        'batch': _batchCtrl.text.trim(),
        'weeklyBudget': _budgetCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Profile updated successfully!'), backgroundColor: AppColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.rose),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('My Profile', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.rose),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Sign Out', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                content: Text('Are you sure you want to sign out?', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx), 
                    child: Text('Cancel', style: TextStyle(color: cs.onSurface.withOpacity(0.6)))
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _signOut();
                    },
                    child: const Text('Sign Out', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      body: _loading
          ? const ProfileShimmer()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.indigo.withOpacity(0.15) : AppColors.indigo.withOpacity(0.08),
                          border: Border.all(color: AppColors.indigo.withOpacity(0.3), width: 2),
                        ),
                        child: const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.person, size: 40, color: AppColors.indigo),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildField('Display Name', _displayNameCtrl, icon: Icons.badge_outlined, context: context),
                    const SizedBox(height: 16),
                    _buildField('College / University', _collegeCtrl, icon: Icons.account_balance_outlined, context: context),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField('Branch', _branchCtrl, icon: Icons.library_books_outlined, context: context)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Year', _yearCtrl, icon: Icons.calendar_today_outlined, isNumber: true, context: context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildField('Roll Number', _rollNumberCtrl, icon: Icons.pin_outlined, context: context),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField('Division', _divisionCtrl, icon: Icons.class_outlined, context: context)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Batch', _batchCtrl, icon: Icons.group_outlined, context: context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildField('Weekly Budget (₹)', _budgetCtrl, icon: Icons.account_balance_wallet_outlined, isNumber: true, context: context),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: DesignStyles.gradientButton(),
                        child: FilledButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _saving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {required IconData icon, bool isNumber = false, required BuildContext context}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = context.isDark;
    
    return TextFormField(
      controller: controller,
      style: TextStyle(color: cs.onSurface),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: cs.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: AppColors.surface(context), // dynamic field background
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: AppColors.border(context))
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: AppColors.indigo, width: 2)
        ),
      ),
    );
  }
}
