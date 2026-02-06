// lib/mock_data.dart

class MockData {
  // Simulate a Student User
  static Map<String, dynamic> studentProfile = {
    "name": "Arun Kumar",
    "regNo": "410121104001",
    "dept": "CSE",
    "quota": "Management",
    "totalFee": 85000,
    "paidFee": 40000, // Partial payment done
    "status": "Pending", // Pending, Verified, No Dues
  };

  // Simulate Pending Payments for Admin
  static List<Map<String, dynamic>> pendingPayments = [
    {
      "id": "PAY001",
      "studentName": "Priya S",
      "regNo": "410121104055",
      "amount": 45000,
      "date": "2025-12-22",
      "txnId": "UPI22334455",
      "imageUrl": "https://via.placeholder.com/300x600.png?text=Receipt+A",
    },
    {
      "id": "PAY002",
      "studentName": "Rahul M",
      "regNo": "410121104012",
      "amount": 12000,
      "date": "2025-12-23",
      "txnId": "UPI99887766",
      "imageUrl": "https://via.placeholder.com/300x600.png?text=Receipt+B",
    },
  ];
}