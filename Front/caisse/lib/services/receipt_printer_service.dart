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
    required this.subtotalHT,
    this.tvaRate = 10.0,
    required this.tvaAmount,
    required this.totalTTC,
    this.paymentMethod,
    this.amountReceived,
    this.change,
    this.isEdited = false,
    this.modifications = const [],
    this.storeName = 'SPRINTKITCHEN',
    this.storeSubtitle = 'RESTAURANT & FAST-FOOD',
    this.storeAddress = '14 Rue de la République, 75001 Paris',
    this.storePhone = '01 23 45 67 89',
    this.storeSiret = 'SIRET 894 123 456 00012 • TVA FR 12 894123456',
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
            opts.add('${opt.label} (+${opt.priceModifier.toStringAsFixed(2)} €)');
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
            opts.add('${opt.label} (+${opt.priceModifier.toStringAsFixed(2)} €)');
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
    final subHT = total / 1.10;
    final tva = total - subHT;

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

  static String _euro(num val) => '${val.toStringAsFixed(2).replaceAll('.', ',')} €';

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
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    data.storeName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),
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
              if (data.serverName != null && data.serverName!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Opérateur : ${data.serverName}',
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                ),
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
                    child: pw.Text('• $opt', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800)),
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
                  pw.Text('Sous-total H.T. :', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_euro(data.subtotalHT), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('T.V.A. (${data.tvaRate.toStringAsFixed(0)}%) :', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_euro(data.tvaAmount), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 3),
              _dividerSolid(width: 1.2),
              pw.SizedBox(height: 3),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL T.T.C.', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
              pw.SizedBox(height: 6),

              // Barcode
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: data.ticketNumber.replaceAll('#', ''),
                  width: 110,
                  height: 28,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('SprintKitchen POS System', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
              ),
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

              // ── Huge Ticket Number & Table ──
              pw.Center(
                child: pw.Text(
                  data.ticketNumber,
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 2),

              // Mode + Table badge
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
                  'Heure : ${_fmtDate(data.dateTime)}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
              if (data.clientName != null && data.clientName!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    'Client : ${data.clientName}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),

              // ── General Order / Kitchen Notes Alert ──
              if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
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
                        data.notes!.trim(),
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
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
                      pw.Row(
                        children: [
                          pw.Text(
                            '⚠️ ATTENTION : COMMANDE MODIFIÉE',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      for (final m in data.modifications)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Text(
                            '• $m',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              _dividerDouble(),
              pw.SizedBox(height: 5),

              // ── Section Title: Articles ──
              pw.Text(
                'ARTICLES À PRÉPARER :',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
              ),
              pw.SizedBox(height: 4),

              // ── Items to Prepare (STRICTLY WITHOUT PRICES) ──
              for (final it in data.items) ...[
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

                      // Options & Sauces (WITHOUT PRICES)
                      if (it.options.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        for (final opt in it.options)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 32, bottom: 1),
                            child: pw.Text(
                              '👉 ${opt.replaceAll(RegExp(r'\s*\(\+?[0-9]+(?:[\.,][0-9]+)?\s*€\)', caseSensitive: false), '').trim()}',
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                      ],

                      // Removed ingredients (Highlighted with alert symbol)
                      if (it.removed.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        for (final rem in it.removed)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 32, bottom: 1),
                            child: pw.Text(
                              '⛔ SANS : ${rem.replaceFirst(RegExp(r'^sans\s+', caseSensitive: false), "").toUpperCase()}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                      ],

                      // Item Note
                      if (it.notes != null && it.notes!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 32),
                          child: pw.Text(
                            '📝 Note : "${it.notes!.trim()}"',
                            style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              _dividerDouble(),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '*** FIN DU BON CUISINE - ${data.ticketNumber} ***',
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

  static pw.Widget _dividerDouble() {
    return pw.Column(
      children: [
        pw.Container(height: 1, color: PdfColors.black),
        pw.SizedBox(height: 1.5),
        pw.Container(height: 1, color: PdfColors.black),
      ],
    );
  }
}
