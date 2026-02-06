import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'verification_screen.dart';

class PaymentListTab extends StatefulWidget {
  final bool isPending;

  const PaymentListTab({super.key, required this.isPending});

  @override
  State<PaymentListTab> createState() => _PaymentListTabState();
}

class _PaymentListTabState extends State<PaymentListTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Prevents rebuilding when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive

    Query query = FirebaseFirestore.instance.collection('payments');
    
    if (widget.isPending) {
      query = query.where('status', isEqualTo: 'under_review');
    } else {
      query = query.where('status', whereIn: ['verified', 'rejected']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('submittedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isPending ? Icons.inbox_outlined : Icons.history_edu_outlined, 
                  size: 80, 
                  color: Colors.grey[300]
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isPending ? "No pending approvals" : "No payment history",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            
            // Safe Data Access
            String studentName = data['studentName'] ?? 'Unknown Student';
            String regNo = data['studentRegNo'] ?? data['uid'] ?? 'No RegNo';
            String dept = data['dept'] ?? 'Gen';
            String semester = data['semester'] ?? '?';
            double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            String transactionId = data['transactionId'] ?? 'Manual';
            String feeType = data['feeType'] ?? 'Fee';
            String status = data['status'] ?? '';
            
            Timestamp? submittedAt = data['submittedAt'] as Timestamp?;
            String dateStr = submittedAt != null 
                ? DateFormat('dd MMM, hh:mm a').format(submittedAt.toDate())
                : 'Just now';

            // Status Styling
            Color statusColor;
            IconData statusIcon;
            Color cardBg;
            
            if (status == 'verified') {
              statusColor = Colors.green[700]!;
              statusIcon = Icons.verified;
              cardBg = Colors.green.shade50;
            } else if (status == 'rejected') {
              statusColor = Colors.red[700]!;
              statusIcon = Icons.error_outline;
              cardBg = Colors.red.shade50;
            } else {
              statusColor = Colors.orange[800]!;
              statusIcon = Icons.pending_actions;
              cardBg = Colors.orange.shade50;
            }

            return Card(
              elevation: 4,
              shadowColor: Colors.black12,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                   if (widget.isPending) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VerificationScreen(
                          data: data, 
                          docId: doc.id, 
                          studentId: data['uid']
                        )
                      ));
                   } else if (status == 'verified') {
                      _showRevertDialog(context, doc.id);
                   }
                }, 
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child: Text(studentName[0].toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text("$regNo  •  $dept", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withOpacity(0.3))
                            ),
                            child: Row(
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                      
                      // Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(feeType, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${amount.toStringAsFixed(0)}", 
                                  style: TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.indigo[900],
                                    fontFamily: 'Roboto', // Or system default
                                  )
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_long, size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(transactionId, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              const SizedBox(height: 8),
                              if (widget.isPending || status == 'verified')
                                Row(
                                  children: [
                                    Text(
                                      widget.isPending ? "Review" : "Revert", 
                                      style: TextStyle(
                                        color: widget.isPending ? Colors.blue[700] : Colors.orange[800], 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13
                                      )
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      widget.isPending ? Icons.arrow_forward : Icons.restore, 
                                      size: 16, 
                                      color: widget.isPending ? Colors.blue[700] : Colors.orange[800]
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Rejection Reason
                      if (status == 'rejected' && data['rejectionReason'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            "Reason: ${data['rejectionReason']}",
                            style: TextStyle(color: Colors.red[900], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRevertDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revert Payment?"),
        content: const Text("This payment is currently Verified. Do you want to revert it back to Pending status?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('payments').doc(docId).update({
                'status': 'under_review',
                'verifiedAt': FieldValue.delete(), // Remove verified timestamp
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Reverted to Pending")));
            },
            child: const Text("Revert to Pending"),
          )
        ],
      )
    );
  }
}
