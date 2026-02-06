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

  // STUDENT: Get Fee Components (Aggregated/Additive)
  Future<Map<String, dynamic>?> getFeeComponents(String dept, String quotaCategory, String batch, String semester) async {
    // We want to fetch all matching configurations and merge them.
    // Order: General -> Specific (Specific overrides General if key matches)
    
    List<Map<String, String>> searchLevels = [
      {'dept': 'All', 'quotaCategory': 'All'},         // 1. Most General
      {'dept': dept, 'quotaCategory': 'All'},          // 2. Specific Dept
      {'dept': 'All', 'quotaCategory': quotaCategory}, // 3. Specific Quota
      {'dept': dept, 'quotaCategory': quotaCategory},  // 4. Most Specific
    ];
    
    Map<String, dynamic> combinedComponents = {};
    DateTime? latestDeadline;

    bool foundAny = false;

    for (var level in searchLevels) {
      QuerySnapshot snapshot = await _db.collection('fee_structures')
          .where('academicYear', isEqualTo: batch)
          .where('dept', isEqualTo: level['dept'])
          .where('quotaCategory', isEqualTo: level['quotaCategory'])
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        foundAny = true;
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        
        // Merge components
        if (data['components'] != null) {
          combinedComponents.addAll(Map<String, dynamic>.from(data['components']));
        }
        
        // Take the latest/most specific deadline if available
        if (data['deadline'] != null) {
          latestDeadline = (data['deadline'] as Timestamp).toDate();
        }
      }
    }
    
    if (!foundAny) return null;

    // Calculate total for the combined set
    double total = 0;
    combinedComponents.forEach((key, value) {
      if (value is Map) {
        // Bus fee logic (summing routes is standard here for total display, 
        // though student chooses one in detail screen)
        (value as Map).values.forEach((amt) => total += (amt as num).toDouble());
      } else {
        total += (value as num).toDouble();
      }
    });

    return {
      'academicYear': batch,
      'dept': dept,
      'quotaCategory': quotaCategory,
      'semester': semester,
      'components': combinedComponents,
      'totalAmount': total,
      'deadline': latestDeadline != null ? Timestamp.fromDate(latestDeadline) : null,
      'isActive': true,
    };
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