import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewFeesScreen extends StatefulWidget {
  final Widget? drawer;
  const ViewFeesScreen({super.key, this.drawer});

  @override
  State<ViewFeesScreen> createState() => _ViewFeesScreenState();
}

class _ViewFeesScreenState extends State<ViewFeesScreen> {
  Future<void> _deleteStructure(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: const Text('Are you sure you want to delete this fee structure?'),
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
      await FirebaseFirestore.instance.collection('fee_structures').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee structure deleted')),
        );
      }
    }
  }

  void _editStructure(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final components = data['components'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Fee Structure'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batch: ${data['academicYear']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Department: ${data['dept']}'),
              Text('Quota: ${data['quotaCategory']}'),
              Text('Semester: ${data['semester']}'),
              const Divider(),
              const Text('Fee Components:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...components.entries.map((entry) {
                final controller = TextEditingController(text: entry.value.toString());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            components[entry.key] = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Calculate total
              double total = 0;
              components.forEach((key, value) {
                if (value is Map) {
                  // Bus fee - take the maximum or first available for representative total
                  total += (value.values.isNotEmpty) ? (value.values.first as num).toDouble() : 0.0;
                } else {
                  total += (value is num) ? value.toDouble() : 0.0;
                }
              });

              // Update Firestore
              await FirebaseFirestore.instance
                  .collection('fee_structures')
                  .doc(doc.id)
                  .update({
                'components': components,
                'totalAmount': total,
                'lastUpdated': FieldValue.serverTimestamp(),
              });

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fee structure updated!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Fee Structures'),
        backgroundColor: Colors.indigo,
      ),
      drawer: widget.drawer,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fee_structures')
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No fee structures found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Create fee structures from the Configure Fees screen'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final components = data['components'] as Map<String, dynamic>? ?? {};
              final total = data['totalAmount'] ?? data['amount'] ?? 0.0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      data['semester'] ?? '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${data['academicYear'] ?? 'N/A'} - ${data['dept'] ?? 'All'} - ${data['quotaCategory'] ?? 'All'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Total: ₹${total.toStringAsFixed(0)} • ${components.length} components',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editStructure(doc),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteStructure(doc.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
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
                          const Text(
                            'Fee Components:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Divider(),
                          if (data['deadline'] != null)
                             Padding(
                               padding: const EdgeInsets.only(bottom: 8),
                               child: Row(
                                 children: [
                                   const Icon(Icons.calendar_month, size: 16, color: Colors.orange),
                                   const SizedBox(width: 8),
                                   Text(
                                     "Deadline: ${DateFormat('dd MMM yyyy').format((data['deadline'] as Timestamp).toDate())}",
                                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                   ),
                                 ],
                               ),
                             ),
                          ...components.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '₹${entry.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
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
