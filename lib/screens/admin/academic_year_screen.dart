import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AcademicYearScreen extends StatefulWidget {
  const AcademicYearScreen({super.key});

  @override
  State<AcademicYearScreen> createState() => _AcademicYearScreenState();
}

class _AcademicYearScreenState extends State<AcademicYearScreen> {

  // Academic Year Creation
  Future<void> _createAcademicYear() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Academic Year'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Academic Year (e.g., 2024-2028)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('academic_years')
            .doc(nameController.text)
            .set({
          'name': nameController.text,
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Academic year created')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Toggle Academic Year Active Status
  Future<void> _toggleAcademicYear(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('academic_years')
        .doc(docId)
        .update({'isActive': !currentStatus});
  }

  // Delete Academic Year
  Future<void> _deleteAcademicYear(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academic Year'),
        content: const Text('Are you sure? This will also delete all associated semesters.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete all semesters for this academic year
        final semesters = await FirebaseFirestore.instance
            .collection('semesters')
            .where('academicYear', isEqualTo: docId)
            .get();
        
        for (var doc in semesters.docs) {
          await doc.reference.delete();
        }

        // Delete academic year
        await FirebaseFirestore.instance
            .collection('academic_years')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Academic year deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Create Semester
  Future<void> _createSemester(String academicYearId) async {

    int? selectedSemesterNumber;
    DateTime? startDate;
    DateTime? endDate;
    final sessionController = TextEditingController(); // Added session controller

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Semester'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField( // Added session field
                  controller: sessionController,
                  decoration: const InputDecoration(
                    labelText: 'Academic Session (e.g., 2024-25)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSemesterNumber,
                  decoration: const InputDecoration(
                    labelText: 'Semester Number',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(8, (index) => index + 1)
                      .map((num) => DropdownMenuItem(
                            value: num,
                            child: Text('Semester $num'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedSemesterNumber = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(startDate != null ? DateFormat('dd/MM/yyyy').format(startDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(endDate != null ? DateFormat('dd/MM/yyyy').format(endDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSemesterNumber != null && startDate != null && endDate != null && sessionController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('semesters')
            .add({
          'academicYear': academicYearId,
          'semesterNumber': selectedSemesterNumber,
          'academicSession': sessionController.text, // Saving session
          'startDate': Timestamp.fromDate(startDate!),
          'endDate': Timestamp.fromDate(endDate!),
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semester created')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Toggle Semester Active Status
  Future<void> _toggleSemester(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('semesters')
        .doc(docId)
        .update({'isActive': !currentStatus});
  }

  // Edit Semester
  Future<void> _editSemester(String docId, Map<String, dynamic> currentData) async {
    int? selectedSemesterNumber = currentData['semesterNumber'];
    DateTime? startDate = (currentData['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (currentData['endDate'] as Timestamp?)?.toDate();
    final sessionController = TextEditingController(text: currentData['academicSession'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Semester'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sessionController,
                  decoration: const InputDecoration(
                    labelText: 'Academic Session',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedSemesterNumber,
                  decoration: const InputDecoration(
                    labelText: 'Semester Number',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(8, (index) => index + 1)
                      .map((num) => DropdownMenuItem(
                            value: num,
                            child: Text('Semester $num'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedSemesterNumber = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(startDate != null ? DateFormat('dd/MM/yyyy').format(startDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(endDate != null ? DateFormat('dd/MM/yyyy').format(endDate!) : 'Not selected'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedSemesterNumber != null && startDate != null && endDate != null) {
      try {
        await FirebaseFirestore.instance
            .collection('semesters')
            .doc(docId)
            .update({
          'semesterNumber': selectedSemesterNumber,
          'academicSession': sessionController.text,
          'startDate': Timestamp.fromDate(startDate!),
          'endDate': Timestamp.fromDate(endDate!),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semester updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Delete Semester
  Future<void> _deleteSemester(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Semester'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('semesters').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semester deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Year Management'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('academic_years')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No academic years found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _createAcademicYear,
                    child: const Text('Create First Academic Year'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Existing Batches',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _createAcademicYear,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Batch'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final doc = snapshot.data!.docs[index - 1];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] ?? false;
              final academicYearId = doc.id;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green : Colors.grey,
                        child: Icon(
                          isActive ? Icons.check : Icons.close,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        data['name'],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(isActive ? 'Active Batch' : 'Inactive Batch'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (val) => _toggleAcademicYear(academicYearId, isActive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAcademicYear(academicYearId),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Semesters',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              TextButton.icon(
                                onPressed: () => _createSemester(academicYearId),
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                label: const Text('Add Semester'),
                                style: TextButton.styleFrom(foregroundColor: Colors.teal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('semesters')
                                .where('academicYear', isEqualTo: academicYearId)
                                .snapshots(),
                            builder: (context, semSnapshot) {
                              if (semSnapshot.hasError) {
                                return Text('Error: ${semSnapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
                              }

                              if (semSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: LinearProgressIndicator());
                              }

                              if (!semSnapshot.hasData || semSnapshot.data!.docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'No semesters created yet',
                                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: semSnapshot.data!.docs.map((semDoc) {
                                  final semData = semDoc.data() as Map<String, dynamic>;
                                  final semIsActive = semData['isActive'] ?? false;
                                  final startDate = (semData['startDate'] as Timestamp?)?.toDate();
                                  final endDate = (semData['endDate'] as Timestamp?)?.toDate();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: ListTile(
                                      visualDensity: VisualDensity.compact,
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: semIsActive ? Colors.teal : Colors.grey[400],
                                        child: Text(
                                          '${semData['semesterNumber']}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(
                                        'Semester ${semData['semesterNumber']}',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Batch: ${data['name']}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo),
                                          ),
                                          if (semData['academicSession'] != null && semData['academicSession'].toString().isNotEmpty)
                                            Text(
                                              'Session: ${semData['academicSession']}',
                                              style: const TextStyle(fontSize: 11, color: Colors.teal),
                                            ),
                                          Text(
                                            startDate != null && endDate != null
                                                ? '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}'
                                                : 'Dates not set',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.scale(
                                            scale: 0.7,
                                            child: Switch(
                                              value: semIsActive,
                                              onChanged: (val) => _toggleSemester(semDoc.id, semIsActive),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                            onPressed: () => _editSemester(semDoc.id, semData),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _deleteSemester(semDoc.id),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
