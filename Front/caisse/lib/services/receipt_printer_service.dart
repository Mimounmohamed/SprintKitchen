import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_models.dart';
import '../models/pos_models.dart';

/// Unified model representing receipt data for both Client receipt and Kitchen slip.
class PrintableReceiptData {
  const PrintableReceiptData({
    required this.ticketNumber,
    required this.dateTime,
    required this.orderType,
    this.tableNumber,
    this.clientName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.serverName,
    this.notes,
    required this.items,
    this.subtotalHT = 0.0,
    this.tvaRate = 0.0,
    this.tvaAmount = 0.0,
    required this.totalTTC,
    this.paymentMethod,
    this.amountReceived,
    this.change,
    this.isEdited = false,
    this.modifications = const [],
    this.prepDuration,
    this.finishedTimeString,
    this.storeName = "BOBO'S",
    this.storeSubtitle = 'RESTAURANT & FAST-FOOD',
    this.storeAddress = '14 Rue de la République, 75001 Paris',
    this.storePhone = '01 23 45 67 89',
    this.storeSiret = 'SIRET 894 123 456 00012',
    this.footerMessage = 'Merci de votre visite et à très bientôt !',
  });

  final String ticketNumber;
  final DateTime dateTime;
  final String orderType; // 'sur_place', 'a_emporter', 'livraison'
  final String? tableNumber;
  final String? clientName;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? serverName;
  final String? notes;
  final List<PrintableItem> items;
  final double subtotalHT;
  final double tvaRate;
  final double tvaAmount;
  final double totalTTC;
  final String? paymentMethod;
  final double? amountReceived;
  final double? change;
  final bool isEdited;
  final List<String> modifications;
  final String? prepDuration;
  final String? finishedTimeString;
  final String storeName;
  final String storeSubtitle;
  final String storeAddress;
  final String storePhone;
  final String storeSiret;
  final String footerMessage;

  String get orderTypeLabel {
    switch (orderType.toLowerCase()) {
      case 'a_emporter':
        return 'À EMPORTER';
      case 'livraison':
        return 'LIVRAISON';
      default:
        return 'SUR PLACE';
    }
  }

  /// Construct from past order in History.
  factory PrintableReceiptData.fromHistoryOrder(
    HistoryOrder o, {
    String? paymentMethod,
    double? amountReceived,
    double? change,
    String? serverName,
  }) {
    String? rawTable = o.tableNumber ?? o.buzzerNumber;
    if (rawTable != null) {
      rawTable = rawTable
          .replaceAll(RegExp(r'^(?:table|buzzer\s*#?)\s*', caseSensitive: false), '')
          .trim();
    }

    final printableItems = o.lines.map((l) {
      final opts = <String>[];
      for (final c in l.customizations) {
        for (final opt in c.selectedOptions) {
          if (opt.priceModifier > 0) {
            opts.add('${opt.label} (+${opt.priceModifier.toStringAsFixed(2)} DA)');
          } else {
            opts.add(opt.label);
          }
        }
      }
      if (opts.isEmpty && l.options.isNotEmpty) {
        opts.addAll(l.options);
      }

      return PrintableItem(
        name: l.name,
        quantity: l.quantity,
        unitPrice: l.unitPrice ?? (l.quantity > 0 ? (l.lineTotal / l.quantity) : l.lineTotal),
        lineTotal: l.lineTotal,
        options: opts,
        removed: l.removed,
        notes: l.notes,
      );
    }).toList();

    final mods = o.modificationSummary.map((m) {
      if (m.details != null && m.details!.isNotEmpty) {
        return '${m.text} (${m.details})';
      }
      return m.text;
    }).toList();

    return PrintableReceiptData(
      ticketNumber: o.ticketNumber.startsWith('#') ? o.ticketNumber : '#${o.ticketNumber}',
      dateTime: o.createdAt,
      orderType: o.orderType,
      tableNumber: rawTable != null && rawTable.isNotEmpty ? rawTable : null,
      clientName: o.clientName ?? o.deliveryName,
      deliveryAddress: o.deliveryAddress,
      deliveryPhone: o.deliveryPhone,
      serverName: serverName ?? o.registerName ?? 'Caisse Principale',
      notes: o.notes,
      items: printableItems,
      subtotalHT: o.subtotalHT,
      tvaAmount: o.tvaAmount,
      totalTTC: o.totalTTC,
      paymentMethod: paymentMethod,
      amountReceived: amountReceived,
      change: change,
      isEdited: o.isEdited,
      modifications: mods,
      prepDuration: o.prepDurationString,
      finishedTimeString: o.finishedTimeString,
    );
  }

  /// Construct from active POS ticket after checkout.
  factory PrintableReceiptData.fromPosTicket({
    required String ticketNumber,
    required List<TicketLine> lines,
    required OrderType orderType,
    String? tableNumber,
    String? clientName,
    String? deliveryAddress,
    String? deliveryPhone,
    String? notes,
    String? paymentMethod,
    double? amountReceived,
    double? change,
    String? serverName,
    bool isEdited = false,
    List<String> modifications = const [],
  }) {
    final printableItems = lines.map((l) {
      final opts = <String>[];
      for (final c in l.customizations) {
        for (final opt in c.selectedOptions) {
          if (opt.priceModifier > 0) {
            opts.add('${opt.label} (+${opt.priceModifier.toStringAsFixed(2)} DA)');
          } else {
            opts.add(opt.label);
          }
        }
      }

      return PrintableItem(
        name: l.name,
        quantity: l.quantity,
        unitPrice: l.unitPrice + l.extrasTotal,
        lineTotal: l.total,
        options: opts,
        removed: l.removedIngredients,
        notes: l.notes,
      );
    }).toList();

    final total = lines.fold<double>(0.0, (sum, it) => sum + it.total);
    final subHT = total;
    final tva = 0.0;

    String typeStr = 'sur_place';
    if (orderType == OrderType.takeaway) typeStr = 'a_emporter';
    if (orderType == OrderType.delivery) typeStr = 'livraison';

    return PrintableReceiptData(
      ticketNumber: ticketNumber.startsWith('#') ? ticketNumber : '#$ticketNumber',
      dateTime: DateTime.now(),
      orderType: typeStr,
      tableNumber: tableNumber,
      clientName: clientName,
      deliveryAddress: deliveryAddress,
      deliveryPhone: deliveryPhone,
      serverName: serverName ?? 'Caisse Principale',
      notes: notes,
      items: printableItems,
      subtotalHT: subHT,
      tvaAmount: tva,
      totalTTC: total,
      paymentMethod: paymentMethod,
      amountReceived: amountReceived,
      change: change,
      isEdited: isEdited,
      modifications: modifications,
    );
  }
}

class PrintableItem {
  const PrintableItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.options = const [],
    this.removed = const [],
    this.notes,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<String> options;
  final List<String> removed;
  final String? notes;
}

/// Service managing direct printing, layout generation, and printer selection.
class ReceiptPrinterService {
  static const String _keySelectedPrinter = 'sp_selected_printer';
  static const String _keyKitchenPrinter = 'sp_kitchen_printer';

  static const String _boboLogoBase64 =
      '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';

  static String _euro(num val) => '${val.toStringAsFixed(2).replaceAll('.', ',')} DA';

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // ────────────────────────── Preferences ──────────────────────────

  static Future<String?> getSavedClientPrinter() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keySelectedPrinter);
  }

  static Future<void> saveClientPrinter(String printerName) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keySelectedPrinter, printerName);
  }

  static Future<String?> getSavedKitchenPrinter() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyKitchenPrinter);
  }

  static Future<void> saveKitchenPrinter(String printerName) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyKitchenPrinter, printerName);
  }

  static Future<Printer?> getActivePrinter({bool isKitchen = false}) async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return null;

      final saved = isKitchen ? await getSavedKitchenPrinter() : await getSavedClientPrinter();
      if (saved != null && saved.isNotEmpty) {
        for (final p in printers) {
          if (p.name.trim().toLowerCase() == saved.trim().toLowerCase()) {
            return p;
          }
        }
      }

      // Default system printer fallback
      for (final p in printers) {
        if (p.isDefault) return p;
      }
      return printers.first;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────── PDF Layout: Client Receipt ──────────────────────────

  /// Generates the standard 80mm thermal receipt for the customer with all details, prices, and branding.
  static Future<Uint8List> buildClientReceiptPdf(PrintableReceiptData data) async {
    final doc = pw.Document();

    final logoImage = pw.MemoryImage(base64Decode(_boboLogoBase64));

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
              // ── Header Logo / Emblem ──
              pw.Center(
                child: pw.Image(
                  logoImage,
                  width: 22 * PdfPageFormat.mm,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  data.storeSubtitle,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  data.storeAddress,
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tél : ${data.storePhone}',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  data.storeSiret,
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 5),

              _dividerDashed(),
              pw.SizedBox(height: 4),

              // ── Ticket Identification ──
              pw.Center(
                child: pw.Text(
                  'TICKET ${data.ticketNumber}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  _fmtDate(data.dateTime),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              if (data.prepDuration != null) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Préparé en ${data.prepDuration}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
                ),
              ],
              pw.SizedBox(height: 4),

              // Mode & Table Box
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      data.orderTypeLabel,
                      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                    if (data.tableNumber != null && data.tableNumber!.isNotEmpty)
                      pw.Text(
                        'TABLE ${data.tableNumber}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      )
                    else if (data.clientName != null && data.clientName!.isNotEmpty)
                      pw.Text(
                        data.clientName!,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                  ],
                ),
              ),

              if (data.deliveryAddress != null && data.deliveryAddress!.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  'Livraison : ${data.deliveryAddress}',
                  style: const pw.TextStyle(fontSize: 7.5),
                ),
                if (data.deliveryPhone != null && data.deliveryPhone!.isNotEmpty)
                  pw.Text(
                    'Tél client : ${data.deliveryPhone}',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
              ],

              pw.SizedBox(height: 4),
              _dividerDashed(),
              pw.SizedBox(height: 4),

              // ── Articles Table Header ──
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 22,
                    child: pw.Text('QTÉ', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Text('DÉSIGNATION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(
                    width: 38,
                    child: pw.Text('P.U.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                  pw.SizedBox(
                    width: 44,
                    child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              _dividerDotted(),
              pw.SizedBox(height: 3),

              // ── Articles List ──
              for (final it in data.items) ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 22,
                      child: pw.Text('${it.quantity}×', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      child: pw.Text(it.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(
                      width: 38,
                      child: pw.Text(_euro(it.unitPrice), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                    ),
                    pw.SizedBox(
                      width: 44,
                      child: pw.Text(_euro(it.lineTotal), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                // Options sublines
                for (final opt in it.options)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 22, top: 1),
                    child: pw.Text('+ $opt', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                  ),
                // Removed ingredients
                for (final rem in it.removed)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 22, top: 1),
                    child: pw.Text('x $rem', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ),
                // Item note
                if (it.notes != null && it.notes!.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 22, top: 1),
                    child: pw.Text('Note: "${it.notes!.trim()}"', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
                  ),
                pw.SizedBox(height: 3),
              ],

              _dividerDashed(),
              pw.SizedBox(height: 4),

              // ── Financial Summary ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL :', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_euro(data.totalTTC), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 3),
              _dividerSolid(width: 1.2),
              pw.SizedBox(height: 4),

              // ── Payment Details ──
              if (data.paymentMethod != null && data.paymentMethod!.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Règlement :', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(data.paymentMethod!, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                if (data.amountReceived != null && data.amountReceived! > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Montant Reçu :', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(_euro(data.amountReceived!), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
                if (data.change != null && data.change! > 0) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Rendu Monnaie :', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(_euro(data.change!), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 4),
                _dividerDotted(),
                pw.SizedBox(height: 4),
              ],

              // ── Footer ──
              pw.Center(
                child: pw.Text(
                  data.footerMessage,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Conservez ce ticket comme justificatif d\'achat',
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ────────────────────────── PDF Layout: Kitchen Ticket (WITHOUT PRICES) ──────────────────────────

  /// Generates the special kitchen production slip strictly WITHOUT PRICES, with large quantities, options, and modifications.
  static Future<Uint8List> buildKitchenReceiptPdf(PrintableReceiptData data) async {
    final doc = pw.Document();

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
              // ── Kitchen Header ──
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.black,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'BON DE CUISINE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // ── Ticket Number & Table ──
              pw.Center(
                child: pw.Text(
                  data.ticketNumber,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),

              // Mode + Table badge
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 1.0),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Text(
                      data.orderTypeLabel,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  if (data.tableNumber != null && data.tableNumber!.isNotEmpty) ...[
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.black,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'TABLE ${data.tableNumber}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
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
                  'Heure : ${_fmtDate(data.dateTime)}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              if (data.finishedTimeString != null || data.prepDuration != null) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Fin : ${data.finishedTimeString ?? "—"}${data.prepDuration != null ? " • Durée : ${data.prepDuration}" : ""}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
              if (data.clientName != null && data.clientName!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Client : ${data.clientName}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              // ── General Order / Kitchen Notes Alert ──
              if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.black, width: 1.0),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NOTE CUISINE :',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        data.notes!.trim(),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Modifications Alert Box (if order was modified) ──
              if (data.isEdited && data.modifications.isNotEmpty) ...[
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
                        '[ ! ] COMMANDE MODIFIÉE',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      for (final m in data.modifications)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(
                            '- $m',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              _dividerSolid(),
              pw.SizedBox(height: 4),

              // ── Section Title: Articles ──
              pw.Text(
                'ARTICLES À PRÉPARER :',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4),
              ),
              pw.SizedBox(height: 5),

              // ── Items to Prepare (STRICTLY WITHOUT PRICES) ──
              for (final it in data.items) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Quantity badge and Item Name
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
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              it.name.toUpperCase(),
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      // Options & Sauces (WITHOUT PRICES)
                      if (it.options.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        for (final opt in it.options)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 30, bottom: 1),
                            child: pw.Text(
                              '+ ${opt.replaceAll(RegExp(r'\s*\(\+?[0-9]+(?:[\.,][0-9]+)?\s*(?:€|DA)\)', caseSensitive: false), '').trim()}',
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                      ],

                      // Removed ingredients
                      if (it.removed.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        for (final rem in it.removed)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 30, bottom: 1),
                            child: pw.Text(
                              '[ SANS : ${rem.replaceFirst(RegExp(r'^sans\s+', caseSensitive: false), "").toUpperCase()} ]',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],

                      // Item Note
                      if (it.notes != null && it.notes!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 30),
                          child: pw.Text(
                            'Note : "${it.notes!.trim()}"',
                            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              _dividerSolid(),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ────────────────────────── Direct Printing Execution ──────────────────────────

  /// Prints silently and directly to the connected/default printer without prompting for user confirmation.
  static Future<bool> directPrintPdf({
    required Uint8List pdfBytes,
    required String jobName,
    bool isKitchen = false,
  }) async {
    try {
      final printer = await getActivePrinter(isKitchen: isKitchen);
      if (printer != null) {
        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => pdfBytes,
          name: jobName,
        );
      } else {
        // Fall back to layout dialog if no printer found
        return await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
          name: jobName,
        );
      }
    } catch (e) {
      // In case direct printing is unsupported on current device, fall back to layoutPdf
      return await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: jobName,
      );
    }
  }

  /// Print client receipt directly without dialog.
  static Future<bool> printClientReceiptDirect(PrintableReceiptData data) async {
    final pdfBytes = await buildClientReceiptPdf(data);
    return await directPrintPdf(
      pdfBytes: pdfBytes,
      jobName: 'Ticket_Client_${data.ticketNumber}',
      isKitchen: false,
    );
  }

  /// Print kitchen receipt directly without dialog.
  static Future<bool> printKitchenReceiptDirect(PrintableReceiptData data) async {
    final pdfBytes = await buildKitchenReceiptPdf(data);
    return await directPrintPdf(
      pdfBytes: pdfBytes,
      jobName: 'Bon_Cuisine_${data.ticketNumber}',
      isKitchen: true,
    );
  }

  // ────────────────────────── Divider Helpers ──────────────────────────

  static pw.Widget _dividerSolid({double width = 0.8}) {
    return pw.Container(
      height: width,
      color: PdfColors.black,
    );
  }

  static pw.Widget _dividerDashed() {
    return pw.Text(
      '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      maxLines: 1,
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
    );
  }

  static pw.Widget _dividerDotted() {
    return pw.Text(
      '................................................................',
      maxLines: 1,
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
    );
  }
}
