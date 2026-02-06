import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/fee_service.dart';
import '../../services/pdf_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'payment_screen.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Uncomment when ready

class SemesterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String semester;

  const SemesterDetailScreen({
    super.key,
    required this.userData,
    required this.semester,
  });

  @override
  State<SemesterDetailScreen> createState() => _SemesterDetailScreenState();
}

class _SemesterDetailScreenState extends State<SemesterDetailScreen> {
  bool _isLoading = true;
  Map<String, double> _feeComponents = {};
  Map<String, Map<String, dynamic>> _paymentStatus = {}; // { "Tuition Fee": {status: 'pending', ...} }
  DateTime? _deadline;
  final User _user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    String dept = widget.userData['dept'] ?? 'CSE';
    String quota = widget.userData['quotaCategory'] ?? 'Management';
    String batch = widget.userData['batch'] ?? '2024-2028';
    String studentType = widget.userData['studentType'] ?? 'day_scholar';
    String? busPlace = widget.userData['busPlace'];

    // 1. Fetch Fee Structure
    var structure = await FeeService().getFeeComponents(dept, quota, batch, widget.semester);
    
    if (structure != null && structure['components'] != null) {
      if (structure['deadline'] != null) {
        _deadline = (structure['deadline'] as Timestamp).toDate();
      }
      Map<String, dynamic> rawComponents = structure['components'];
      
      // Filter fees based on student type
      for (var entry in rawComponents.entries) {
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
            // Bus fee is a map of places, get only the student's place
            if (busPlace != null && feeValue.containsKey(busPlace)) {
              _feeComponents[feeType] = (feeValue[busPlace] as num).toDouble();
            }
            continue;
          }
        }
        
        // Add other fees
        if (feeValue is num) {
          _feeComponents[feeType] = feeValue.toDouble();
        }
      }
    }

    // 2. Fetch Payments for each component
    for (String feeType in _feeComponents.keys) {
      // ID Construction: uid_semester_feeType (sanitized)
      String sanitizedType = feeType.replaceAll(" ", "_");
      String paymentId = "${_user.uid}_${widget.semester}_$sanitizedType";
      
      var doc = await FirebaseFirestore.instance.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        _paymentStatus[feeType] = doc.data() as Map<String, dynamic>;
      } else {
        _paymentStatus[feeType] = {'status': 'not_paid'};
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadBill(String feeType, double amount) async {
    // Navigate to PaymentScreen for the full payment flow
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          feeType: feeType,
          amount: amount,
          semester: widget.semester,
        ),
      ),
    );
    _loadDetails(); // Refresh details on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Semester ${widget.semester} - Fee Details")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDetails,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 20),
                const Text("Fee Components", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_feeComponents.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("No fees configured for this semester yet.", style: TextStyle(fontStyle: FontStyle.italic)),
                   )
                else
                  ..._feeComponents.entries.map((entry) => _buildFeeItem(entry.key, entry.value)).toList(),
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryCard() {
    double total = _feeComponents.values.fold(0, (sum, val) => sum + val);
    int paidCount = _paymentStatus.values.where((p) => p['status'] == 'verified').length;
    int totalCount = _feeComponents.length;
    
    return Card(
      color: Colors.indigo,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Total Semester Fee", style: TextStyle(color: Colors.white70)),
            Text("₹ $total", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            if (_deadline != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Due by: ${DateFormat('dd MMM yyyy').format(_deadline!)}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const Divider(color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Progress: $paidCount / $totalCount Paid", style: const TextStyle(color: Colors.white)),
                if (paidCount == totalCount && totalCount > 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Build map of only paid fees
                      Map<String, double> paidFees = {};
                      _feeComponents.forEach((feeType, amount) {
                        var status = _paymentStatus[feeType];
                        if (status != null && status['status'] == 'verified') {
                          paidFees[feeType] = amount;
                        }
                      });
                      
                      PdfService().generateAndDownloadCertificate(
                        widget.userData['name'] ?? 'Student', 
                        widget.userData['regNo'] ?? '', 
                        widget.userData['dept'] ?? 'CSE', 
                        widget.userData['batch'] ?? '', 
                        widget.semester,
                        paidFees, // Pass only paid fees
                      );
                    },
                    icon: const Icon(Icons.download, size: 16, color: Colors.indigo),
                    label: const Text("NO DUE CERT", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFeeItem(String title, double amount) {
    var statusData = _paymentStatus[title] ?? {'status': 'not_paid'};
    String status = statusData['status'];
    Color color = Colors.grey;
    IconData icon = Icons.circle_outlined;
    String statusText = "Not Paid";

    if (status == 'under_review') {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
      statusText = "Verification Pending";
    } else if (status == 'verified') {
      color = Colors.green;
      icon = Icons.check_circle;
      statusText = "Verified";
    } else if (status == 'rejected') {
      color = Colors.red;
      icon = Icons.error_outline;
      statusText = "Rejected";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Amount: ₹ $amount"),
            Text(statusText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            if (status == 'rejected' && statusData['rejectionReason'] != null)
              Text("Reason: ${statusData['rejectionReason']}", style: const TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        trailing: status == 'not_paid' || status == 'rejected'
          ? ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text("Pay"),
              onPressed: () => _uploadBill(title, amount),
              style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
            )
          : null,
      ),
    );
  }
}
