import 'package:flutter/material.dart';
import '../../services/fee_service.dart';

class VerificationScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId; // Payment Document ID
  final String studentId;

  const VerificationScreen({
    super.key, 
    required this.data, 
    required this.docId, 
    required this.studentId
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isProcessing = false;
  final _reasonCtrl = TextEditingController();

  Future<void> _verifyPayment() async {
    setState(() => _isProcessing = true);
    try {
      // Approve Payment component
      await FeeService().verifyPaymentComponent(widget.docId, true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Verified! Payment Cleared.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayment() async {
    // Show Dialog for Reason
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Payment"),
        content: TextField(
          controller: _reasonCtrl,
          decoration: const InputDecoration(labelText: "Reason for Rejection", hintText: "e.g., Invalid Receipt"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject"),
          )
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      await FeeService().verifyPaymentComponent(widget.docId, false, rejectionReason: _reasonCtrl.text);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match fields from payment_screen.dart
    final String receiptUrl = widget.data['proofUrl'] ?? widget.data['receiptUrl'] ?? '';
    final double amount = (widget.data['amount'] as num?)?.toDouble() ?? 0.0;
    final String semester = widget.data['semester'] ?? '?';
    final String studentName = widget.data['studentName'] ?? 'Unknown';
    final String transactionId = widget.data['transactionId'] ?? '';

    return Scaffold(
      appBar: AppBar(title: Text("Verify Payment - $studentName")),
      body: Column(
        children: [
          // IMAGE VIEW
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: receiptUrl.isNotEmpty && receiptUrl.startsWith('http') 
                  ? InteractiveViewer(
                      child: Image.network(
                        receiptUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Loading receipt image...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Image load error: $error');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, color: Colors.white, size: 50),
                                const SizedBox(height: 10),
                                const Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  error.toString(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const Icon(Icons.link_off, color: Colors.white, size: 50),
                       const SizedBox(height: 10),
                       const Text('Invalid or missing image URL', style: TextStyle(color: Colors.white)),
                       const SizedBox(height: 5),
                       Text("URL: $receiptUrl", style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
            ),
          ),
          
          // DATA VIEW
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Payment Verification", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text("₹ $amount", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 15),
                    
                    _detailRow(Icons.person, "Student: $studentName"),
                    _detailRow(Icons.category, "Fee Type: ${widget.data['feeType'] ?? 'Fee'}"),
                    _detailRow(Icons.school, "Semester: $semester"),
                    _detailRow(Icons.receipt, "TXN ID: $transactionId"),
                    
                    const Divider(height: 30),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing ? null : _rejectPayment,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text("REJECT"),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _verifyPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isProcessing 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text("APPROVE"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}