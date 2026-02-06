# Logging Service Usage Guide

## Overview
The logging service provides comprehensive logging capabilities for debugging, monitoring, and auditing the APEC No-Dues system.

## Features
- Multiple log levels (INFO, WARNING, ERROR, DEBUG)
- Category-based logging
- Firestore integration
- User action tracking
- Payment event logging
- Authentication logging
- Notification logging

## Usage Examples

### Basic Logging

```dart
import 'package:apec_no_dues/services/log_service.dart';

// Info log
await LogService().info('User logged in successfully');

// Warning log
await LogService().warning('Payment deadline approaching');

// Error log
await LogService().error(
  'Failed to upload receipt',
  error: e,
  stackTrace: stackTrace,
);

// Debug log
await LogService().debug('Processing payment data');
```

### Category-Based Logging

```dart
// With category
await LogService().info(
  'Fee structure created',
  category: 'Admin',
  metadata: {
    'dept': 'CSE',
    'amount': 85000,
  },
);
```

### User Action Logging

```dart
// Log user actions
await LogService().logUserAction(
  'Submitted payment',
  details: {
    'amount': 85000,
    'transactionId': 'TXN123456',
  },
);
```

### Payment Logging

```dart
// Log payment events
await LogService().logPayment(
  action: 'submitted',
  studentId: userId,
  transactionId: 'TXN123456',
  amount: 85000.0,
  status: 'under_review',
);
```

### Authentication Logging

```dart
// Log auth events
await LogService().logAuth(
  'login_success',
  userId: user.uid,
  email: user.email,
);
```

### Notification Logging

```dart
// Log notification events
await LogService().logNotification(
  type: 'payment_reminder',
  recipientId: studentId,
  title: 'Payment Deadline Approaching',
  body: '3 days remaining',
  sent: true,
);
```

## Integration Examples

### In Payment Screen

```dart
// Before submission
await LogService().logUserAction('Started payment submission');

try {
  // Upload receipt
  await LogService().debug('Uploading receipt image');
  
  // Submit payment
  await LogService().logPayment(
    action: 'submitted',
    studentId: userId,
    transactionId: txnId,
    amount: amount,
    status: 'under_review',
  );
  
  await LogService().info('Payment submitted successfully');
} catch (e) {
  await LogService().error(
    'Payment submission failed',
    category: 'Payment',
    error: e,
    stackTrace: stackTrace,
  );
}
```

### In Admin Verification

```dart
// When verifying payment
await LogService().logPayment(
  action: 'verified',
  studentId: paymentData['studentId'],
  transactionId: paymentData['transactionId'],
  amount: paymentData['amount'],
  status: 'verified',
);

await LogService().logUserAction(
  'Verified payment',
  details: {
    'paymentId': paymentId,
    'adminId': adminId,
  },
);
```

### In Error Handler

```dart
// In error_handler.dart
static void showError(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
}) {
  // Log the error
  LogService().error(
    message,
    category: 'UI',
    metadata: {'hasRetry': onRetry != null},
  );
  
  // Show snackbar
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

## Viewing Logs

### In Firebase Console
1. Go to Firestore Database
2. Navigate to `logs` collection
3. Filter by:
   - `level` (INFO, WARNING, ERROR, DEBUG)
   - `category` (Payment, Authentication, etc.)
   - `userId`
   - `timestamp`

### Query Logs Programmatically

```dart
// Get user logs
StreamBuilder<QuerySnapshot>(
  stream: LogService().getUserLogs(userId, limit: 50),
  builder: (context, snapshot) {
    // Display logs
  },
);

// Get error logs
StreamBuilder<QuerySnapshot>(
  stream: LogService().getErrorLogs(limit: 100),
  builder: (context, snapshot) {
    // Display errors
  },
);

// Get logs by category
StreamBuilder<QuerySnapshot>(
  stream: LogService().getLogsByCategory('Payment', limit: 100),
  builder: (context, snapshot) {
    // Display payment logs
  },
);
```

## Log Structure in Firestore

```json
{
  "level": "INFO",
  "message": "Payment submitted successfully",
  "category": "Payment",
  "userId": "abc123",
  "userEmail": "student@example.com",
  "timestamp": "2026-02-04T22:00:00Z",
  "metadata": {
    "amount": 85000,
    "transactionId": "TXN123456"
  },
  "stackTrace": null,
  "platform": "flutter"
}
```

## Log Levels

| Level | Use Case | Color |
|-------|----------|-------|
| INFO | Normal operations, successful actions | Blue |
| WARNING | Potential issues, approaching limits | Orange |
| ERROR | Failures, exceptions | Red |
| DEBUG | Development debugging | Gray |

## Categories

- **General**: Miscellaneous logs
- **UserAction**: User interactions
- **Payment**: Payment-related events
- **Authentication**: Login/logout events
- **Notification**: FCM/Email notifications
- **API**: External API calls
- **Admin**: Admin operations
- **Staff**: Staff operations

## Log Retention

Logs are stored in Firestore. To manage storage:

```dart
// Clear logs older than 30 days
await LogService().clearOldLogs(daysToKeep: 30);
```

**Recommendation**: Set up a Cloud Function to run monthly:

```javascript
// In functions/index.js
exports.cleanupOldLogs = onSchedule({
  schedule: '0 0 1 * *', // First day of each month
  timeZone: 'Asia/Kolkata',
}, async (event) => {
  const db = admin.firestore();
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 30);
  
  const oldLogs = await db.collection('logs')
    .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
    .get();
  
  const batch = db.batch();
  oldLogs.docs.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  
  console.log(`Deleted ${oldLogs.size} old logs`);
});
```

## Best Practices

1. **Use Appropriate Levels**
   - INFO for successful operations
   - WARNING for potential issues
   - ERROR for failures
   - DEBUG for development only

2. **Add Metadata**
   - Include relevant context
   - Use structured data (objects)
   - Don't log sensitive information (passwords, tokens)

3. **Category Consistency**
   - Use predefined categories
   - Create new categories sparingly
   - Document custom categories

4. **Performance**
   - Logging is async (doesn't block UI)
   - Logs are batched to Firestore
   - Console logs always print immediately

5. **Privacy**
   - Don't log personal information
   - Sanitize user data
   - Follow GDPR guidelines

## Monitoring Dashboard (Future Enhancement)

Create an admin screen to view logs:

```dart
class LogViewerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('System Logs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: LogService().getErrorLogs(limit: 100),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final log = snapshot.data!.docs[index].data();
              return LogTile(log: log);
            },
          );
        },
      ),
    );
  }
}
```

## Cost Considerations

- Firestore charges for reads/writes
- Each log = 1 write
- Estimate: 1,000 logs/day = 30,000 writes/month
- Firestore free tier: 20,000 writes/day
- **Recommendation**: Use logging judiciously in production

---

*Last Updated: February 4, 2026*
