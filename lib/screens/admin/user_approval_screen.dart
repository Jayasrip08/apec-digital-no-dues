import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserApprovalScreen extends StatelessWidget {
  const UserApprovalScreen({super.key});

  Future<void> _approveUser(BuildContext context, String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'approvalStatus': 'approved',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name has been approved!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, String uid, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject User"),
        content: Text("Are you sure you want to reject and delete $name? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject & Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User rejected and removed.")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Approvals")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('approvalStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text("All caught up! No pending approvals.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;
              final name = user['name'] ?? 'Unknown';
              final email = user['email'] ?? 'No Email';
              final role = user['role']?.toString().toUpperCase() ?? 'UNKNOWN';
              final details = user['employeeId'] ?? user['dept'] ?? 'No Details';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: Text(role[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$email\n$role • $details"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: "Approve",
                        onPressed: () => _approveUser(context, uid, name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Reject",
                        onPressed: () => _rejectUser(context, uid, name),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
