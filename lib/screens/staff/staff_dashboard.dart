import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import 'staff_student_detail.dart';
import '../profile_screen.dart';
import '../../widgets/payment_status_badge.dart';
import '../../services/fee_service.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String? _staffDept;
  String _selectedStatus = 'All';
  String? _selectedBatch;
  int? _selectedSemester;
  bool _isLoadingStaff = true;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (doc.exists) {
        setState(() {
          _staffDept = doc.data()?['dept'];
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingStaff = false);
    }
  }

  String _searchQuery = ""; // NEW: Search query state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        backgroundColor: Colors.indigo,
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
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR (No other filters)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Name or Reg No",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // STUDENT LIST
          Expanded(
            child: _isLoadingStaff
                ? const Center(child: CircularProgressIndicator())
                : _buildStudentList(),
          ),
        ],
      ),
    );
  }

  // Removed _buildFilterBar

  Widget _buildStudentList() {
    if (_staffDept == null) {
      if (_isLoadingStaff) return const Center(child: CircularProgressIndicator());
      return const Center(child: Text("Department info not found."));
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('dept', isEqualTo: _staffDept);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("No students found in $_staffDept department"));

        final docs = snapshot.data!.docs;

        // Apply Search Filter client-side
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? "").toString().toLowerCase();
          final regNo = (data['regNo'] ?? "").toString().toLowerCase();
          
          if (_searchQuery.isNotEmpty) {
             return name.contains(_searchQuery) || regNo.contains(_searchQuery);
          }
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("No students match your search."));

        return ListView.builder(
          itemCount: filteredDocs.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            final studentId = filteredDocs[index].id;

            return _StudentListItem(
              studentId: studentId,
            );
          },
        );
      },
    );
  }
}

class _StudentListItem extends StatelessWidget {
  final String studentId;

  const _StudentListItem({
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(studentId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final studentData = snapshot.data!.data() as Map<String, dynamic>?;
        if (studentData == null) return const SizedBox.shrink();

        // Simplified Card - Details passed to Detail Screen
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.indigo[50], 
                child: Text(
                  (studentData['name'] ?? "U")[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
                )
              ),
              title: Text(
                studentData['name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                "${studentData['regNo']} • ${studentData['batch'] ?? 'N/A'}",
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.indigo),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => StaffStudentDetail(studentData: studentData, studentId: studentId)));
              },
          ),
        );
      },
    );
  }
}
