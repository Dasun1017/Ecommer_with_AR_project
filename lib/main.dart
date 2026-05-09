import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'utils/app_routes.dart';
import 'utils/app_theme.dart';
import 'utils/theme_controller.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // 🔧 ADMIN SETUP: Set admin role for specific emails
  // Add your admin emails here
  await _setupAdminUsers([
    'your.admin@email.com',  // Replace with your actual admin email
    // Add more admin emails as needed
  ]);

  final themeController = ThemeController.instance;
  await themeController.load();

  runApp(MyApp(themeController: themeController));
}

/// Setup admin users by email
Future<void> _setupAdminUsers(List<String> adminEmails) async {
  if (adminEmails.isEmpty || adminEmails.first == 'your.admin@email.com') {
    // Skip if no emails configured
    print('⚠️ No admin emails configured. Update main.dart to set admin users.');
    return;
  }

  try {
    final firestore = FirebaseFirestore.instance;
    
    for (String email in adminEmails) {
      if (email.isEmpty) continue;
      
      // Query for user with this email
      final usersQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        final userDoc = usersQuery.docs.first;
        final currentRole = userDoc.data()['role'];
        
        if (currentRole != 'admin') {
          // Update to admin
          await userDoc.reference.update({
            'role': 'admin',
            'updatedAt': DateTime.now().toIso8601String(),
          });
          print('✅ Set $email as admin');
        } else {
          print('ℹ️ $email is already an admin');
        }
      } else {
        print('⚠️ User not found: $email (they need to register first)');
      }
    }
  } catch (e) {
    print('❌ Error setting up admin users: $e');
  }
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;

  const MyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'AR Shopping',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,
          home: const AuthWrapper(),
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
