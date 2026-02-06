import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verification_screen.dart';
import 'fee_setup_screen.dart';
import 'view_fees_screen.dart';
import 'academic_year_screen.dart';
import 'student_assignment_screen.dart';
import 'overdue_payments_screen.dart';
import '../login_screen.dart';
import 'user_approval_screen.dart';
import '../profile_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Console"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: "Pending Actions", icon: Icon(Icons.notifications_active)),
              Tab(text: "Payment History", icon: Icon(Icons.history)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: "My Profile",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            )
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OverduePaymentsScreen()),
              ),
              label: const Text('Overdue'),
              icon: const Icon(Icons.warning),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              heroTag: 'overdue',
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserApprovalScreen()),
              ),
              label: const Text('Approvals'),
              icon: const Icon(Icons.verified_user),
              backgroundColor: Colors.deepOrangeAccent,
              foregroundColor: Colors.white,
              heroTag: 'approvals',
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AcademicYearScreen()),
              ),
              label: const Text('Academic'),
              icon: const Icon(Icons.calendar_today),
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
              heroTag: 'academic',
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewFeesScreen()),
              ),
              label: const Text('View Fees'),
              icon: const Icon(Icons.visibility),
              backgroundColor: Colors.purpleAccent[700],
              foregroundColor: Colors.white,
              heroTag: 'viewfees',
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeeSetupScreen()),
              ),
              label: const Text('Set Fee'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.blueAccent[700],
              foregroundColor: Colors.white,
              heroTag: 'fee',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            Container(
              color: Colors.white,
              child: _buildPaymentList(isPending: true),
            ),
            Container(
              color: Colors.white,
              child: _buildPaymentList(isPending: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList({required bool isPending}) {
    Query query = FirebaseFirestore.instance.collection('payments');
    
    if (isPending) {
      query = query.where('status', isEqualTo: 'under_review');
    } else {
      query = query.where('status', whereIn: ['verified', 'rejected']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('submittedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        // Only show loading on initial load, not on updates
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPending ? Icons.inbox : Icons.history, 
                  size: 80, 
                  color: Colors.grey[300]
                ),
                const SizedBox(height: 16),
                Text(
                  isPending ? "No pending approvals" : "No payment history",
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
            
            String studentName = data['studentName'] ?? 'Unknown';
            String regNo = data['studentRegNo'] ?? '';
            String dept = data['dept'] ?? '';
            String semester = data['semester'] ?? '?';
            double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            String transactionId = data['transactionId'] ?? '';
            String feeType = data['feeType'] ?? 'Fee';
            String status = data['status'] ?? '';

            Color statusColor;
            IconData statusIcon;
            
            if (status == 'verified') {
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              statusIcon = Icons.cancel;
            } else {
              statusColor = Colors.orange;
              statusIcon = Icons.hourglass_top;
            }

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isPending ? () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => VerificationScreen(
                      data: data, 
                      docId: doc.id, 
                      studentId: data['uid']
                    )
                  ));
                } : null, // History items are read-only for now
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Leading Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          statusIcon, 
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$feeType - ₹${amount.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$regNo • $dept • Sem $semester",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "TXN: $transactionId",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (status == 'rejected' && data['rejectionReason'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "Reason: ${data['rejectionReason']}",
                                  style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Trailing
                      if (isPending)
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
}
