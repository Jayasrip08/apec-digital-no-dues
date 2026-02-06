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
  bool _showHistory = false;
  List<String> _allBatches = [];
  List<String> _activeBatches = [];
  String? _selectedBatch;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academic_years')
        .orderBy('name', descending: true)
        .get();
    
    if (mounted) {
      setState(() {
        _allBatches = snapshot.docs.map((doc) => doc.id).toList();
        _activeBatches = snapshot.docs
            .where((doc) => doc.data()['isActive'] == true)
            .map((doc) => doc.id)
            .toList();
      });
    }
  }
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
        actions: [
          if (_allBatches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<String?>(
                value: _selectedBatch,
                hint: const Text("Batch", style: TextStyle(color: Colors.white70, fontSize: 12)),
                dropdownColor: Colors.indigo,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                underline: Container(),
                icon: const Icon(Icons.filter_alt, color: Colors.white70, size: 18),
                items: [
                  const DropdownMenuItem(value: null, child: Text("All Batches")),
                  ..._allBatches.map((batch) => DropdownMenuItem(value: batch, child: Text(batch))),
                ],
                onChanged: (val) => setState(() => _selectedBatch = val),
              ),
            ),
          Row(
            children: [
              const Text("History", style: TextStyle(fontSize: 12, color: Colors.white70)),
              Switch(
                value: _showHistory,
                activeColor: Colors.white,
                onChanged: (val) => setState(() => _showHistory = val),
              ),
            ],
          ),
        ],
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
                  const Text(
                    'No fee structures found',
                    style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;
          final displayedDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final batchId = data['academicYear'] ?? '';
            
            // 1. Filter by specific chosen batch
            if (_selectedBatch != null) {
              return batchId == _selectedBatch;
            }

            // 2. If no batch selected, check History toggle
            if (_showHistory) {
              return true; // Show everything
            } else {
              // Show only active versions in active batches
              final bool isVersionActive = data['isActive'] ?? true;
              final bool isBatchActive = _activeBatches.contains(batchId);
              return isVersionActive && isBatchActive;
            }
          }).toList();

          if (displayedDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _showHistory ? 'No structures found' : 'No active fee structures found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  if (!_showHistory)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Toggle "History" to see old/inactive fees'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayedDocs.length,
            itemBuilder: (context, index) {
              final doc = displayedDocs[index];
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
