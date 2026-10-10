import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'kitchen_order_details_dialog.dart';

/* ─── Config ─────────────────────────────────────────────── */
const String _kBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue:
      'https://sprintkitchen-backend-api-dxedcmdth6avgha4.francecentral-01.azurewebsites.net/api',
);

/* ─── Colors ─────────────────────────────────────────────── */
class C {
  static const bg        = Color(0xFFF3F2EF);
  static const cardBg    = Colors.white;
  static const ink       = Color(0xFF1A1714);
  static const brown     = Color(0xFF2E1F0F);
  static const yellow    = Color(0xFFF2B705);
  static const muted     = Color(0xFF8B8378);
  static const border    = Color(0xFFE2DFD8);
  static const green     = Color(0xFF22A45D);
  static const greenBg   = Color(0xFFE8F8EF);
  static const greenText = Color(0xFF1A7A45);
  static const teal      = Color(0xFF16A085);
  static const orange    = Color(0xFFE08E0B);
  static const orangeBg  = Color(0xFFFDF3DC);
  static const red       = Color(0xFFD93025);
  static const redBg     = Color(0xFFFBEAE7);
  static const gray      = Color(0xFF9A948A);
}

/* ─── Responsive helper ──────────────────────────────────── */
class R {
  final double w, h;
  const R(this.w, this.h);
  int get cols {
    if (w < 650)  return 2;
    if (w < 950)  return 3;
    if (w < 1300) return 4;
    return 5;
  }
  double get gap  => w < 800 ? 10 : 14;
  double get hPad => w < 800 ? 12 : 18;
  double get cardH {
    final available = h - (hPad * 2) - gap;
    return (available / 2).clamp(220.0, 440.0);
  }
  double get scale => (w / 1280).clamp(0.72, 1.3);
  double fs(double base) => (base * scale).roundToDouble();
}

/* ─── Helpers ────────────────────────────────────────────── */
bool _isToday(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  // Same calendar day
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return true;
  }
  // Within the last 20 hours (covers late-night service crossing midnight)
  if (now.difference(local).inHours < 20 && !local.isAfter(now)) {
    return true;
  }
  return false;
}

/* ─── Models ─────────────────────────────────────────────── */
enum OrderMode   { surPlace, emporter, livraison }
enum OrderStatus { attente, preparation, terminee }
enum Urgency     { normal, warning, critical, ready }

class KdsCustomization {
  final String groupName;
  final List<String> selectedOptions;
  const KdsCustomization({required this.groupName, required this.selectedOptions});
}

class KdsItem {
  final String? id;
  final String qty;
  final String name;
  final List<String> subLines;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? station;
  String? kdsStatus;
  final List<String> ingredients;
  final List<KdsCustomization> customizations;
  final List<String> removedIngredients;
  final String? notes;
  final Map<String, dynamic> rawJson;

  KdsItem({
    this.id,
    required this.qty,
    required this.name,
    this.subLines = const [],
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.lineTotal = 0.0,
    this.station,
    this.kdsStatus,
    this.ingredients = const [],
    this.customizations = const [],
    this.removedIngredients = const [],
    this.notes,
    this.rawJson = const {},
  });

  bool get isReady => kdsStatus == 'ready' || kdsStatus == 'served';

  Map<String, dynamic> toDbJson() {
    final map = Map<String, dynamic>.from(rawJson);
    if (id != null && id!.isNotEmpty) {
      map['_id'] = id;
    }
    map['kdsStatus'] = kdsStatus ?? 'pending';
    if (map['productId'] is Map && (map['productId'] as Map)['_id'] != null) {
      map['productId'] = (map['productId'] as Map)['_id'].toString();
    }
    return map;
  }

  factory KdsItem.fromJson(Map<String, dynamic> j) {
    final String? itemId = j['_id']?.toString();
    final int qtyInt = (j['quantity'] as num?)?.toInt() ?? 1;
    final double uPrice = (j['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final double lTotal = (j['lineTotal'] as num?)?.toDouble() ?? (uPrice * qtyInt);
    final String? station = j['kdsStation']?.toString() ??
        (j['productId'] is Map ? (j['productId'] as Map)['kdsStation']?.toString() : null);
    final String? itemKdsStatus = j['kdsStatus']?.toString();
    final String? itemNotes = (j['notes'] != null && j['notes'].toString().trim().isNotEmpty)
        ? j['notes'].toString().trim()
        : null;

    final parsedCustoms = <KdsCustomization>[];
    final customs = j['customizations'] as List? ?? [];
    for (final c in customs) {
      if (c is Map) {
        final gName = c['groupName']?.toString() ?? '';
        final optsList = <String>[];
        final rawOpts = c['selectedOptions'] as List? ?? [];
        for (final o in rawOpts) {
          if (o is Map) {
            final lbl = o['label']?.toString() ?? '';
            if (lbl.isNotEmpty) optsList.add(lbl);
          } else if (o != null && o.toString().isNotEmpty) {
            optsList.add(o.toString());
          }
        }
        if (optsList.isNotEmpty) {
          parsedCustoms.add(KdsCustomization(groupName: gName, selectedOptions: optsList));
        }
      }
    }

    final removed = <String>[];
    final rawRemoved = j['removedIngredients'] as List? ?? [];
    for (final r in rawRemoved) {
      final s = r?.toString().trim() ?? '';
      if (s.isNotEmpty) {
        removed.add(s);
      }
    }

    final ingredientsList = <String>[];
    if (j['productId'] is Map && (j['productId'] as Map)['ingredients'] is List) {
      for (final ing in (j['productId'] as Map)['ingredients'] as List) {
        if (ing != null && ing.toString().trim().isNotEmpty) {
          ingredientsList.add(ing.toString().trim());
        }
      }
    }

    final subs = <String>[];
    for (final c in parsedCustoms) {
      final opts = c.selectedOptions.join(', ');
      subs.add(c.groupName.isNotEmpty ? '${c.groupName}: $opts' : opts);
    }
    for (final r in removed) {
      subs.add(r.toLowerCase().startsWith('sans') ? r : 'Sans $r');
    }
    if (itemNotes != null && itemNotes.isNotEmpty) {
      subs.add(itemNotes);
    }

    String name = j['productName']?.toString() ?? '';
    if (name.isEmpty && j['productId'] is Map) {
      name = (j['productId'] as Map)['name']?.toString() ?? '';
    }
    if (name.isEmpty) name = '?';

    return KdsItem(
      id: itemId,
      qty: '$qtyInt\u00d7',
      name: name,
      subLines: subs,
      quantity: qtyInt,
      unitPrice: uPrice,
      lineTotal: lTotal,
      station: station,
      kdsStatus: itemKdsStatus,
      ingredients: ingredientsList,
      customizations: parsedCustoms,
      removedIngredients: removed,
      notes: itemNotes,
      rawJson: Map<String, dynamic>.from(j),
    );
  }
}

class OrderModification {
  final String action; // 'deleted', 'added', 'modified', 'table', 'note', 'general'
  final String text;
  final String? details;

  const OrderModification({
    required this.action,
    required this.text,
    this.details,
  });

  factory OrderModification.fromJson(dynamic j) {
    if (j is String) {
      final s = j.trim();
      String act = 'modified';
      if (s.toLowerCase().startsWith('supprim') || s.contains('❌')) {
        act = 'deleted';
      } else if (s.toLowerCase().startsWith('ajout') || s.contains('➕')) {
        act = 'added';
      } else if (s.toLowerCase().startsWith('table')) {
        act = 'table';
      } else if (s.toLowerCase().startsWith('note')) {
        act = 'note';
      }
      return OrderModification(action: act, text: s);
    }
    if (j is Map) {
      return OrderModification(
        action: j['action']?.toString() ?? 'modified',
        text: j['text']?.toString() ?? '',
        details: j['details']?.toString(),
      );
    }
    return const OrderModification(action: 'modified', text: '');
  }
}

class KitchenOrder {
  final String id;
  final String ticketNumber;
  final OrderMode mode;
  final DateTime createdAt;
  final DateTime? kdsSentAt;
  final DateTime? finishedAt;
  final List<KdsItem> items;
  OrderStatus status;
  String? note;
  final String? comment;
  final String? tableNumber;
  final double subtotalHT;
  final double tvaRate;
  final double tvaAmount;
  final double totalTTC;
  final String? clientName;
  final String? registerName;
  final bool isEdited;
  final List<OrderModification> modificationSummary;

  KitchenOrder({
    required this.id,
    required this.ticketNumber,
    required this.mode,
    required this.createdAt,
    this.kdsSentAt,
    this.finishedAt,
    required this.items,
    required this.status,
    this.note,
    this.comment,
    this.tableNumber,
    this.subtotalHT = 0.0,
    this.tvaRate = 0.0,
    this.tvaAmount = 0.0,
    this.totalTTC = 0.0,
    this.clientName,
    this.registerName,
    this.isEdited = false,
    this.modificationSummary = const [],
  });

  Duration? get prepDuration {
    if (finishedAt == null) return null;
    final start = kdsSentAt ?? createdAt;
    final diff = finishedAt!.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  String? get finishedTimeString {
    if (finishedAt == null) return null;
    final dt = finishedAt!.toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String? get prepDurationString {
    final d = prepDuration;
    if (d == null) return null;
    final totalSec = d.inSeconds;
    if (totalSec < 60) return '${totalSec}s';
    final m = d.inMinutes;
    final s = totalSec % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '${h}h ${remM.toString().padLeft(2, '0')}m';
    }
    return s > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '$m min';
  }

  factory KitchenOrder.fromJson(Map<String, dynamic> j) {
    final rawMode = j['orderType'] as String? ?? 'sur_place';
    OrderMode mode;
    switch (rawMode) {
      case 'a_emporter': mode = OrderMode.emporter;  break;
      case 'livraison':  mode = OrderMode.livraison; break;
      default:           mode = OrderMode.surPlace;
    }

    final rawKds = j['kdsStatus'] as String? ?? 'pending';
    final rawStatus = j['status'] as String? ?? '';
    OrderStatus status;
    String? note;

    if (rawStatus == 'terminee' || rawKds == 'served') {
      status = OrderStatus.terminee;
      note   = 'TERMIN\u00c9';
    } else if (rawKds == 'in_progress') {
      status = OrderStatus.preparation;
    } else if (rawKds == 'ready' || rawStatus == 'a_encaisser') {
      status = OrderStatus.terminee;
      note   = 'PR\u00caT';
    } else {
      status = OrderStatus.attente;
    }

    final items = (j['items'] as List? ?? [])
        .map((i) => KdsItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final ts = j['kdsSentAt'] ?? j['createdAt'];
    final rawSent = j['kdsSentAt'];
    final DateTime? kdsSentAt = rawSent != null ? DateTime.tryParse(rawSent.toString()) : null;

    final rawReady = j['kdsReadyAt'] ??
        j['completedAt'] ??
        (rawStatus == 'terminee' ||
                rawStatus == 'a_encaisser' ||
                rawKds == 'served' ||
                rawKds == 'ready'
            ? j['updatedAt']
            : null);
    final DateTime? finishedAt = rawReady != null ? DateTime.tryParse(rawReady.toString()) : null;

    final rawTicket = j['ticketNumber']?.toString() ?? '?';
    final ticketNumber = rawTicket.startsWith('#') ? rawTicket : '#$rawTicket';

    final rawComment = j['notes'] ?? j['comment'] ?? j['orderNotes'];
    final comment = rawComment?.toString().trim();

    String? table = j['tableNumber']?.toString().trim();
    if (table == null || table.isEmpty) {
      final buzzer = j['buzzerNumber']?.toString().trim() ?? '';
      final match = RegExp(r'^(?:table|buzzer\s*#?)\s*(.+)$', caseSensitive: false).firstMatch(buzzer);
      if (match != null) {
        table = match.group(1)?.trim();
      } else if (buzzer.isNotEmpty) {
        table = buzzer;
      }
    }

    final double computedTotal =
        items.fold<double>(0.0, (sum, it) => sum + it.lineTotal);
    final double totalTTC =
        (j['totalTTC'] as num?)?.toDouble() ?? computedTotal;
    final double tvaRate = (j['tvaRate'] as num?)?.toDouble() ?? 0.0;
    final double tvaAmount = (j['tvaAmount'] as num?)?.toDouble() ?? 0.0;
    final double subtotalHT = (j['subtotalHT'] as num?)?.toDouble() ?? totalTTC;
    final clientName = j['clientName']?.toString();
    final registerName = j['registerId'] is Map
        ? (j['registerId'] as Map)['name']?.toString()
        : null;

    return KitchenOrder(
      id:           j['_id']?.toString() ?? '',
      ticketNumber: ticketNumber,
      mode:         mode,
      createdAt:    ts != null
          ? DateTime.tryParse(ts as String) ?? DateTime.now()
          : DateTime.now(),
      kdsSentAt:    kdsSentAt,
      finishedAt:   finishedAt,
      items:        items,
      status:       status,
      note:         note,
      comment:      (comment != null && comment.isNotEmpty) ? comment : null,
      tableNumber:  (table != null && table.isNotEmpty) ? table : null,
      subtotalHT:   subtotalHT,
      tvaRate:      tvaRate,
      tvaAmount:    tvaAmount,
      totalTTC:     totalTTC,
      clientName:   (clientName != null && clientName.isNotEmpty) ? clientName : null,
      registerName: (registerName != null && registerName.isNotEmpty) ? registerName : null,
      isEdited:     j['isEdited'] == true || (j['modificationSummary'] is List && (j['modificationSummary'] as List).isNotEmpty),
      modificationSummary: (j['modificationSummary'] as List<dynamic>? ?? [])
          .map((m) => OrderModification.fromJson(m))
          .toList(),
    );
  }
}

/* ─── API ────────────────────────────────────────────────── */
class KdsApi {
  static Future<List<KitchenOrder>> fetchOrders() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/orders?limit=100'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];

    final activeOrders = data.where((j) {
      if (j is! Map) return false;
      final status = j['status'] as String? ?? '';
      final kdsStatus = j['kdsStatus'] as String? ?? 'pending';

      // Ignore drafts, cancelled orders, employee meals
      if (status == 'annulee' || status == 'repas_employe' || status == 'en_cours') {
        return false;
      }

      final ts = j['kdsSentAt'] ?? j['createdAt'];
      final dt = ts != null
          ? (DateTime.tryParse(ts as String) ?? DateTime.now())
          : DateTime.now();

      // If completed / served, only include if from today
      if (status == 'terminee' || kdsStatus == 'served' || kdsStatus == 'ready' || status == 'a_encaisser') {
        return _isToday(dt);
      }

      // Active orders (en_attente, in_progress, pending)
      return true;
    }).map((j) => KitchenOrder.fromJson(j as Map<String, dynamic>)).toList();

    return activeOrders;
  }



  static Future<void> advanceOrder(String id, String kdsStatus) async {
    // 1. Try dedicated KDS endpoint first
    try {
      final res = await http
          .patch(
            Uri.parse('$_kBaseUrl/kds/orders/$id/kds-status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'kdsStatus': kdsStatus}),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) return;
    } catch (_) {
      // Fallback
    }

    // 2. Fallback to PUT /orders/:id
    final body = <String, dynamic>{'kdsStatus': kdsStatus};
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (kdsStatus == 'ready') {
      body['status'] = 'a_encaisser';
      body['kdsReadyAt'] = nowIso;
    } else if (kdsStatus == 'served') {
      body['status'] = 'terminee';
      body['completedAt'] = nowIso;
    }

    final res = await http
        .put(
          Uri.parse('$_kBaseUrl/orders/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  static Future<void> updateItemStatus({
    required KitchenOrder order,
    required int itemIndex,
    required String newStatus,
  }) async {
    final item = order.items[itemIndex];
    item.kdsStatus = newStatus;

    // 1. Try dedicated endpoint PATCH /kds/orders/:orderId/items/:itemId/kds-status
    if (item.id != null && item.id!.isNotEmpty) {
      try {
        final res = await http
            .patch(
              Uri.parse('$_kBaseUrl/kds/orders/${order.id}/items/${item.id}/kds-status'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'kdsStatus': newStatus}),
            )
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) return;
      } catch (_) {
        // Fallback below
      }
    }

    // 2. Fallback to PUT /orders/:id with updated items array
    final itemsPayload = order.items.map((it) => it.toDbJson()).toList();
    final body = <String, dynamic>{
      'items': itemsPayload,
    };

    // If all items are ready, also set order kdsStatus to ready
    final allReady = order.items.every((it) => it.isReady);
    if (allReady && order.status == OrderStatus.attente) {
      body['kdsStatus'] = 'ready';
      body['status'] = 'a_encaisser';
      body['kdsReadyAt'] = DateTime.now().toUtc().toIso8601String();
      order.status = OrderStatus.terminee;
      order.note = 'PR\u00caT';
    }

    final res = await http
        .put(
          Uri.parse('$_kBaseUrl/orders/${order.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }
}


/* ─── Screen ─────────────────────────────────────────────── */
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});
  @override State<KdsScreen> createState() => _KdsState();
}

enum _Tab { toutes, attente, preparation, terminees }

class _KdsState extends State<KdsScreen> {
  List<KitchenOrder> _orders = [];
  _Tab     _tab     = _Tab.toutes;
  DateTime _now     = DateTime.now();
  bool     _loading = true;
  String?  _error;
  late Timer _clockTimer;
  late Timer _pollTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    _fetchOrders();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _fetchOrders());
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pollTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final orders = await KdsApi.fetchOrders();
      if (mounted) {
        setState(() { _orders = orders; _loading = false; _error = null; });
      }
    } catch (e) {
      if (mounted) { setState(() { _loading = false; _error = e.toString(); }); }
    }
  }

  List<KitchenOrder> get _visible {
    switch (_tab) {
      case _Tab.toutes:
        final active = _orders.where((o) => o.status != OrderStatus.terminee).toList();
        final done = _orders.where((o) => o.status == OrderStatus.terminee).toList();
        active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        done.sort((a, b) => (b.finishedAt ?? b.createdAt).compareTo(a.finishedAt ?? a.createdAt));
        return [...active, ...done];
      case _Tab.attente:
        final list = _orders.where((o) => o.status == OrderStatus.attente).toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      case _Tab.preparation:
        final list = _orders.where((o) => o.status == OrderStatus.preparation).toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      case _Tab.terminees:
        final list = _orders.where((o) => o.status == OrderStatus.terminee).toList();
        list.sort((a, b) => (b.finishedAt ?? b.createdAt).compareTo(a.finishedAt ?? a.createdAt));
        return list;
    }
  }

  int _count(_Tab t) {
    switch (t) {
      case _Tab.toutes:      return _orders.length;
      case _Tab.attente:     return _orders.where((o) => o.status == OrderStatus.attente).length;
      case _Tab.preparation: return _orders.where((o) => o.status == OrderStatus.preparation).length;
      case _Tab.terminees:   return _orders.where((o) => o.status == OrderStatus.terminee).length;
    }
  }

  Future<void> _advance(KitchenOrder order) async {
    if (order.status == OrderStatus.terminee) return;

    String nextKds;
    if (order.status == OrderStatus.attente) {
      nextKds = 'in_progress';
    } else {
      final isTable = (order.tableNumber != null && order.tableNumber!.isNotEmpty) ||
          order.mode == OrderMode.surPlace;
      nextKds = isTable ? 'ready' : 'served';
    }

    // Optimistic UI update
    setState(() {
      if (order.status == OrderStatus.attente) {
        order.status = OrderStatus.preparation;
      } else {
        order.status = OrderStatus.terminee;
        order.note = 'TERMIN\u00c9';
      }
    });

    try {
      await KdsApi.advanceOrder(order.id, nextKds);
      await Future.delayed(const Duration(milliseconds: 400));
      _fetchOrders();
    } catch (_) {
      _fetchOrders(); // restore true state on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: C.bg,
        body: LayoutBuilder(builder: (ctx, constraints) {
          final r = R(constraints.maxWidth, constraints.maxHeight);
          return Column(children: [
            _buildHeader(r),
            _buildTabs(r),
            Expanded(child: _buildBody(r)),
          ]);
        }),
      ),
    );
  }

  void _showOrderDetails(KitchenOrder order) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => KitchenOrderDetailsDialog(
        order: order,
        onClose: () => Navigator.of(dialogCtx).pop(),
        onAdvance: (ord) async {
          Navigator.of(dialogCtx).pop();
          await _advance(ord);
        },
        onItemStatusChanged: (item, isReady) {
          if (mounted) setState(() {});
        },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  /* ── Body states ── */
  Widget _buildBody(R r) {
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: C.yellow),
        const SizedBox(height: 16),
        Text('Connexion \u00e0 la cuisine\u2026',
            style: TextStyle(color: C.muted, fontSize: r.fs(14))),
      ]));
    }
    if (_error != null && _orders.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: C.muted),
        const SizedBox(height: 12),
        Text('Erreur de connexion',
            style: TextStyle(color: C.ink, fontSize: r.fs(15), fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Nouvelle tentative dans 5s\u2026',
            style: TextStyle(color: C.muted, fontSize: r.fs(12))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _fetchOrders,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('R\u00e9essayer'),
          style: ElevatedButton.styleFrom(
              backgroundColor: C.yellow, foregroundColor: C.brown, elevation: 0),
        ),
      ]));
    }
    if (_visible.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline_rounded, size: 48, color: C.green),
        const SizedBox(height: 12),
        Text('Aucune commande en attente',
            style: TextStyle(color: C.muted, fontSize: r.fs(15))),
      ]));
    }
    return LayoutBuilder(builder: (_, gc) {
      final gr = R(gc.maxWidth, gc.maxHeight);
      return GridView.builder(
        padding: EdgeInsets.all(gr.hPad).copyWith(bottom: gr.hPad + 4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gr.cols,
          crossAxisSpacing: gr.gap,
          mainAxisSpacing: gr.gap,
          mainAxisExtent: gr.cardH,
        ),
        itemCount: _visible.length,
        itemBuilder: (_, i) {
          final o = _visible[i];
          return _OrderCard(
            order: o,
            now: _now,
            r: gr,
            onAdvance: () => _advance(o),
            onDetails: () => _showOrderDetails(o),
          );
        },
      );
    });
  }

  /* ── Header ── */
  Widget _buildHeader(R r) {
    final connected = _error == null;
    final logoSize  = r.w < 800 ? 38.0 : 44.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.fs(18), vertical: r.w < 800 ? 8 : 11),
      decoration: BoxDecoration(
        color: C.cardBg,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFACC15), width: 2.0),
            image: const DecorationImage(
              image: AssetImage('assets/images/bobo_portrait.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(width: r.fs(10)),
        Text(
          "Bobo's",
          style: GoogleFonts.pacifico(
            fontSize: r.fs(22),
            letterSpacing: 0.5,
            color: C.ink,
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'ÉCRAN CUISINE – POSTE PRINCIPAL',
              style: GoogleFonts.bebasNeue(
                fontSize: r.fs(22),
                color: const Color(0xFF1C1917),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.fs(10), vertical: 5),
          decoration: BoxDecoration(
            color: connected ? C.greenBg : C.orangeBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(
                color: connected ? C.green : C.orange, shape: BoxShape.circle)),
            SizedBox(width: r.fs(5)),
            Text(connected ? 'Cuisine Connect\u00e9e' : 'Reconnexion\u2026',
              style: TextStyle(fontSize: r.fs(11), fontWeight: FontWeight.w700,
                  color: connected ? C.greenText : C.orange)),
          ]),
        ),
      ]),
    );
  }

  /* ── Tabs ── */
  static const _tabLabels = {
    _Tab.toutes:      'TOUTES',
    _Tab.attente:     'EN ATTENTE',
    _Tab.preparation: 'EN PR\u00c9PARATION',
    _Tab.terminees:   'TERMIN\u00c9ES',
  };

  Widget _buildTabs(R r) {
    return Container(
      color: C.bg,
      padding: EdgeInsets.fromLTRB(r.hPad, r.w < 800 ? 8 : 10, r.hPad, r.w < 800 ? 6 : 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _Tab.values.map((t) {
              final active = t == _tab;
              return Padding(
                padding: EdgeInsets.only(right: r.fs(9)),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = t),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.fs(13), vertical: r.w < 800 ? 7 : 9),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFFCF0CA) : C.cardBg,
                        border: Border.all(
                            color: active ? C.yellow : C.border, width: active ? 1.5 : 1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_tabLabels[t]!, style: TextStyle(fontSize: r.fs(11.5),
                            fontWeight: FontWeight.w800, letterSpacing: 0.3,
                            color: active ? C.ink : C.muted)),
                        SizedBox(width: r.fs(6)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
                          decoration: BoxDecoration(
                            color: active ? C.yellow : const Color(0xFFEBE8E1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('${_count(t)}', style: TextStyle(fontSize: r.fs(10),
                              fontWeight: FontWeight.w800, color: active ? C.brown : C.ink)),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

}

/* ─── Order Card ─────────────────────────────────────────── */
class _OrderCard extends StatefulWidget {
  final KitchenOrder order;
  final DateTime now;
  final R r;
  final Future<void> Function() onAdvance;
  final VoidCallback? onDetails;
  const _OrderCard({
    required this.order,
    required this.now,
    required this.r,
    required this.onAdvance,
    this.onDetails,
  });
  @override State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late AnimationController _bounce;
  late Animation<double> _bounceAnim;
  bool _canScrollDown = false;
  bool _advancing     = false; // debounce — prevents double-tap

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 620))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: 5).animate(
        CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    _scroll.addListener(_checkScroll);
  }

  void _checkScroll() {
    if (!_scroll.hasClients) return;
    final can = _scroll.position.maxScrollExtent > 0 &&
                _scroll.offset < _scroll.position.maxScrollExtent - 4;
    if (can != _canScrollDown) { setState(() => _canScrollDown = can); }
  }

  @override
  void didUpdateWidget(_OrderCard old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() { _scroll.dispose(); _bounce.dispose(); super.dispose(); }

  Duration get _elapsed => widget.now.difference(widget.order.createdAt);

  String get _elapsedLabel {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Urgency get _urgency {
    if (widget.order.status == OrderStatus.terminee) return Urgency.ready;
    final m = _elapsed.inMinutes;
    if (m >= 15) return Urgency.critical;
    if (m >= 10) return Urgency.warning;
    return Urgency.normal;
  }

  Color get _borderColor {
    if (widget.order.status == OrderStatus.terminee) return C.border;
    if (widget.order.isEdited) {
      if (_urgency == Urgency.critical) return C.red;
      return const Color(0xFFF87171);
    }
    switch (_urgency) {
      case Urgency.critical: return C.red;
      case Urgency.warning:  return C.orange;
      case Urgency.ready:    return C.teal;
      case Urgency.normal:   return C.border;
    }
  }

  Color get _cardBg => widget.order.status == OrderStatus.terminee
      ? C.cardBg
      : (_urgency == Urgency.critical ? C.redBg : C.cardBg);

  Color get _timerColor {
    if (widget.order.status == OrderStatus.terminee) return C.greenText;
    switch (_urgency) {
      case Urgency.critical: return C.red;
      case Urgency.warning:  return C.orange;
      case Urgency.ready:    return C.teal;
      case Urgency.normal:   return C.green;
    }
  }

  ({String label, Color bg, Color fg}) get _badge {
    switch (widget.order.mode) {
      case OrderMode.surPlace:  return (label: 'SUR PLACE',  bg: C.greenBg,  fg: C.greenText);
      case OrderMode.emporter:  return (label: '\u00c0 EMPORTER', bg: C.orangeBg, fg: C.orange);
      case OrderMode.livraison: return (label: 'LIVRAISON',  bg: C.redBg,    fg: C.red);
    }
  }

  ({String label, Color bg, Color fg}) get _btn {
    switch (widget.order.status) {
      case OrderStatus.attente:     return (label: 'COMMENCER',        bg: C.yellow, fg: C.brown);
      case OrderStatus.preparation: return (label: 'TERMINER \u2713',  bg: C.green,  fg: Colors.white);
      case OrderStatus.terminee:
        final dur = widget.order.prepDurationString;
        final lbl = dur != null ? 'TERMIN\u00c9 \u2713 ($dur)' : 'TERMIN\u00c9 \u2713';
        return (label: lbl, bg: const Color(0xFFEBE8E1), fg: C.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.r;
    final muted  = widget.order.status == OrderStatus.terminee;
    final isCrit = _urgency == Urgency.critical && widget.order.status != OrderStatus.terminee;
    final b      = _badge;
    final btn    = _btn;
    final pad    = r.w < 800 ? 10.0 : 13.0;
    final bg     = _cardBg;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(r.w < 800 ? 10 : 12),
        border: Border.all(
            color: _borderColor,
            width: (widget.order.isEdited || _urgency != Urgency.normal) ? 1.8 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        /* ID + table badge ────── Mode badge */
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    widget.order.ticketNumber,
                    style: TextStyle(
                      fontSize: r.fs(13.5),
                      fontWeight: FontWeight.w800,
                      color: isCrit ? C.red : C.ink,
                    ),
                  ),
                  if (widget.order.tableNumber != null && widget.order.tableNumber!.isNotEmpty) ...[
                    SizedBox(width: r.fs(6)),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                        ),
                        child: Text(
                          widget.order.tableNumber!.toUpperCase().startsWith('TABLE')
                              ? widget.order.tableNumber!.toUpperCase()
                              : 'TABLE ${widget.order.tableNumber}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.fs(9.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
              decoration: BoxDecoration(color: b.bg, borderRadius: BorderRadius.circular(5)),
              child: Text(
                b.label,
                style: TextStyle(
                  fontSize: r.fs(9.5),
                  fontWeight: FontWeight.w800,
                  color: b.fg,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.fs(4)),
        /* Timer ────── MODIFIÉ badge */
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    widget.order.status == OrderStatus.terminee
                        ? Icons.check_circle_rounded
                        : Icons.access_time_rounded,
                    size: r.fs(12),
                    color: _timerColor,
                  ),
                  SizedBox(width: r.fs(4)),
                  Flexible(
                    child: Text(
                      widget.order.status == OrderStatus.terminee
                          ? (widget.order.finishedTimeString != null
                              ? 'Fin: ${widget.order.finishedTimeString}'
                              : (widget.order.note ?? 'Termin\u00e9e'))
                          : (widget.order.note ?? _elapsedLabel),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.fs(11.5),
                        fontWeight: FontWeight.w700,
                        color: _timerColor,
                        fontFeatures: (widget.order.status != OrderStatus.terminee && widget.order.note == null)
                            ? const [FontFeature.tabularFigures()]
                            : null,
                      ),
                    ),
                  ),
                  if (widget.order.status == OrderStatus.terminee &&
                      (widget.order.prepDurationString != null || _elapsedLabel.isNotEmpty)) ...[
                    SizedBox(width: r.fs(5)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.fs(5), vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: r.fs(10), color: const Color(0xFF059669)),
                          SizedBox(width: r.fs(3)),
                          Text(
                            widget.order.prepDurationString ?? _elapsedLabel,
                            style: TextStyle(
                              fontSize: r.fs(9.5),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.order.isEdited) ...[
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: r.fs(9.5), color: const Color(0xFFDC2626)),
                    const SizedBox(width: 3),
                    Text(
                      'MODIFIÉ',
                      style: TextStyle(
                        fontSize: r.fs(9.5),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFDC2626),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: r.fs(8)),
        Divider(color: C.border, height: 1, thickness: 1),
        SizedBox(height: r.fs(8)),
        /* Items + scroll hints */
        Expanded(
          child: Stack(children: [
            SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.order.isEdited) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: r.fs(8)),
                      padding: EdgeInsets.all(r.fs(7)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFF87171), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: r.fs(15),
                                color: const Color(0xFFDC2626),
                              ),
                              SizedBox(width: r.fs(4)),
                              Text(
                                'MODIFICATIONS :',
                                style: TextStyle(
                                  fontSize: r.fs(9.5),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFDC2626),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          if (widget.order.modificationSummary.isNotEmpty) ...[
                            SizedBox(height: r.fs(4)),
                            for (final m in widget.order.modificationSummary) ...[
                              Padding(
                                padding: EdgeInsets.only(bottom: r.fs(3)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      m.action == 'deleted'
                                          ? Icons.remove_circle
                                          : (m.action == 'added'
                                              ? Icons.add_circle
                                              : (m.action == 'table'
                                                  ? Icons.table_restaurant
                                                  : (m.action == 'note'
                                                      ? Icons.chat_bubble
                                                      : Icons.change_circle))),
                                      size: r.fs(11),
                                      color: m.action == 'deleted'
                                          ? const Color(0xFFDC2626)
                                          : (m.action == 'added'
                                              ? const Color(0xFF16A34A)
                                              : (m.action == 'table'
                                                  ? const Color(0xFF2563EB)
                                                  : (m.action == 'note'
                                                      ? const Color(0xFF7C3AED)
                                                      : const Color(0xFFD97706)))),
                                    ),
                                    SizedBox(width: r.fs(4)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.text,
                                            style: TextStyle(
                                              fontSize: r.fs(9),
                                              fontWeight: FontWeight.w800,
                                              color: m.action == 'deleted'
                                                  ? const Color(0xFFB91C1C)
                                                  : (m.action == 'added'
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFF1F2937)),
                                              decoration: m.action == 'deleted'
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          if (m.details != null && m.details!.isNotEmpty) ...[
                                            Text(
                                              m.details!,
                                              style: TextStyle(
                                                fontSize: r.fs(8.5),
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            SizedBox(height: r.fs(2)),
                            Text(
                              'Vérifier les articles et options ci-dessous',
                              style: TextStyle(
                                fontSize: r.fs(8.5),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (widget.order.comment != null && widget.order.comment!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: r.fs(8)),
                      padding: EdgeInsets.symmetric(horizontal: r.fs(8), vertical: r.fs(6)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: r.fs(13),
                            color: const Color(0xFFD97706),
                          ),
                          SizedBox(width: r.fs(6)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COMMENTAIRE :',
                                  style: TextStyle(
                                    fontSize: r.fs(9),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: r.fs(2)),
                                Text(
                                  widget.order.comment!,
                                  style: TextStyle(
                                    fontSize: r.fs(11.5),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF78350F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  for (final item in widget.order.items) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.qty} ${item.name}',
                            style: TextStyle(
                              fontSize: r.fs(13.5),
                              fontWeight: FontWeight.w700,
                              color: item.isReady
                                  ? C.greenText
                                  : (muted ? C.muted : (isCrit ? C.red : C.ink)),
                              decoration: item.isReady ? TextDecoration.lineThrough : null,
                              decorationColor: C.greenText,
                            ),
                          ),
                        ),
                        if (item.isReady)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: r.fs(12),
                              color: C.green,
                            ),
                          ),
                      ],
                    ),
                    for (final sub in item.subLines)
                      Padding(
                        padding: EdgeInsets.only(top: 1, left: r.fs(2)),
                        child: Text(
                          '\u00b7 $sub',
                          style: TextStyle(
                            fontSize: r.fs(11.5),
                            color: item.isReady
                                ? C.muted.withValues(alpha: 0.6)
                                : C.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    SizedBox(height: r.fs(7)),
                  ],
                ],
              ),
            ),
            /* A — gradient fade */
            if (_canScrollDown)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [bg.withValues(alpha: 0), bg],
                      ),
                    ),
                  ),
                ),
              ),
            /* D — bouncing arrow */
            if (_canScrollDown)
              Positioned(
                bottom: 2, left: 0, right: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (ctx2, child) => Transform.translate(
                      offset: Offset(0, _bounceAnim.value),
                      child: Center(
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: C.muted.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: C.muted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(height: r.fs(6)),
        /* Action buttons row */
        SizedBox(
          width: double.infinity,
          height: r.w < 800 ? 32 : 38,
          child: Row(
            children: [
              /* Main action button (Commencer / Terminer / Terminé) - 85% */
              Expanded(
                flex: 85,
                child: ElevatedButton(
                  onPressed: (_advancing || widget.order.status == OrderStatus.terminee)
                      ? null
                      : () async {
                          setState(() => _advancing = true);
                          await widget.onAdvance();
                          if (mounted) setState(() => _advancing = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btn.bg,
                    foregroundColor: btn.fg,
                    disabledBackgroundColor: const Color(0xFFEBE8E1),
                    disabledForegroundColor: C.muted,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(btn.label, style: TextStyle(fontSize: r.fs(11.5),
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
              SizedBox(width: r.fs(5)),
              /* Order details button - 15% */
              Expanded(
                flex: 15,
                child: Tooltip(
                  message: 'Détails de la commande',
                  child: OutlinedButton(
                    onPressed: widget.onDetails,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: C.ink,
                      side: const BorderSide(color: C.border, width: 1.2),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: r.fs(15),
                      color: C.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

