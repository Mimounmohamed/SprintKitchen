import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../kds_screen.dart';
import '../services/kitchen_printer_service.dart';

class KitchenReceiptPreviewDialog extends StatefulWidget {
  const KitchenReceiptPreviewDialog({super.key, required this.order});

  final KitchenOrder order;

  static Future<void> show(BuildContext context, KitchenOrder order) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => KitchenReceiptPreviewDialog(order: order),
    );
  }

  @override
  State<KitchenReceiptPreviewDialog> createState() => _KitchenReceiptPreviewDialogState();
}

class _KitchenReceiptPreviewDialogState extends State<KitchenReceiptPreviewDialog> {
  bool _printing = false;
  String? _printerName;

  @override
  void initState() {
    super.initState();
    _loadPrinter();
  }

  Future<void> _loadPrinter() async {
    final p = await KitchenPrinterService.getActivePrinter();
    if (mounted && p != null) {
      setState(() => _printerName = p.name);
    }
  }

  Future<void> _printDirect() async {
    setState(() => _printing = true);
    try {
      final ok = await KitchenPrinterService.directPrintKitchenSlip(widget.order);
      if (!mounted) return;
      setState(() => _printing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Bon cuisine envoyé à l\'imprimante.' : 'Impression lancée.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _printing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'impression : $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width > 800 ? 680.0 : size.width * 0.95;
    final height = size.height > 850 ? 750.0 : size.height * 0.92;

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
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFF1F2937),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/bobo_portrait.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BON CUISINE — ${widget.order.ticketNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _printerName != null ? 'Imprimante : $_printerName' : 'Imprimante par défaut',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Preview
            Expanded(
              child: PdfPreview(
                build: (format) => KitchenPrinterService.buildKitchenSlipPdf(widget.order),
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                previewPageMargin: const EdgeInsets.all(16),
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1F2937)),
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
                            'Le document est prêt. Vous pouvez l\'imprimer directement sur votre imprimante.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _printDirect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
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

            // Footer actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Printing.layoutPdf(
                        onLayout: (format) => KitchenPrinterService.buildKitchenSlipPdf(widget.order),
                        name: 'Bon_Cuisine_${widget.order.ticketNumber}',
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16, color: Color(0xFF6B7280)),
                    label: const Text(
                      'Autre imprimante…',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _printing ? null : _printDirect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
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
                    label: const Text(
                      'IMPRIMER DIRECT',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
