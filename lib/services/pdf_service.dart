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
}
