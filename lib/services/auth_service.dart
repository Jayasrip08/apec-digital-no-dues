import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. REGISTER: Create Auth User + Firestore Document
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    required String role, 
    String? regNo,
    String? dept,
    String? quotaCategory,
    String? employeeId, 
    String? batch, // NEW: Batch field (e.g. 2024-2028)
    String? studentType, // NEW: Student type (day_scholar/hosteller/bus_user)
    String? busPlace, // NEW: Bus place if bus_user
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      User? user = result.user;

      // 1. Check if ANY admin already exists
      QuerySnapshot adminQuery = await _db.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      bool firstAdmin = adminQuery.docs.isEmpty;

      // Determine approval status: 
      // - Students: Approved
      // - First Admin: Approved (Auto)
      // - Meaning subsequent Admins/Staff: Pending
      String approvalStatus = 'pending';
      // Only the very first admin is auto-approved
      if (role == 'admin' && firstAdmin) {
        approvalStatus = 'approved';
      }

      await _db.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': role,
        'approvalStatus': approvalStatus, // NEW: Approval workflow
        'regNo': regNo ?? '',
        'dept': dept ?? '',
        'employeeId': employeeId ?? '', 
        'quotaCategory': quotaCategory ?? 'Management',
        'batch': batch ?? '', // NEW
        'studentType': studentType ?? 'day_scholar', // NEW
        'busPlace': busPlace ?? '', // NEW
        'createdAt': FieldValue.serverTimestamp(),
        
        if (role == 'student') ...{
          'totalFee': 85000, // Default fallback
          'paidFee': 0,
          'status': 'Pending'
        }
      });

      await _auth.signOut(); // Ensure fresh login is required
      return null; 
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred";
    }
  }

  // 2. LOGIN: Check approval status
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
      DocumentSnapshot doc = await _db.collection('users').doc(result.user!.uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        
        // Check approval status
        String approvalStatus = userData['approvalStatus'] ?? 'approved';
        if (approvalStatus == 'pending') {
          // Sign out the user immediately
          await _auth.signOut();
          throw Exception('Your account is pending admin approval. Please wait for approval.');
        }
        
        return userData;
      }
      return null;
    } catch (e) {
      throw e.toString(); 
    }
  }
}