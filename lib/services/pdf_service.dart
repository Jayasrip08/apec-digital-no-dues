import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<void> generateAndDownloadCertificate(
    String studentName, 
    String regNo, 
    String dept, 
    String batch, 
    String semester,
    Map<String, double> paidFees, // NEW: Actual fees paid by student
  ) async {
    final pdf = pw.Document();

    // Calculate total
    double totalPaid = paidFees.values.fold(0, (sum, val) => sum + val);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Header(level: 0, child: pw.Text("ADHIPARASAKTHI ENGINEERING COLLEGE")),
              pw.SizedBox(height: 20),
              pw.Text("DIGITAL NO-DUES CERTIFICATE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text("SEMESTER $semester", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 30),
              pw.Text("This is to certify that", style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Text(studentName.toUpperCase(), style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Register No: $regNo | Dept: $dept | Batch: $batch", style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 30),
              pw.Text("Has successfully cleared the following dues for Semester $semester:", 
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              
              // Fee Details Table
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  children: [
                    // Table Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Fee Component", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("Amount Paid", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Divider(),
                    // Fee Items
                    ...paidFees.entries.map((entry) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(entry.key),
                          pw.Text("₹ ${entry.value.toStringAsFixed(0)}"),
                        ],
                      ),
                    )).toList(),
                    pw.Divider(),
                    // Total
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Total Paid", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        pw.Text("₹ ${totalPaid.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}")],),
                  pw.Column(children: [
                    pw.Container(height: 40, width: 100, color: PdfColors.grey300, child: pw.Center(child: pw.Text("VERIFIED"))),
                    pw.Text("Accounts Officer Sign")
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'No-Dues-Certificate-$regNo-Sem$semester',
    );
  }

  // Generate Department Fee Report
  Future<void> generateDeptReport(
    String dept,
    String? batch,
    String statusFilter,
    List<Map<String, dynamic>> students, // List of {name, regNo, batch, totalFee, paidFee, balance}
  ) async {
    final pdf = pw.Document();
    
    // Aggregates
    double totalExpected = 0;
    double totalCollected = 0;
    double totalPending = 0;
    
    for (var s in students) {
      totalExpected += (s['totalFee'] as num).toDouble();
      totalCollected += (s['verifiedPaid'] as num? ?? 0).toDouble();
      totalPending += (s['balance'] as num).toDouble();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pw.PageOrientation.landscape, // Wider for table
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text("ADHIPARASAKTHI ENGINEERING COLLEGE")),
            pw.Text("DEPARTMENT FEE STATUS REPORT (${dept.toUpperCase()})", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Generated: ${DateTime.now().toString().split('.')[0]}"),
                pw.Text("Batch: ${batch ?? 'All'} | Filter: $statusFilter"),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            // SUMMARY BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [pw.Text("Total Students"), pw.Text("${students.length}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                  pw.Column(children: [pw.Text("Total Expected"), pw.Text("₹ ${totalExpected.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                  pw.Column(children: [pw.Text("Verified Collected"), pw.Text("₹ ${totalCollected.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green))]),
                  pw.Column(children: [pw.Text("Total Pending"), pw.Text("₹ ${totalPending.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red))]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // TABLE
            pw.Table.fromTextArray(
              context: context,
              headers: ['Reg No', 'Name', 'Batch', 'Total Fee', 'Verified', 'Pending', 'Balance', 'Status'],
              data: students.map((s) {
                final total = (s['totalFee'] as num).toDouble();
                final balance = (s['balance'] as num).toDouble();
                final verified = (s['verifiedPaid'] as num? ?? 0).toDouble();
                final pending = (s['pendingPaid'] as num? ?? 0).toDouble();
                
                String statusDict;
                PdfColor statusColor = PdfColors.black;

                if (total == 0) {
                   statusDict = "NO FEE";
                   statusColor = PdfColors.grey;
                } else if (balance <= 0) {
                   statusDict = "PAID";
                   statusColor = PdfColors.green;
                } else if (pending > 0) {
                   statusDict = "VERIFYING";
                   statusColor = PdfColors.orange;
                } else {
                   statusDict = "DUE";
                   statusColor = PdfColors.red;
                }

                return [
                  s['regNo'] ?? '-',
                  s['name'] ?? 'Unknown',
                  s['batch'] ?? '-',
                  total.toStringAsFixed(0),
                  verified.toStringAsFixed(0),
                  pending > 0 ? pending.toStringAsFixed(0) : '-',
                  balance.toStringAsFixed(0),
                  pw.Text(statusDict, style: pw.TextStyle(color: statusColor, fontWeight: pw.FontWeight.bold)),
                ];
              }).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {
                1: pw.Alignment.centerLeft, // Name left aligned
              },
            ),
          ]; // End of children
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fee-Report-${dept.replaceAll(' ', '')}-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
