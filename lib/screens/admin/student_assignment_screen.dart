import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentAssignmentScreen extends StatefulWidget {
  const StudentAssignmentScreen({super.key});

  @override
  State<StudentAssignmentScreen> createState() => _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  String? _selectedStaffId;
  String? _selectedDepartment;
  bool _isLoading = false;

  final List<String> _departments = ['CSE', 'ECE', 'MECH', 'CIVIL', 'EEE', 'IT'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Students to Staff'),
      ),
      body: Column(
        children: [
          // Staff Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Staff Member',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'staff')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final staffList = snapshot.data!.docs;

                    if (staffList.isEmpty) {
                      return const Text('No staff members found');
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Staff/HOD',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: staffList.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text('${data['name']} (${data['dept'] ?? 'N/A'})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedStaffId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Department',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(dept),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedDepartment = value);
                  },
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: _selectedStaffId == null || _selectedDepartment == null
                ? const Center(
                    child: Text('Please select staff and department'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'student')
                        .where('dept', isEqualTo: _selectedDepartment)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final students = snapshot.data!.docs;

                      if (students.isEmpty) {
                        return const Center(
                          child: Text('No students found in this department'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final studentData = student.data() as Map<String, dynamic>;
                          final studentId = student.id;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('student_assignments')
                                .doc('${_selectedStaffId}_$studentId')
                                .get(),
                            builder: (context, assignmentSnapshot) {
                              final isAssigned = assignmentSnapshot.hasData &&
                                  assignmentSnapshot.data!.exists;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(studentData['name'][0]),
                                  ),
                                  title: Text(studentData['name']),
                                  subtitle: Text(
                                    '${studentData['regNo']} | ${studentData['quotaCategory']}',
                                  ),
                                  trailing: Switch(
                                    value: isAssigned,
                                    onChanged: (value) {
                                      _toggleAssignment(studentId, studentData, value);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAssignment(
    String studentId,
    Map<String, dynamic> studentData,
    bool assign,
  ) async {
    if (_selectedStaffId == null) return;

    setState(() => _isLoading = true);

    try {
      final docId = '${_selectedStaffId}_$studentId';

      if (assign) {
        // Assign student to staff
        await FirebaseFirestore.instance
            .collection('student_assignments')
            .doc(docId)
            .set({
          'staffId': _selectedStaffId,
          'studentId': studentId,
          'studentName': studentData['name'],
          'studentRegNo': studentData['regNo'],
          'dept': studentData['dept'],
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': FirebaseAuth.instance.currentUser!.uid,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${studentData['name']} assigned')),
          );
        }
      } else {
        // Unassign student
        await FirebaseFirestore.instance
            .collection('student_assignments')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${studentData['name']} unassigned')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
