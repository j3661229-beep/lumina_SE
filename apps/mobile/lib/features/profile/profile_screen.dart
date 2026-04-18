import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/shimmer_widgets.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';

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
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: cs.error),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: cs.surface,
                title: Text('Sign Out', style: TextStyle(color: cs.onSurface)),
                content: Text('Are you sure you want to sign out?', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx), 
                    child: Text('Cancel', style: TextStyle(color: cs.onSurface))
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _signOut();
                    },
                    child: Text('Sign Out', style: TextStyle(color: cs.error)),
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
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: cs.primary.withOpacity(0.15),
                        child: Icon(Icons.person, size: 44, color: cs.primary),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildField('Display Name', _displayNameCtrl, icon: Icons.badge_outlined, cs: cs),
                          const SizedBox(height: 16),
                          _buildField('College / University', _collegeCtrl, icon: Icons.account_balance_outlined, cs: cs),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildField('Branch', _branchCtrl, icon: Icons.library_books_outlined, cs: cs)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField('Year', _yearCtrl, icon: Icons.calendar_today_outlined, isNumber: true, cs: cs)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildField('Roll Number', _rollNumberCtrl, icon: Icons.pin_outlined, cs: cs),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildField('Division', _divisionCtrl, icon: Icons.class_outlined, cs: cs)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField('Batch', _batchCtrl, icon: Icons.group_outlined, cs: cs)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        text: 'Save Changes',
                        onPressed: _saveProfile,
                        isLoading: _saving,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {required IconData icon, bool isNumber = false, required ColorScheme cs}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: cs.onSurface),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: cs.onSurface.withOpacity(0.6)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
