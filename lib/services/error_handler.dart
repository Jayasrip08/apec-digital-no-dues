import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

/// Comprehensive error handling service for the app
class ErrorHandler {
  /// Show error snackbar with retry option
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning message
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Handle Firebase errors with user-friendly messages
  static String getFirebaseErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'not-found':
          return 'The requested data was not found';
        case 'already-exists':
          return 'This data already exists';
        case 'unauthenticated':
          return 'Please log in to continue';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your connection';
        default:
          return error.message ?? 'An error occurred';
      }
    }
    
    if (error is SocketException) {
      return 'No internet connection. Please check your network';
    }
    
    return error.toString();
  }

  /// Upload file with retry mechanism
  static Future<String?> uploadFileWithRetry({
    required File file,
    required String path,
    required BuildContext context,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          if (context.mounted) {
            showError(
              context,
              'Failed to upload file after $maxRetries attempts: ${getFirebaseErrorMessage(e)}',
            );
          }
          return null;
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    return null;
  }

  /// Execute Firestore operation with retry
  static Future<T?> executeWithRetry<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    int maxRetries = 3,
    String? errorMessage,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          if (context.mounted) {
            showError(
              context,
              errorMessage ?? getFirebaseErrorMessage(e),
            );
          }
          return null;
        }
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    return null;
  }

  /// Check for duplicate payment submission
  static Future<bool> checkDuplicatePayment({
    required String studentId,
    required String transactionId,
  }) async {
    try {
      final existingPayment = await FirebaseFirestore.instance
          .collection('payments')
          .where('studentId', isEqualTo: studentId)
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      return existingPayment.docs.isNotEmpty;
    } catch (e) {
      print('Error checking duplicate payment: $e');
      return false;
    }
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(message ?? 'Please wait...'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}

/// Input validation utilities
class Validators {
  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  /// Validate registration number
  static String? validateRegNo(String? value) {
    if (value == null || value.isEmpty) {
      return 'Registration number is required';
    }
    if (value.length < 5) {
      return 'Enter a valid registration number';
    }
    return null;
  }

  /// Validate amount
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount';
    }
    if (amount > 1000000) {
      return 'Amount seems too large';
    }
    return null;
  }

  /// Validate transaction ID
  static String? validateTransactionId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Transaction ID is required';
    }
    if (value.length < 6) {
      return 'Transaction ID must be at least 6 characters';
    }
    return null;
  }

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate dropdown selection
  static String? validateDropdown(dynamic value, String fieldName) {
    if (value == null) {
      return 'Please select $fieldName';
    }
    return null;
  }

  /// Validate date
  static String? validateDate(DateTime? value, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate future date
  static String? validateFutureDate(DateTime? value, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    if (value.isBefore(DateTime.now())) {
      return '$fieldName must be in the future';
    }
    return null;
  }

  /// Validate date range
  static String? validateDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 'Both dates are required';
    }
    if (end.isBefore(start)) {
      return 'End date must be after start date';
    }
    return null;
  }
}
