import 'package:cloud_firestore/cloud_firestore.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the role of a user by their user ID
  /// Returns 'client' by default if role is not found or on error
  Future<String> getUserRole(String userId) async {
    try {
      print('🔍 RoleService: Fetching role for user: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) {
        print('⚠️ RoleService: User document does not exist for ID: $userId');
        return 'client';
      }
      
      final data = doc.data();
      if (data == null) {
        print('⚠️ RoleService: User document exists but data is null');
        return 'client';
      }
      
      final role = data['role'] as String?;
      print('📋 RoleService: User data retrieved. Role field value: "${role}"');
      
      if (role == null) {
        print('⚠️ RoleService: Role field is null, defaulting to client');
        return 'client';
      }
      
      final normalizedRole = role.toLowerCase().trim();
      print('✅ RoleService: Returning role: "$normalizedRole"');
      return normalizedRole;
      
    } catch (e) {
      print('❌ RoleService Error getting user role: $e');
      return 'client'; // Default to client on error
    }
  }

  /// Check if a user is an admin
  Future<bool> isAdmin(String userId) async {
    final role = await getUserRole(userId);
    return role == 'admin';
  }

  /// Check if a user is a client
  Future<bool> isClient(String userId) async {
    final role = await getUserRole(userId);
    return role == 'client';
  }

  /// Update a user's role (admin only operation)
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  /// Check admin permission before allowing access to admin features
  Future<bool> checkAdminPermission(String userId) async {
    return await isAdmin(userId);
  }
}
