import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'student/student_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'staff/staff_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Login & Get User Data
      Map<String, dynamic>? userData = await _authService.loginUser(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim()
      );

      if (!mounted) return; // Added check
      setState(() => _isLoading = false);

      if (userData != null) {
        String role = userData['role'];

        // 2. Route based on Role
        String normalizedRole = role.trim().toLowerCase();
        print("DEBUG: User Role Detected: '$normalizedRole' (Original: '$role')");

        Widget nextScreen;
        if (normalizedRole == 'admin') {
          nextScreen = const AdminDashboard();
        } else if (normalizedRole == 'staff') {
          nextScreen = const StaffDashboard();
        } else if (normalizedRole == 'student') {
          nextScreen = const StudentDashboard();
        } else {
          // Fallback for unknown role
          print("ERROR: Unknown role '$role'. Defaulting to StudentDashboard but showing warning.");
          // You might want to show an error screen here instead
          nextScreen = const StudentDashboard(); 
        }

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = e.toString().replaceAll("Exception:", "").trim();
        
        if (errorMessage.toLowerCase().contains("pending admin approval")) {
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               title: const Text("Approval Pending"),
               content: const Text("Your account is currently waiting for Admin approval. You will be able to login once an administrator verifies your details."),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
               ],
             ),
           );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo[800]!, Colors.indigo[400]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school, size: 80, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text(
                      "APEC NO-DUES",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      "Digital Clearance System",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: "Email address",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("SIGN IN", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text("Don't have an account? Register"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}