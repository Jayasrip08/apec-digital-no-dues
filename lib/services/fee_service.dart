import 'package:cloud_firestore/cloud_firestore.dart';

class FeeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ADMIN: Set Comprehensive Fee Structure
  Future<void> setFeeComponents({
    required String academicYear,
    required String quotaCategory,
    required String dept,
    required String semester,
    required Map<String, double> components, // {"Tuition": 50000, "Bus": 15000}
  }) async {
    String docId = "${academicYear}_${dept}_${quotaCategory}_$semester";
    
    await _db.collection('fee_structures').doc(docId).set({
      'academicYear': academicYear,
      'quotaCategory': quotaCategory,
      'dept': dept,
      'semester': semester,
      'components': components,
      'totalAmount': components.values.fold(0.0, (sum, item) => sum + item),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // STUDENT: Get Fee Components
  Future<Map<String, dynamic>?> getFeeComponents(String dept, String quotaCategory, String batch, String semester) async {
    // Priority order with isActive filter:
    // 1. Exact match: batch_dept_quota_semester
    // 2. All dept: batch_All_quota_semester
    // 3. All quota: batch_dept_All_semester
    // 4. All both: batch_All_All_semester
    
    List<Map<String, String>> queries = [
      {'dept': dept, 'quotaCategory': quotaCategory},  // Exact
      {'dept': 'All', 'quotaCategory': quotaCategory}, // All dept
      {'dept': dept, 'quotaCategory': 'All'},          // All quota
      {'dept': 'All', 'quotaCategory': 'All'},         // All both
    ];
    
    for (var query in queries) {
      QuerySnapshot snapshot = await _db.collection('fee_structures')
          .where('academicYear', isEqualTo: batch)
          .where('dept', isEqualTo: query['dept'])
          .where('quotaCategory', isEqualTo: query['quotaCategory'])
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data() as Map<String, dynamic>;
      }
    }
    
    return null;
  }

  // STUDENT: Submit Proof for Specific Component
  Future<void> submitComponentProof({
    required String uid,
    required String semester,
    required String feeType, // E.g., "Tuition Fee"
    required double amountExpected,
    required String proofUrl,
    bool ocrVerified = false,
  }) async {
    // ID: uid_semester_feeType (Sanitized)
    String sanitizedType = feeType.replaceAll(" ", "_");
    String paymentId = "${uid}_${semester}_$sanitizedType";
    
    await _db.collection('payments').doc(paymentId).set({
      'uid': uid,
      'semester': semester,
      'feeType': feeType,
      'amountExpected': amountExpected,
      'amountPaid': amountExpected, // Assuming full payment for now
      'proofUrl': proofUrl,
      'status': 'under_review',
      'ocrVerified': ocrVerified,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  // ADMIN: Verify Payment Component
  Future<void> verifyPaymentComponent(String paymentId, bool isApproved, {String? rejectionReason}) async {
     await _db.collection('payments').doc(paymentId).update({
       'status': isApproved ? 'verified' : 'rejected',
       'rejectionReason': rejectionReason,
       'verifiedAt': FieldValue.serverTimestamp(),
     });
  }

  // HELPER: Calculate Fee Amount for specific student type
  double calculateStudentFee({
    required Map<String, dynamic> feeStructure,
    required String studentType, // 'hosteller', 'bus_user', 'day_scholar'
    String? busPlace,
  }) {
    double total = 0.0;
    Map<String, dynamic> components = feeStructure['components'] as Map<String, dynamic>? ?? {};

    for (var entry in components.entries) {
      String feeType = entry.key;
      var feeValue = entry.value;

      // Skip hostel fee for non-hostellers
      if (feeType.toLowerCase().contains('hostel') && studentType != 'hosteller') {
        continue;
      }

      // Handle bus fee
      if (feeType.toLowerCase().contains('bus')) {
        if (studentType != 'bus_user') {
          continue; // Skip bus fee for non-bus users
        } else if (feeValue is Map) {
          // Bus fee is a map of places
          if (busPlace != null && feeValue.containsKey(busPlace)) {
            total += (feeValue[busPlace] as num).toDouble();
          }
          continue;
        }
      }

      // Add regular fees
      if (feeValue is num) {
        total += feeValue.toDouble();
      }
    }
    return total;
  }
}