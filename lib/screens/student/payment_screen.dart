import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/error_handler.dart';
import '../../services/fee_service.dart';

class PaymentScreen extends StatefulWidget {
  final String feeType;
  final double amount;
  final String semester;

  const PaymentScreen({
    super.key,
    required this.feeType,
    required this.amount,
    required this.semester,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _currentStep = 0;
  XFile? _imageFile; // CHANGED: Use XFile for web compatibility
  late TextEditingController _amountCtrl;
  final _txnCtrl = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.amount.toStringAsFixed(0));
  }

  // 1. UPI REDIRECT
  Future<void> _launchUPI() async {
    String upiUrl = "upi://pay?pa=collegefees@sbi&pn=APEC&cu=INR&am=${widget.amount}&tn=${widget.feeType}";
    if (await canLaunchUrl(Uri.parse(upiUrl))) {
      await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
    } else {
      upiUrl = "upi://pay?pa=collegefees@sbi&pn=APEC&cu=INR";
      if (await canLaunchUrl(Uri.parse(upiUrl))) {
        await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No UPI App found. Please pay manually.")));
      }
    }
  }

  // 2. IMAGE PICKER & OCR
  Future<void> _pickAndScanImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
      // OCR only works on Mobile (Android/iOS)
      if (!kIsWeb) {
        _performOCR(File(pickedFile.path));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto-scan not supported on Web. Please enter details manually.")));
      }
    }
  }

  Future<void> _performOCR(File image) async {
    try {
      final inputImage = InputImage.fromFile(image);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      String text = recognizedText.text;

      // 1. Transaction ID (12 digits)
      RegExp txnRegex = RegExp(r'\b\d{12}\b'); 
      String? extractedTxn = txnRegex.stringMatch(text);

       // 2. Amount Extraction
      RegExp amountRegex = RegExp(r'[₹|Rs\.?|INR]?\s?(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false);
      var matches = amountRegex.allMatches(text);
      
      String? extractedAmount;
      for (var m in matches) {
        String val = m.group(1)?.replaceAll(",", "") ?? "";
        double? d = double.tryParse(val);
        if (d != null && d > 10 && d < 1000000) { 
           extractedAmount = val;
           if ((d - widget.amount).abs() < 1) break;
        }
      }

      setState(() {
        if (extractedTxn != null) _txnCtrl.text = extractedTxn;
        if (extractedAmount != null) _amountCtrl.text = extractedAmount!;
            
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("OCR Complete: found ${extractedTxn != null ? 'TxnID' : ''} ${extractedAmount != null ? 'Amount' : ''}"),
          backgroundColor: Colors.green
        ));
      });
      textRecognizer.close();
    } catch (e) {
      debugPrint("OCR Error: $e");
    }
  }

  // 3. SUBMIT TO FIREBASE
  Future<void> _submitPayment() async {
    if (_imageFile == null) {
      ErrorHandler.showError(context, 'Please upload a receipt image');
      return;
    }
    
    // Transaction ID is optional if image is provided
    String txnId = _txnCtrl.text.trim();
    if (txnId.isEmpty) {
       txnId = "IMG-${DateTime.now().millisecondsSinceEpoch}"; // Auto-generate if empty
    } else {
       // Only validate if manually entered
       final txnError = Validators.validateTransactionId(txnId);
       if (txnError != null) {
          ErrorHandler.showError(context, txnError);
          return;
       }
    }
    
    final amountError = Validators.validateAmount(_amountCtrl.text);
    if (amountError != null) {
      ErrorHandler.showError(context, amountError);
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // Check duplicate
      final isDuplicate = await ErrorHandler.checkDuplicatePayment(
        studentId: user.uid,
        transactionId: txnId,
      );
      
      if (isDuplicate) {
        if (mounted) ErrorHandler.showWarning(context, 'A payment with this transaction ID already exists');
        setState(() => _isUploading = false);
        return;
      }
      
      // UPLOAD LOGIC (Web vs Mobile)
      String? downloadUrl;
      if (kIsWeb) {
        // Web Upload
        final bytes = await _imageFile!.readAsBytes();
        final ref = FirebaseStorage.instance.ref().child('receipts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        downloadUrl = await ref.getDownloadURL();
      } else {
        // Mobile Upload (reusing existing helper if it supports File, or simplified here)
        final ref = FirebaseStorage.instance.ref().child('receipts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(_imageFile!.path));
        downloadUrl = await ref.getDownloadURL();
      }
      
      if (downloadUrl == null) throw Exception("Upload failed");

      // Submit Data
      await FeeService().submitComponentProof(
        uid: user.uid,
        semester: widget.semester,
        feeType: widget.feeType,
        amountExpected: widget.amount,
        proofUrl: downloadUrl,
        ocrVerified: !kIsWeb, // OCR only on mobile
      );
      
      // Update Metadata
      String sanitizedType = widget.feeType.replaceAll(" ", "_");
      String paymentId = "${user.uid}_${widget.semester}_$sanitizedType";
      
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
         var userData = userDoc.data()!;
         await FirebaseFirestore.instance.collection('payments').doc(paymentId).update({
           'transactionId': txnId,
           'amount': double.parse(_amountCtrl.text.trim()),
           'studentId': user.uid,
           'studentName': userData['name'],
           'studentRegNo': userData['regNo'],
           'dept': userData['dept'],
           'quota': userData['quotaCategory'], 
         });
       }

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Receipt submitted successfully! Admin will review it soon.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, "Submission Failed: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pay & Verify")),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
             // Step 0: UPI - Always allow continue
             setState(() => _currentStep++);
          } else if (_currentStep == 1) {
             // Step 1: Image - Validate before moving
             if (_imageFile == null) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a receipt first.")));
               return;
             }
             setState(() => _currentStep++);
          } else {
             // Step 2: Verify - Submit
             _submitPayment();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        steps: [
          Step(
            title: const Text("Pay via UPI"),
            content: Column(
              children: [
                const Text("Pay to: collegefees@sbi"),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _launchUPI, child: const Text("Open UPI App")),
              ],
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text("Upload Screenshot"),
            content: Column(
              children: [
                _imageFile != null 
                    ? (kIsWeb 
                        ? Image.network(_imageFile!.path, height: 150) // Web: Use blob URL path or Image.network
                        : Image.file(File(_imageFile!.path), height: 150)) // Mobile: Use File
                    : Container(height: 100, color: Colors.grey[200], child: const Center(child: Text("No Image"))),
                TextButton.icon(
                  icon: const Icon(Icons.camera_alt), 
                  label: const Text("Select Screenshot"), 
                  onPressed: _pickAndScanImage
                ),
                if (kIsWeb) const Text("(OCR Auto-scan not available on Web)", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text("Verify Details"),
            content: Column(
              children: [
                TextField(controller: _txnCtrl, decoration: const InputDecoration(labelText: "Transaction ID")),
                TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount Paid")),
                if (_isUploading) const LinearProgressIndicator(),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
