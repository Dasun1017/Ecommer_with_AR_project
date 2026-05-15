// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  final ThemeController _themeController = ThemeController.instance;

  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _orderUpdates = true;
  bool _promotions = false;

  final List<String> _countryOptions = [
    'Pakistan',
    'Sri Lanka',
    'India',
    'Bangladesh',
    'Nepal',
    'Maldives',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Canada',
    'Australia',
  ];

  String _selectedCountry = 'Pakistan';
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    final user = await _authService.getUserData(userId);
    if (!mounted) return;
    setState(() {
      _user = user;
      if (user?.country != null && user!.country!.trim().isNotEmpty) {
        _selectedCountry = user.country!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildSection(
            title: 'Notifications',
            children: [
              _buildSwitchTile(
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _pushNotifications,
                onChanged: (value) => setState(() {
                  _pushNotifications = value;
                }),
              ),
              _buildSwitchTile(
                title: 'Email Notifications',
                subtitle: 'Receive email updates',
                value: _emailNotifications,
                onChanged: (value) => setState(() {
                  _emailNotifications = value;
                }),
              ),
              _buildSwitchTile(
                title: 'SMS Notifications',
                subtitle: 'Receive SMS alerts',
                value: _smsNotifications,
                onChanged: (value) => setState(() {
                  _smsNotifications = value;
                }),
              ),
              _buildSwitchTile(
                title: 'Order Updates',
                subtitle: 'Get notified about order status',
                value: _orderUpdates,
                onChanged: (value) => setState(() {
                  _orderUpdates = value;
                }),
              ),
              _buildSwitchTile(
                title: 'Promotions & Offers',
                subtitle: 'Receive promotional emails',
                value: _promotions,
                onChanged: (value) => setState(() {
                  _promotions = value;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Appearance',
            children: [
              _buildSwitchTile(
                title: 'Dark Mode',
                subtitle: 'Enable dark theme',
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) async {
                  await _themeController.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Account',
            children: [
              _buildListTile(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English',
                onTap: _showLanguageDialog,
              ),
              _buildListTile(
                icon: Icons.location_on_outlined,
                title: 'Country/Region',
                subtitle: _selectedCountry,
                onTap: _showCountryDialog,
              ),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: _showChangePasswordDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Privacy & Security',
            children: [
              _buildListTile(
                icon: Icons.security_outlined,
                title: 'Privacy Policy',
                onTap: () => _showInfoDialog(
                  'Privacy Policy',
                  'Your privacy is important to us. We collect and use your personal information to provide and improve our services.',
                ),
              ),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _showInfoDialog(
                  'Terms of Service',
                  'By using our app, you agree to these terms and conditions.',
                ),
              ),
              _buildListTile(
                icon: Icons.shield_outlined,
                title: 'Data & Privacy',
                onTap: () => _showInfoDialog(
                  'Data & Privacy',
                  'We take data protection seriously. Your information is encrypted and stored securely.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'App',
            children: [
              _buildListTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: _showAboutDialog,
              ),
              _buildListTile(
                icon: Icons.rate_review_outlined,
                title: 'Rate Us',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Thank you for your support!')),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.share_outlined,
                title: 'Share App',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share functionality coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Danger Zone',
            children: [
              _buildListTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Account',
                titleColor: Colors.red.shade700,
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      activeColor: Colors.blue.shade700,
      onChanged: onChanged,
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final color = titleColor ?? Colors.blue.shade700;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
      onTap: onTap,
    );
  }

  Widget _buildDialogHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.language_outlined,
                title: 'Select Language',
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: 'en',
                activeColor: Colors.blue.shade700,
                onChanged: (_) => Navigator.pop(context),
              ),
              RadioListTile<String>(
                title: const Text('Urdu'),
                value: 'ur',
                groupValue: 'en',
                activeColor: Colors.blue.shade700,
                onChanged: (_) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Urdu language coming soon!')),
                  );
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryDialog() {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to update your country.')),
      );
      return;
    }

    String tempCountry = _selectedCountry;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDialogHeader(
                    icon: Icons.location_on_outlined,
                    title: 'Select Country',
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: _countryOptions.map((country) {
                        return RadioListTile<String>(
                          title: Text(country),
                          value: country,
                          groupValue: tempCountry,
                          activeColor: Colors.blue.shade700,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              tempCountry = value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final updatedUser = _user!.copyWith(
                          country: tempCountry,
                          updatedAt: DateTime.now(),
                        );
                        await _authService.updateUserProfile(updatedUser);

                        if (!context.mounted) return;
                        setState(() {
                          _user = updatedUser;
                          _selectedCountry = tempCountry;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Country updated successfully.'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController(text: _user?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.lock_reset_outlined,
                title: 'Change Password',
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 14),
              Text(
                'We will send a password reset link to your email.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: _fieldDecoration('Email'),
                enabled: false,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _authService.resetPassword(emailController.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password reset email sent!')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Email'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.info_outline,
                title: title,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 14),
              Text(content, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.shopping_bag_outlined,
                title: 'E-Commerce AR App',
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 14),
              Text(
                'Version 1.0.0\n\nAn innovative shopping experience with Augmented Reality.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogHeader(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Account',
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _authService.deleteAccount();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
