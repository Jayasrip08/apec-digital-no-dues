import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/fee_service.dart';

class StaffStudentDetail extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String studentId;

  const StaffStudentDetail({super.key, required this.studentData, required this.studentId});

  @override
  State<StaffStudentDetail> createState() => _StaffStudentDetailState();
}

class _StaffStudentDetailState extends State<StaffStudentDetail> {
  String _selectedSemester = '1';

  @override
  Widget build(BuildContext context) {
    // Construct ID: Batch_Dept_Quota_Sem
    // Note: Use widget.studentData
    final feeDocId = "${widget.studentData['batch']}_${widget.studentData['dept']}_${widget.studentData['quotaCategory']}_$_selectedSemester";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Details"),
        actions: [
          // Semester Dropdown in AppBar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<String>(
              value: _selectedSemester,
              dropdownColor: Colors.indigo,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              items: ['1', '2', '3', '4', '5', '6', '7', '8'].map((s) => DropdownMenuItem(value: s, child: Text("Sem $s"))).toList(),
              onChanged: (val) {
                if(val != null) setState(() => _selectedSemester = val);
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: FirebaseFirestore.instance
                  .collection('fee_structures')
                  .where('academicYear', isEqualTo: widget.studentData['batch'])
                  .where('dept', isEqualTo: widget.studentData['dept'])
                  .where('quotaCategory', isEqualTo: widget.studentData['quotaCategory'])
                  .where('semester', isEqualTo: _selectedSemester)
                  .where('isActive', isEqualTo: true)
                  .limit(1)
                  .get()
                  .then((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null),
              builder: (context, feeSnapshot) {
                final feeStructure = feeSnapshot.data;
                
                // Calculate Total Fee Requirement
                double totalFeeAmt = 0.0;
                if (feeStructure != null) {
                  totalFeeAmt = FeeService().calculateStudentFee(
                    feeStructure: feeStructure,
                    studentType: widget.studentData['studentType'] ?? 'day_scholar',
                    busPlace: widget.studentData['busPlace'],
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('studentId', isEqualTo: widget.studentId)
                      .where('semester', isEqualTo: _selectedSemester) // Filter by selected sem
                      .snapshots(),
                  builder: (context, paymentSnapshot) {
                    final payments = paymentSnapshot.data?.docs ?? [];
                    
                    double totalPaidVerified = 0;
                    double totalPendingReview = 0;

                    for (var p in payments) {
                      final pData = p.data() as Map<String, dynamic>;
                      final amt = (pData['amount'] as num?)?.toDouble() ?? 0.0;
                      
                      if (pData['status'] == 'verified') {
                        totalPaidVerified += amt;
                      } else if (pData['status'] == 'under_review') {
                        totalPendingReview += amt;
                      }
                    }

                    final double due = totalFeeAmt - totalPaidVerified;
                    
                    // Status Logic
                    String statusText = "PENDING";
                    Color statusColor = Colors.orange;
                    
                    if (totalFeeAmt == 0 && feeSnapshot.connectionState == ConnectionState.done) {
                       statusText = "NO FEE SET";
                       statusColor = Colors.grey;
                    } else if (due <= 0) {
                      statusText = "CLEARED";
                      statusColor = Colors.green;
                    } else if (totalPendingReview > 0) {
                      statusText = "VERIFICATION PENDING";
                      statusColor = Colors.orange;
                    } else {
                      statusText = "HAS DUES";
                      statusColor = Colors.red;
                    }

                    return Column(
                      children: [
                        // STUDENT INFO HEADER with Stats
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.indigo,
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.studentData['name'] ?? "Unknown", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 5),
                              Text("Reg No: ${widget.studentData['regNo']}  |  Quota: ${widget.studentData['quotaCategory']}", style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 20),
                              
                              // STATS ROW simplified
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _headerStat("Paid (Verified)", "₹${totalPaidVerified.toStringAsFixed(0)}"),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                    child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                                ],
                              ),
                              if (totalPendingReview > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text("Pending Verify: ₹${totalPendingReview.toStringAsFixed(0)}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                )
                            ],
                          ),
                        ),
                        
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Align(alignment: Alignment.centerLeft, child: Text("Payment History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        ),

                        // PAYMENT LIST
                        if (payments.isEmpty)
                           const Padding(padding: EdgeInsets.all(20), child: Text("No payments found for this semester."))
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: payments.length,
                            itemBuilder: (context, index) {
                              var payData = payments[index].data() as Map<String, dynamic>;
                              String pStatus = payData['status'];
                              Color pColor = pStatus == 'verified' ? Colors.green : (pStatus == 'rejected' ? Colors.red : Colors.orange);

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: pColor.withOpacity(0.1),
                                    child: Icon(pStatus == 'verified' ? Icons.check : (pStatus == 'rejected' ? Icons.close : Icons.hourglass_empty), color: pColor),
                                  ),
                                  title: Text("₹${payData['amount']}"),
                                  subtitle: Text("Txn: ${payData['transactionId'] ?? 'N/A'}\nDate: ${payData['submittedAt'] != null ? (payData['submittedAt'] as Timestamp).toDate().toString().split(' ')[0] : 'N/A'}"),
                                  trailing: Chip(
                                    label: Text(pStatus.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    backgroundColor: pColor,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                        const SizedBox(height: 30),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
