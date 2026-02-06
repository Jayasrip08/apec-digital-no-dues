import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import 'staff_student_detail.dart';
import '../profile_screen.dart';
import '../../services/pdf_service.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String? _staffDept;
  bool _isLoading = true;
  String _loadingMessage = "Loading department data...";

  // Data Store
  List<Map<String, dynamic>> _allStudents = []; // Stores calculated fee data
  List<String> _batches = [];
  
  // Filters
  String _searchQuery = "";
  String? _selectedBatch;
  String _selectedStatus = 'All'; // All, Paid, Pending, Overdue

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Fetching department info...";
    });

    try {
      // 1. Get Staff Dept
      final staffDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (!staffDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      _staffDept = staffDoc.data()?['dept'];

      if (_staffDept == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _loadingMessage = "Loading fee structures...");

      // 2. Fetch Fee Structures (Active)
      final feeSnapshot = await FirebaseFirestore.instance
          .collection('fee_structures')
          .where('isActive', isEqualTo: true)
          .get();
      
      final feeStructures = feeSnapshot.docs.map((d) => d.data()).toList();

      setState(() => _loadingMessage = "Loading students & payments...");

      // 3. Fetch Students in Dept
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('dept', isEqualTo: _staffDept)
          .get();

      // 4. Fetch All Payments for Dept (Remove status filter to get pending ones too)
      final paymentSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('dept', isEqualTo: _staffDept)
          //.where('status', isEqualTo: 'verified') // REMOVED: Fetch all to see pending
          .get();

      // 5. Process Data Calculation
      List<Map<String, dynamic>> processedList = [];
      Set<String> batchesFound = {};

      for (var doc in studentSnapshot.docs) {
        final data = doc.data();
        final String uid = doc.id;
        final String batch = data['batch'] ?? '';
        if (batch.isNotEmpty) batchesFound.add(batch);
        
        final String studentType = data['studentType'] ?? 'day_scholar';
        final String quota = data['quotaCategory'] ?? 'Management';
        final String busPlace = data['busPlace'] ?? '';

        // Calculate Total Fee for this student
        // Pass 'dept' (stored in data['dept'] or use _staffDept)
        double totalFee = _calculateTotalFee(feeStructures, batch, data['dept'] ?? '', studentType, quota, busPlace);
        
        // Calculate Paid Amounts (Verified vs Pending)
        double verifiedPaid = 0;
        double pendingPaid = 0;
        
        for (var p in paymentSnapshot.docs) {
          if (p['studentId'] == uid) {
             final amount = (p['amount'] as num).toDouble();
             final status = p['status'] ?? 'pending';
             
             if (status == 'verified') {
               verifiedPaid += amount;
             } else if (status == 'pending') {
               pendingPaid += amount;
             }
          }
        }

        // Balance is based on Verified Only
        double balance = totalFee - verifiedPaid;
        if (balance < 0) balance = 0;

        processedList.add({
          'uid': uid,
          'name': data['name'] ?? 'Unknown',
          'regNo': data['regNo'] ?? '',
          'batch': batch,
          'totalFee': totalFee,
          'verifiedPaid': verifiedPaid,
          'pendingPaid': pendingPaid,
          'balance': balance,
          'rawData': data, 
        });
      }

      if (mounted) {
        setState(() {
          _allStudents = processedList;
          _batches = batchesFound.toList()..sort();
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = "Error: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  double _calculateTotalFee(List<Map<String, dynamic>> structures, String batch, String dept, String type, String quota, String busPlace) {
    double total = 0;

    for (var struct in structures) {
      final sDept = struct['dept'] ?? 'All';
      if (sDept != 'All' && sDept != dept) continue;

      if (struct.containsKey('batch')) {
         final sBatch = struct['batch'];
         if (sBatch != null && sBatch != 'All' && sBatch != batch) continue;
      }

      final components = struct['components'] as Map<String, dynamic>? ?? {};
      
      if (components.containsKey('Tuition Fee')) {
        final tuitionMap = components['Tuition Fee'];
        if (tuitionMap is Map) {
           var key = tuitionMap.keys.firstWhere(
             (k) => k.toString().toLowerCase() == quota.toLowerCase(), 
             orElse: () => ''
           );
           if (key.isNotEmpty) total += (tuitionMap[key] as num?)?.toDouble() ?? 0;
        }
      }

      if (type == 'bus_user' && components.containsKey('Bus Fee')) {
        final busMap = components['Bus Fee'];
        if (busMap is Map) total += (busMap[busPlace] as num?)?.toDouble() ?? 0;
      }

      if (type == 'hosteller' && components.containsKey('Hostel Fee')) {
         final hostelMap = components['Hostel Fee'];
         if (hostelMap is Map) total += (hostelMap['Standard'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getFilteredList() {
    return _allStudents.where((s) {
      final searchLower = _searchQuery.toLowerCase();
      if (searchLower.isNotEmpty) {
        final name = s['name'].toString().toLowerCase();
        final reg = s['regNo'].toString().toLowerCase();
        if (!name.contains(searchLower) && !reg.contains(searchLower)) return false;
      }

      if (_selectedBatch != null && s['batch'] != _selectedBatch) return false;

      final balance = s['balance'] as double;
      final pendingAmount = s['pendingPaid'] as double;
      final totalFee = s['totalFee'] as double;

      if (_selectedStatus == 'Verified') {
        // Fully Paid and Verified (AND Total Fee > 0 to exclude config errors)
        if (balance > 0 || totalFee == 0) return false;
      } 
      else if (_selectedStatus == 'Pending') {
         if (pendingAmount <= 0) return false;
      } 
      else if (_selectedStatus == 'Not Paid') {
         if (balance <= 0 || pendingAmount > 0) return false;
      }

      return true;
    }).toList();
  }

  // Multi-Select State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(uid);
      }
    });
  }

  void _enterSelectionMode(String uid) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(uid);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _downloadReport() async {
    // Determine target list: Selection or Filtered View
    var targetList = <Map<String, dynamic>>[];
    
    if (_isSelectionMode && _selectedIds.isNotEmpty) {
      targetList = _allStudents.where((s) => _selectedIds.contains(s['uid'])).toList();
    } else {
      targetList = _getFilteredList();
    }

    if (targetList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No students selected for report")));
      return;
    }
    
    await PdfService().generateDeptReport(
      _staffDept ?? "Department", 
      _isSelectionMode ? "Custom Selection" : _selectedBatch, 
      _isSelectionMode ? "Selected (${targetList.length})" : _selectedStatus, 
      targetList
    );
    
    if (_isSelectionMode) _exitSelectionMode(); // Auto-exit after download
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredList();

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode) : null,
        title: Text(_isSelectionMode ? "${_selectedIds.length} Selected" : (_staffDept != null ? "$_staffDept Dashboard" : "Staff Console")),
        backgroundColor: _isSelectionMode ? Colors.grey[800] : Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _downloadReport, 
            icon: const Icon(Icons.file_download),
            tooltip: _isSelectionMode ? "Download Selected" : "Download Report",
          ),
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
             IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            )
          ]
        ],
      ),
      body: Column(
        children: [
          // FILTERS CONTAINER (Hide in selection mode for cleaner look? No, keep it.)
          if (!_isSelectionMode)
           Container(
            padding: const EdgeInsets.all(12),
            color: Colors.indigo[50],
            child: Column(
              children: [
                // Top Row: Search
                 TextField(
                  decoration: InputDecoration(
                    hintText: "Search Name or Reg No",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),
                // Bottom Row: Dropdowns
                Row(
                  children: [
                    // Batch Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text("Batch"),
                            value: _selectedBatch,
                            items: [
                              const DropdownMenuItem(value: null, child: Text("All Batches")),
                              ..._batches.map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            ], 
                            onChanged: (v) => setState(() => _selectedBatch = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                     // Status Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedStatus,
                            items: ['All', 'Verified', 'Pending', 'Not Paid'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _selectedStatus = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // HEADER ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(flex: 3, child: Text("STUDENT (${filteredList.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const Expanded(flex: 2, child: Text("FEE INFO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                const SizedBox(width: 40), // Space for arrow
              ],
            ),
          ),

          // LIST
          Expanded(
            child: _isLoading 
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text(_loadingMessage)]))
              : filteredList.isEmpty
                  ? const Center(child: Text("No students found matching filters."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: filteredList.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = filteredList[i];
                        final uid = item['uid'];
                        
                        final balance = item['balance'] as double;
                        final pendingAmount = item['pendingPaid'] as double;
                        final totalFee = item['totalFee'] as double;
                        
                        // Status Logic
                        bool isPaid = balance <= 0;
                        bool isPending = pendingAmount > 0;
                        bool isNoFee = totalFee == 0; // NEW: Check for 0 fee
                        bool isSelected = _selectedIds.contains(uid);

                        Color statusColor;
                        String statusText;

                        if (isNoFee) {
                          statusColor = Colors.grey;
                          statusText = "NO FEE SET";
                        } else if (isPaid) {
                          statusColor = Colors.green;
                          statusText = "PAID";
                        } else if (isPending) {
                          statusColor = Colors.orange;
                          statusText = "Verifying...";
                        } else {
                          statusColor = Colors.red;
                          statusText = "Due: ₹${balance.toStringAsFixed(0)}";
                        }

                        return InkWell(
                          onTap: () {
                             if (_isSelectionMode) {
                               _toggleSelection(uid);
                             } else {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => StaffStudentDetail(
                                 studentData: item['rawData'], 
                                 studentId: uid
                               )));
                             }
                          },
                          onLongPress: () => _enterSelectionMode(uid), // ENTER SELECTION MODE
                          child: Container(
                             color: isSelected ? Colors.indigo.withOpacity(0.1) : null,
                             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                             child: Row(
                              children: [
                                // Selection Checkbox or Avatar
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isSelected ? Colors.indigo : Colors.grey,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: statusColor.withOpacity(0.1),
                                      child: Text(
                                        item['name'][0].toUpperCase(),
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),

                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("${item['regNo']} • ${item['batch']}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                // Fee Info
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          fontSize: 13
                                        ),
                                      ),
                                      if (isPending)
                                        Text(
                                          "Pending: ₹${pendingAmount.toStringAsFixed(0)}",
                                          style: const TextStyle(fontSize: 10, color: Colors.orange),
                                        ),
                                      Text(
                                        "Total: ₹${totalFee.toStringAsFixed(0)}",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (!_isSelectionMode) const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
