# APEC Digital No-Dues System

A comprehensive Flutter + Firebase fee management system for Adhiparasakthi Engineering College (APEC) with automated payment tracking, OCR receipt verification, and digital certificate generation.

## 🎯 Overview

This system manages student fees using a tripartite role model:
- **Students**: View fees, submit payments, download certificates
- **Staff/HODs**: Monitor assigned students' payment status
- **Admin (Accounts Office)**: Verify payments, manage fee structures

### Key Features

✅ **Role-Based Access Control**
- Student, Staff, and Admin roles
- Secure authentication with Firebase Auth
- Firestore security rules

✅ **Academic Year Management**
- Create and manage academic years
- Semester-based fee tracking
- Activate/deactivate periods

✅ **Payment Processing**
- UPI redirect (no payment gateway)
- Receipt upload with OCR
- Multi-status tracking (under_review → verified/rejected)
- Payment history view

✅ **Automated Notifications**
- FCM push notifications
- Payment deadline reminders (7, 3, 1 days before)
- Status change notifications
- Peak activity time optimization

✅ **Admin Features**
- Fee structure management
- Payment verification
- Receipt review with OCR data
- Digital No-Dues certificate generation

✅ **Cloud Automation**
- Scheduled payment reminders
- Automatic notification triggers
- Activity tracking for optimal notification timing

---

## 🏗️ Architecture

### Tech Stack

**Frontend:**
- Flutter (Android + Web support)
- Material Design UI

**Backend:**
- Firebase Authentication
- Cloud Firestore (NoSQL database)
- Firebase Storage (receipt images)
- Firebase Cloud Functions (automation)
- Firebase Cloud Messaging (notifications)

**AI/ML:**
- Google ML Kit Text Recognition (OCR)

---

## 📁 Project Structure

```
apec_no_dues/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── firebase_options.dart        # Firebase configuration
│   │
│   ├── models/                      # Data models
│   │   └── academic_period.dart     # AcademicYear & Semester models
│   │
│   ├── screens/                     # UI screens
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   │
│   │   ├── student/
│   │   │   ├── student_dashboard.dart
│   │   │   ├── payment_screen.dart
│   │   │   └── payment_history_screen.dart
│   │   │
│   │   ├── admin/
│   │   │   ├── admin_dashboard.dart
│   │   │   ├── fee_setup_screen.dart
│   │   │   ├── verification_screen.dart
│   │   │   └── academic_year_screen.dart
│   │   │
│   │   └── staff/
│   │       ├── staff_dashboard.dart
│   │       └── staff_student_detail.dart
│   │
│   ├── services/                    # Business logic
│   │   ├── auth_service.dart        # Authentication
│   │   ├── fee_service.dart         # Fee management
│   │   ├── pdf_service.dart         # Certificate generation
│   │   ├── notification_service.dart # FCM handling
│   │   └── activity_tracker.dart    # User activity monitoring
│   │
│   └── widgets/                     # Reusable widgets
│       └── payment_status_badge.dart
│
├── functions/                       # Cloud Functions
│   ├── index.js                     # Function definitions
│   └── package.json                 # Dependencies
│
├── firestore.rules                  # Security rules
├── firebase.json                    # Firebase config
└── pubspec.yaml                     # Flutter dependencies
```

---

## 🔐 Security

### Firestore Security Rules

- **Students**: Can only read/write their own data
- **Staff**: Read-only access to assigned students
- **Admin**: Full access to all collections
- **Payment Status**: Only admin can verify/reject
- **Notifications**: Users can only mark their own as read

### Authentication

- Email/Password authentication
- Role stored in Firestore `users` collection
- Role-based routing on login

---

## 📊 Database Schema

### Collections

#### `users`
```json
{
  "uid": "string",
  "email": "string",
  "name": "string",
  "role": "student|staff|admin",
  "regNo": "string",
  "dept": "string",
  "quotaCategory": "string",
  "fcmToken": "string",
  "lastActiveAt": "timestamp"
}
```

#### `payments`
```json
{
  "studentId": "string",
  "studentName": "string",
  "amount": "number",
  "transactionId": "string",
  "receiptUrl": "string",
  "status": "under_review|verified|rejected",
  "timestamp": "timestamp",
  "verifiedAt": "timestamp",
  "rejectionReason": "string"
}
```

#### `fee_structures`
```json
{
  "academicYear": "string",
  "semester": "string",
  "dept": "string",
  "quotaCategory": "string",
  "amount": "number",
  "deadline": "timestamp"
}
```

#### `academic_years`
```json
{
  "name": "string",
  "startDate": "timestamp",
  "endDate": "timestamp",
  "isActive": "boolean"
}
```

#### `semesters`
```json
{
  "academicYear": "string",
  "name": "string",
  "number": "number",
  "startDate": "timestamp",
  "endDate": "timestamp",
  "isActive": "boolean"
}
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Firebase CLI
- Android Studio / VS Code
- Firebase project (Blaze plan for Cloud Functions)

### Installation

1. **Clone the repository**
   ```bash
   cd e:\apec_no_dues
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   ```bash
   firebase login
   firebase init
   ```

4. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

5. **Deploy Security Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

For detailed deployment instructions, see [deployment_guide.md](deployment_guide.md).

---

## 📱 User Flows

### Student Flow
1. Register with email, select department and quota
2. View assigned fee amount and deadline
3. Click "Pay Fee" → redirected to UPI app
4. Upload payment receipt screenshot
5. OCR extracts transaction details
6. Submit for admin review
7. Receive notification when verified
8. Download Digital No-Dues certificate

### Admin Flow
1. Create academic year and semesters
2. Define fee structures for each category
3. Set payment deadlines
4. Review pending payments
5. View receipt images and OCR data
6. Verify or reject payments
7. System auto-generates certificate on verification

### Staff Flow
1. View assigned students
2. Check payment status (paid/unpaid/verified)
3. View payment history (read-only)
4. Use data for exam clearance

---

## 🔔 Notifications

### Automated Triggers

1. **Payment Reminders**
   - Sent at 7, 3, and 1 day(s) before deadline
   - Scheduled daily at 10 AM IST
   - Only sent during student's peak activity time

2. **Status Change Notifications**
   - Payment verified → Success notification
   - Payment rejected → Rejection notification with reason

3. **Welcome Notification**
   - Sent on user registration

---

## 🧪 Testing

### Run Tests
```bash
flutter test
```

### Check Code Quality
```bash
flutter analyze
```

### Build APK
```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release
```

---

## 📦 Dependencies

### Flutter Packages
- `firebase_core`: ^3.15.2
- `firebase_auth`: ^5.7.0
- `cloud_firestore`: ^5.6.12
- `firebase_storage`: ^12.4.10
- `firebase_messaging`: ^15.2.10
- `google_mlkit_text_recognition`: ^0.15.1
- `image_picker`: ^1.2.1
- `pdf`: ^3.11.3
- `printing`: ^5.14.2
- `url_launcher`: ^6.3.2
- `intl`: ^0.20.2

### Cloud Functions
- `firebase-functions`: ^5.0.0
- `firebase-admin`: ^12.0.0

---

## 🎨 UI/UX Features

- Material Design 3
- Responsive layouts
- Status color coding
- Loading states
- Error handling
- Snackbar notifications
- Modal bottom sheets
- Image preview
- PDF generation

---

## 🔧 Configuration

### Student Categories
- Management Quota
- Counseling (Government Quota)
- SC/ST Scholarship
- 7.5% Reservation

### Departments
- CSE (Computer Science)
- ECE (Electronics)
- MECH (Mechanical)
- CIVIL (Civil Engineering)
- EEE (Electrical)
- IT (Information Technology)

---

## 📈 Future Enhancements

- [ ] Multi-semester payment tracking
- [ ] Partial payment support
- [ ] Email notifications
- [ ] SMS notifications
- [ ] Payment analytics dashboard
- [ ] Export reports (Excel/PDF)
- [ ] Bulk fee structure upload
- [ ] Student assignment automation for staff
- [ ] Web admin panel
- [ ] iOS support

---

## 🤝 Contributing

This is a college project. For improvements:
1. Create feature branch
2. Make changes
3. Test thoroughly
4. Submit for review

---

## 📄 License

This project is for educational purposes for Adhiparasakthi Engineering College.

---

## 👥 Team

**Developed for:** Adhiparasakthi Engineering College (APEC)
**Purpose:** Digital Fee Management & No-Dues Certificate System

---

## 📞 Support

For issues or questions:
- Check [deployment_guide.md](deployment_guide.md)
- Review Firebase Console logs
- Check Firestore security rules

---

## 🎉 Acknowledgments

- Firebase for backend infrastructure
- Google ML Kit for OCR
- Flutter team for the framework
- APEC for the opportunity

---

*Last Updated: February 4, 2026*
