// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
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
    if (userId != null) {
      final user = await _authService.getUserData(userId);
      setState(() {
        _user = user;
        if (user?.country != null && user!.country!.trim().isNotEmpty) {
          _selectedCountry = user.country!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection(
            title: 'Notifications',
            children: [
              _buildSwitchTile(
                title: 'Push Notifications',
                subtitle: 'Receive push notifications',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                  });
                },
              ),
              _buildSwitchTile(
                title: 'Email Notifications',
                subtitle: 'Receive email updates',
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
                  });
                },
              ),
              _buildSwitchTile(
                title: 'SMS Notifications',
                subtitle: 'Receive SMS alerts',
                value: _smsNotifications,
                onChanged: (value) {
                  setState(() {
                    _smsNotifications = value;
                  });
                },
              ),
              _buildSwitchTile(
                title: 'Order Updates',
                subtitle: 'Get notified about order status',
                value: _orderUpdates,
                onChanged: (value) {
                  setState(() {
                    _orderUpdates = value;
                  });
                },
              ),
              _buildSwitchTile(
                title: 'Promotions & Offers',
                subtitle: 'Receive promotional emails',
                value: _promotions,
                onChanged: (value) {
                  setState(() {
                    _promotions = value;
                  });
                },
              ),
            ],
          ),
          const Divider(thickness: 8),
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
          const Divider(thickness: 8),
          _buildSection(
            title: 'Account',
            children: [
              _buildListTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () {
                  _showLanguageDialog();
                },
              ),
              _buildListTile(
                icon: Icons.location_on,
                title: 'Country/Region',
                subtitle: _selectedCountry,
                onTap: () {
                  _showCountryDialog();
                },
              ),
              _buildListTile(
                icon: Icons.lock,
                title: 'Change Password',
                onTap: () {
                  _showChangePasswordDialog();
                },
              ),
            ],
          ),
          const Divider(thickness: 8),
          _buildSection(
            title: 'Privacy & Security',
            children: [
              _buildListTile(
                icon: Icons.security,
                title: 'Privacy Policy',
                onTap: () {
                  _showInfoDialog(
                    'Privacy Policy',
                    'Your privacy is important to us. We collect and use your personal information to provide and improve our services...',
                  );
                },
              ),
              _buildListTile(
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {
                  _showInfoDialog(
                    'Terms of Service',
                    'By using our app, you agree to these terms and conditions...',
                  );
                },
              ),
              _buildListTile(
                icon: Icons.shield,
                title: 'Data & Privacy',
                onTap: () {
                  _showInfoDialog(
                    'Data & Privacy',
                    'We take data protection seriously. Your information is encrypted and stored securely...',
                  );
                },
              ),
            ],
          ),
          const Divider(thickness: 8),
          _buildSection(
            title: 'App',
            children: [
              _buildListTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  _showAboutDialog();
                },
              ),
              _buildListTile(
                icon: Icons.rate_review,
                title: 'Rate Us',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your support!')),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.share,
                title: 'Share App',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share functionality coming soon!')),
                  );
                },
              ),
            ],
          ),
          const Divider(thickness: 8),
          _buildSection(
            title: 'Danger Zone',
            children: [
              _buildListTile(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                titleColor: Colors.red,
                onTap: () {
                  _showDeleteAccountDialog();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        ...children,
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
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
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
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: 'en',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('اردو (Urdu)'),
              value: 'ur',
              groupValue: 'en',
              onChanged: (value) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Urdu language coming soon!')),
                );
              },
            ),
          ],
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
      builder: (context) => AlertDialog(
        title: const Text('Select Country'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: _countryOptions.map((country) {
                  return RadioListTile<String>(
                    title: Text(country),
                    value: country,
                    groupValue: tempCountry,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        tempCountry = value;
                      });
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updatedUser = _user!.copyWith(
                  country: tempCountry,
                  updatedAt: DateTime.now(),
                );

                await _authService.updateUserProfile(updatedUser);

                if (context.mounted) {
                  setState(() {
                    _user = updatedUser;
                    _selectedCountry = tempCountry;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Country updated successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController(text: _user?.email ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We will send a password reset link to your email.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _authService.resetPassword(emailController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag, size: 80),
            SizedBox(height: 16),
            Text(
              'E-Commerce AR App',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text(
              'An innovative shopping experience with Augmented Reality',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _authService.deleteAccount();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
