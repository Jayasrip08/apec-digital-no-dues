import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper methods for FeeSetupScreen
extension FeeSetupHelpers on _FeeSetupScreenState {
  void loadExistingStructure(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    setState(() {
      _editingDocId = doc.id;
      _batch = data['academicYear'] ?? _batch;
      _dept = data['dept'] ?? _dept;
      _quota = data['quotaCategory'] ?? _quota;
      _semester = data['semester'] ?? _semester;
      
      // Load components
      _controllers.clear();
      if (data['components'] != null) {
        Map<String, dynamic> components = data['components'];
        components.forEach((key, value) {
          _controllers[key] = TextEditingController(text: value.toString());
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded for editing. Modify and save.')),
    );
  }

  Future<void> deleteStructure(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: const Text('Are you sure you want to delete this fee structure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('fee_structures').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee structure deleted')),
        );
      }
    }
  }

  Widget buildStructuresList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fee_structures')
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No fee structures found. Create one above!'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final components = data['components'] as Map<String, dynamic>? ?? {};
            final total = data['totalAmount'] ?? 0.0;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Text(
                    data['semester'] ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  '${data['academicYear']} - ${data['dept']} - ${data['quotaCategory']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Total: ₹${total.toStringAsFixed(0)} • ${components.length} components'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => loadExistingStructure(doc),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteStructure(doc.id),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: components.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 14)),
                              Text('₹${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
