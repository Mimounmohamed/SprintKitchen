import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/receipt_printer_service.dart';
import '../theme/app_colors.dart';

/// Interactive modal allowing the user to preview both the Client Receipt and Kitchen Slip,
/// and print either directly to the connected printer without compulsory preview next time.
class ReceiptPreviewDialog extends StatefulWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.data,
    this.initialShowKitchen = false,
  });

  final PrintableReceiptData data;
  final bool initialShowKitchen;

  /// Helper to open the dialog.
  static Future<void> show(
    BuildContext context,
    PrintableReceiptData data, {
    bool initialShowKitchen = false,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ReceiptPreviewDialog(
        data: data,
        initialShowKitchen: initialShowKitchen,
      ),
    );
  }

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  late bool _showKitchen;
  bool _printing = false;
  String? _activePrinterName;

  @override
  void initState() {
    super.initState();
    _showKitchen = widget.initialShowKitchen;
    _loadActivePrinter();
  }

  Future<void> _loadActivePrinter() async {
    final p = await ReceiptPrinterService.getActivePrinter(isKitchen: _showKitchen);
    if (mounted && p != null) {
      setState(() => _activePrinterName = p.name);
    }
  }

  Future<void> _directPrint() async {
    setState(() => _printing = true);
    try {
      bool success = false;
      if (_showKitchen) {
        success = await ReceiptPrinterService.printKitchenReceiptDirect(widget.data);
      } else {
        success = await ReceiptPrinterService.printClientReceiptDirect(widget.data);
      }

      if (!mounted) return;
      setState(() => _printing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                    ? (_showKitchen
                        ? 'Bon cuisine envoyé à l\'imprimante.'
                        : 'Ticket client envoyé à l\'imprimante.')
                    : 'Impression lancée.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _printing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'impression : $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showPrinterPicker() async {
    final printers = await Printing.listPrinters();
    if (!mounted) return;

    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune imprimante détectée sur ce poste.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final selected = await showDialog<Printer>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.print_outlined, color: AppColors.brandDark),
            SizedBox(width: 8),
            Text('Choisir une imprimante', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionnez l\'imprimante par défaut pour ce poste :',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              for (final p in printers)
                ListTile(
                  leading: Icon(
                    Icons.print,
                    color: p.name == _activePrinterName ? AppColors.brandDark : Colors.grey,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: p.name == _activePrinterName ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: p.isDefault ? const Text('Imprimante par défaut du système') : null,
                  trailing: p.name == _activePrinterName
                      ? const Icon(Icons.check_circle, color: Color(0xFF059669))
                      : null,
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      if (_showKitchen) {
        await ReceiptPrinterService.saveKitchenPrinter(selected.name);
      } else {
        await ReceiptPrinterService.saveClientPrinter(selected.name);
      }
      setState(() => _activePrinterName = selected.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width > 900 ? 750.0 : size.width * 0.95;
    final height = size.height > 850 ? 780.0 : size.height * 0.92;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Top Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(bottom: BorderSide(color: Color(0xFF333333))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APERÇU TICKET — ${widget.data.ticketNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _activePrinterName != null
                              ? 'Imprimante connectée : $_activePrinterName'
                              : 'Imprimante système par défaut',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Printer config icon
                  IconButton(
                    onPressed: _showPrinterPicker,
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                    tooltip: 'Sélectionner l\'imprimante',
                  ),
                  const SizedBox(width: 4),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),

            // ── Mode Switch Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF3F4F6),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _showKitchen = false);
                        _loadActivePrinter();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_showKitchen ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: !_showKitchen
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 17,
                              color: !_showKitchen ? AppColors.brandDark : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TICKET CLIENT (avec prix & détails)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: !_showKitchen ? FontWeight.w800 : FontWeight.w600,
                                color: !_showKitchen ? AppColors.brandDark : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _showKitchen = true);
                        _loadActivePrinter();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _showKitchen ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _showKitchen
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 17,
                              color: _showKitchen ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'BON CUISINE (sans prix)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _showKitchen ? FontWeight.w800 : FontWeight.w600,
                                color: _showKitchen ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── PDF Interactive Preview ──
            Expanded(
              child: PdfPreview(
                key: ValueKey(_showKitchen),
                build: (format) => _showKitchen
                    ? ReceiptPrinterService.buildKitchenReceiptPdf(widget.data)
                    : ReceiptPrinterService.buildClientReceiptPdf(widget.data),
                allowPrinting: false, // We use our own direct print buttons
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                previewPageMargin: const EdgeInsets.all(16),
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: AppColors.brandDark),
                ),
                onError: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.print_disabled_outlined, size: 40, color: Color(0xFFDC2626)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aperçu visuel non disponible dans ce navigateur',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Le ticket est prêt. Vous pouvez l\'imprimer directement sur votre imprimante de caisse.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _directPrint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Lancer l\'impression directe', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Bottom Action Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  // Print with system dialog (optional)
                  TextButton.icon(
                    onPressed: () {
                      if (_showKitchen) {
                        Printing.layoutPdf(
                          onLayout: (format) => ReceiptPrinterService.buildKitchenReceiptPdf(widget.data),
                          name: 'Bon_Cuisine_${widget.data.ticketNumber}',
                        );
                      } else {
                        Printing.layoutPdf(
                          onLayout: (format) => ReceiptPrinterService.buildClientReceiptPdf(widget.data),
                          name: 'Ticket_Client_${widget.data.ticketNumber}',
                        );
                      }
                    },
                    icon: const Icon(Icons.tune, size: 16, color: Color(0xFF6B7280)),
                    label: const Text(
                      'Autre imprimante…',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Direct print button (no approval dialog)
                  ElevatedButton.icon(
                    onPressed: _printing ? null : _directPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showKitchen ? const Color(0xFFDC2626) : AppColors.brandDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _printing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print, size: 18),
                    label: Text(
                      _showKitchen ? 'IMPRIMER BON CUISINE DIRECT' : 'IMPRIMER TICKET DIRECT',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
