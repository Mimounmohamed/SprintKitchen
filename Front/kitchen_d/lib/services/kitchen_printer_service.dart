import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kds_screen.dart';

class KitchenPrinterService {
  static const String _keyPrinterName = 'kds_kitchen_printer';

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static Future<String?> getSavedPrinter() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyPrinterName);
  }

  static Future<void> savePrinter(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyPrinterName, name);
  }

  static Future<Printer?> getActivePrinter() async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return null;

      final saved = await getSavedPrinter();
      if (saved != null && saved.isNotEmpty) {
        for (final p in printers) {
          if (p.name.trim().toLowerCase() == saved.trim().toLowerCase()) {
            return p;
          }
        }
      }

      for (final p in printers) {
        if (p.isDefault) return p;
      }
      return printers.first;
    } catch (_) {
      return null;
    }
  }

  /// Builds the kitchen slip PDF strictly WITHOUT PRICES.
  static Future<Uint8List> buildKitchenSlipPdf(KitchenOrder order) async {
    final doc = pw.Document();

    String modeLabel = 'SUR PLACE';
    if (order.mode == OrderMode.emporter) modeLabel = 'À EMPORTER';
    if (order.mode == OrderMode.livraison) modeLabel = 'LIVRAISON';

    String? table = order.tableNumber;
    if (table != null) {
      table = table.replaceAll(RegExp(r'^(?:table|buzzer\s*#?)\s*', caseSensitive: false), '').trim();
    }

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          72 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3.5 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Top Kitchen Banner ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '*** BON DE CUISINE ***',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // ── Huge Ticket Number ──
              pw.Center(
                child: pw.Text(
                  order.ticketNumber,
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 2),

              // Mode & Table
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1.2),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      modeLabel,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  if (table != null && table.isNotEmpty) ...[
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'TABLE $table',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  'Heure : ${_fmtDate(order.createdAt)}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              if (order.clientName != null && order.clientName!.trim().isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Client : ${order.clientName!.trim()}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              // ── Notes Alert ──
              if (order.comment != null && order.comment!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NOTE CUISINE :',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        order.comment!.trim(),
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Modifications Alert ──
              if (order.isEdited && order.modificationSummary.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '[ ! ] ATTENTION : COMMANDE MODIFIÉE',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      for (final m in order.modificationSummary)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(
                            m.details != null && m.details!.isNotEmpty
                                ? '- ${m.text} (${m.details})'
                                : '- ${m.text}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Column(
                children: [
                  pw.Container(height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 1.5),
                  pw.Container(height: 1, color: PdfColors.black),
                ],
              ),
              pw.SizedBox(height: 5),

              pw.Text(
                'ARTICLES À PRÉPARER :',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
              ),
              pw.SizedBox(height: 4),

              // ── Items (WITHOUT PRICES) ──
              for (final it in order.items) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Large Quantity and Item Name
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.black,
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            child: pw.Text(
                              '${it.quantity}x',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              it.name.toUpperCase(),
                              style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      // Customizations / Sauces
                      if (it.customizations.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        for (final c in it.customizations)
                          if (c.selectedOptions.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 32, bottom: 1),
                              child: pw.Text(
                                '+ ${c.selectedOptions.join(", ")}',
                                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                      ],

                      // Removed ingredients
                      if (it.removedIngredients.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        for (final rem in it.removedIngredients)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 32, bottom: 1),
                            child: pw.Text(
                              '[ SANS : ${rem.replaceFirst(RegExp(r"^sans\s+", caseSensitive: false), "").toUpperCase()} ]',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                      ],

                      // Item Note
                      if (it.notes != null && it.notes!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 32),
                          child: pw.Text(
                            'Note : "${it.notes!.trim()}"',
                            style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              pw.Column(
                children: [
                  pw.Container(height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 1.5),
                  pw.Container(height: 1, color: PdfColors.black),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '*** FIN DU BON CUISINE - ${order.ticketNumber} ***',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Prints kitchen slip directly to the printer without approval dialog.
  static Future<bool> directPrintKitchenSlip(KitchenOrder order) async {
    try {
      final pdfBytes = await buildKitchenSlipPdf(order);
      final printer = await getActivePrinter();

      if (printer != null) {
        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => pdfBytes,
          name: 'Bon_Cuisine_${order.ticketNumber}',
        );
      } else {
        return await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
          name: 'Bon_Cuisine_${order.ticketNumber}',
        );
      }
    } catch (_) {
      final pdfBytes = await buildKitchenSlipPdf(order);
      return await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Bon_Cuisine_${order.ticketNumber}',
      );
    }
  }
}
