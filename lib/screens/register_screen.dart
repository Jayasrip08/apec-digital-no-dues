import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController(); // NEW: For staff/admin
  
  // Dropdown Selections
  String _selectedRole = 'student'; // NEW: Role selector
  String _selectedDept = 'CSE';
  String _selectedBatch = ''; // Will be set from Firestore
  String _selectedQuota = 'Management'; // Critical for Fee Structure
  String _selectedStudentType = 'day_scholar'; // NEW: Student type
  String? _selectedBusPlace; // NEW: Bus place if bus_user
  List<String> _availableBusPlaces = []; // NEW: Dynamic bus places
  bool _isLoading = false;
  List<String> _activeBatches = []; // Dynamic list from Firestore
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _loadActiveBatches();
  }

  Future<void> _loadActiveBatches() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academic_years')
          .where('isActive', isEqualTo: true)
          .get();
      
      if (mounted) {
        setState(() {
          _activeBatches = snapshot.docs.map((doc) => doc['name'] as String).toList();
          if (_activeBatches.isNotEmpty) {
            _selectedBatch = _activeBatches.first;
          }
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBatches = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading batches: $e')),
        );
      }
    }
  }

  bool _loadingBusPlaces = false; // Add loading state

  Future<void> _loadBusPlaces() async {
    setState(() => _loadingBusPlaces = true);
    try {
      // Fetch fee structures to get bus places - Get MOST RECENT active one
      // Fetch fee structures to get bus places
      // OPTIMIZATION: Fetch all active structures and sort client-side to avoid needing a Firestore composite index
      final snapshot = await FirebaseFirestore.instance
          .collection('fee_structures')
          .where('isActive', isEqualTo: true)
          .get();
      
      final docs = snapshot.docs.toList();
      // Sort by lastUpdated descending (newest first)
      docs.sort((a, b) {
        final aTime = (a.data()['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b.data()['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      List<String> foundPlaces = [];
      
      for (var doc in docs) {
        final data = doc.data();
        final components = data['components'] as Map<String, dynamic>?;
        
        if (components != null && components['Bus Fee'] is Map) {
          final busFeeMap = components['Bus Fee'] as Map<String, dynamic>;
          if (busFeeMap.isNotEmpty) {
            foundPlaces = busFeeMap.keys.toList().cast<String>();
            break; // Found one with bus fees, stop looking
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableBusPlaces = foundPlaces;
          if (_availableBusPlaces.isNotEmpty) {
            _selectedBusPlace = _availableBusPlaces.first;
          } else {
             _selectedBusPlace = null;
          }
          _loadingBusPlaces = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBusPlaces = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bus routes: $e')),
        );
      }
    }
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == 'student' && _selectedBatch.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot register student without an active batch. Please contact admin.'), backgroundColor: Colors.red),
        );
        return;
      }

      // Call Auth Service
      String? error = await AuthService().registerUser(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        role: _selectedRole, // Use selected role
        regNo: _selectedRole == 'student' ? _regNoCtrl.text.trim() : null,
        dept: (_selectedRole == 'student' || _selectedRole == 'staff') ? _selectedDept : null,
        quotaCategory: _selectedRole == 'student' ? _selectedQuota : null,
        employeeId: (_selectedRole == 'staff' || _selectedRole == 'admin') ? _employeeIdCtrl.text.trim() : null,
        batch: _selectedRole == 'student' ? _selectedBatch : null, // NEW
        studentType: _selectedRole == 'student' ? _selectedStudentType : null, // NEW
        busPlace: _selectedRole == 'student' && _selectedStudentType == 'bus_user' ? _selectedBusPlace : null, // NEW
      );

      setState(() => _isLoading = false);

      if (error == null) {
        if (mounted) {
          // Different messages based on role
          String message;
          if (_selectedRole == 'admin') {
            message = "Registration Successful! Please Login.";
          } else {
            message = "Registration Successful! Your account is pending admin approval.";
          }
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          Navigator.pop(context); // Return to Login
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo[800]!, Colors.indigo[400]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Join the Digital No-Dues Portal",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      
                      // ROLE SELECTOR
                      const _SectionHeader(title: "Identity"),
                      DropdownButtonFormField(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: "Registering as",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_pin_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'student', child: Text('Student')),
                          DropdownMenuItem(value: 'staff', child: Text('Staff / HOD')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (val) => setState(() => _selectedRole = val.toString()),
                      ),
                      const SizedBox(height: 24),

                      // CONDITIONAL FIELDS
                      if (_selectedRole == 'student' || _selectedRole == 'staff') ...[
                        const _SectionHeader(title: "Academic Context"),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('departments').orderBy('name').snapshots(),
                          builder: (context, snapshot) {
                            List<String> depts = [];
                            if (snapshot.hasData) {
                              depts = snapshot.data!.docs.map((d) => d['name'] as String).toList();
                            }
                            if (depts.isEmpty) depts = ['CSE', 'ECE', 'MECH', 'CIVIL']; // Fallback

                            return DropdownButtonFormField(
                              value: depts.contains(_selectedDept) ? _selectedDept : null,
                              decoration: InputDecoration(
                                labelText: "Department", 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.account_balance_outlined),
                              ),
                              items: depts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => setState(() => _selectedDept = val.toString()),
                              validator: (val) => val == null ? 'Please select a department' : null,
                            );
                          }
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedRole == 'student') ...[
                        if (_activeBatches.isNotEmpty)
                          DropdownButtonFormField(
                            value: _selectedBatch,
                            decoration: InputDecoration(
                              labelText: "Batch", 
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.group_outlined),
                            ),
                            items: _activeBatches.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _selectedBatch = val.toString()),
                          )
                        else if (!_loadingBatches)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Expanded(child: Text("No active batches found. Admin must create/activate an academic year before students can register.", style: TextStyle(color: Colors.red, fontSize: 12))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('quotas').orderBy('name').snapshots(),
                          builder: (context, snapshot) {
                            List<String> quotas = [];
                            if (snapshot.hasData) {
                              quotas = snapshot.data!.docs.map((d) => d['name'] as String).toList();
                            }
                            if (quotas.isEmpty) quotas = ['Management', 'Counseling']; // Fallback

                            // Ensure default is valid or null
                            String? validQuota = quotas.contains(_selectedQuota) ? _selectedQuota : (quotas.isNotEmpty ? quotas.first : null);

                            return DropdownButtonFormField(
                              value: validQuota,
                              decoration: InputDecoration(
                                labelText: "Admission Quota",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.assignment_ind_outlined),
                              ),
                              items: quotas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => setState(() => _selectedQuota = val.toString()),
                              validator: (val) => val == null ? 'Please select a quota' : null,
                            );
                          }
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedStudentType,
                          decoration: InputDecoration(
                            labelText: "Type",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.directions_walk_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'day_scholar', child: Text('Day Scholar')),
                            DropdownMenuItem(value: 'hosteller', child: Text('Hosteller')),
                            DropdownMenuItem(value: 'bus_user', child: Text('Bus User')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedStudentType = val!;
                              if (val == 'bus_user') _loadBusPlaces();
                            });
                          },
                        ),
                        
                        // BUS ROUTE SECTION
                        if (_selectedStudentType == 'bus_user') ...[
                          const SizedBox(height: 16),
                          if (_loadingBusPlaces)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(children: [CircularProgressIndicator.adaptive(), SizedBox(width: 10), Text("Loading bus routes...")]),
                            )
                          else if (_availableBusPlaces.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: _selectedBusPlace,
                              decoration: InputDecoration(
                                labelText: "Bus Route",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.bus_alert_outlined),
                              ),
                              items: _availableBusPlaces.map((place) => DropdownMenuItem(value: place, child: Text(place))).toList(),
                              onChanged: (val) => setState(() => _selectedBusPlace = val),
                              validator: (v) => v == null ? "Please select your bus route" : null,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Expanded(child: Text("No bus routes defined. Please contact admin to set up bus fees.", style: TextStyle(color: Colors.orange))),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      const _SectionHeader(title: "Personal Credentials"),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(labelText: "Full Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person_outline)),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      if (_selectedRole == 'student') 
                        TextFormField(
                          controller: _regNoCtrl,
                          decoration: InputDecoration(labelText: "Register Number", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.numbers_outlined)),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        )
                      else
                        TextFormField(
                          controller: _employeeIdCtrl,
                          decoration: InputDecoration(labelText: "Employee ID", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.badge_outlined)),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(labelText: "Email address", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email_outlined)),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.lock_outline)),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : Text("CREATE ${_selectedRole.toUpperCase()} ACCOUNT", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Already have an account? Sign In"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 1.1)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
