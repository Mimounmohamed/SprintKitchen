import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/* ─── Config ─────────────────────────────────────────────── */
const _kBaseUrl =
    'https://sprintkitchen-backend-api-dxedcmdth6avgha4.francecentral-01.azurewebsites.net/api';

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

/* ─── Models ─────────────────────────────────────────────── */
enum OrderMode   { surPlace, emporter, livraison }
enum OrderStatus { attente, preparation, pret }
enum Urgency     { normal, warning, critical, ready }

class KdsItem {
  final String qty, name;
  final List<String> subLines;
  const KdsItem({required this.qty, required this.name, this.subLines = const []});

  factory KdsItem.fromJson(Map<String, dynamic> j) {
    final subs = <String>[];
    final customs = j['customizations'] as List? ?? [];
    for (final c in customs) {
      final opts = (c['selectedOptions'] as List? ?? [])
          .map((o) => o['label']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (opts.isNotEmpty) { subs.add('${c['groupName']}: $opts'); }
    }
    final removed = j['removedIngredients'] as List? ?? [];
    for (final r in removed) { subs.add('Sans $r'); }
    if (j['notes'] != null && (j['notes'] as String).isNotEmpty) {
      subs.add(j['notes'] as String);
    }
    return KdsItem(
      qty:      '${j['quantity'] ?? 1}\u00d7',
      name:     j['productName']?.toString() ?? '?',
      subLines: subs,
    );
  }
}

class KitchenOrder {
  final String id;
  final String ticketNumber;
  final OrderMode mode;
  final DateTime createdAt;
  final List<KdsItem> items;
  OrderStatus status;
  String? note;

  KitchenOrder({
    required this.id,
    required this.ticketNumber,
    required this.mode,
    required this.createdAt,
    required this.items,
    required this.status,
    this.note,
  });

  factory KitchenOrder.fromJson(Map<String, dynamic> j) {
    final rawMode = j['orderType'] as String? ?? 'sur_place';
    OrderMode mode;
    switch (rawMode) {
      case 'a_emporter': mode = OrderMode.emporter;  break;
      case 'livraison':  mode = OrderMode.livraison; break;
      default:           mode = OrderMode.surPlace;
    }

    final rawKds = j['kdsStatus'] as String? ?? 'pending';
    OrderStatus status;
    String? note;
    switch (rawKds) {
      case 'in_progress':
        status = OrderStatus.preparation;
        break;
      case 'ready':
        status = OrderStatus.pret;
        note   = 'PR\u00caT';
        break;
      default:
        status = OrderStatus.attente;
    }
    if (j['status'] == 'a_encaisser' && status != OrderStatus.pret) {
      status = OrderStatus.pret;
      note   = 'PR\u00caT \u2022 EN ATTENTE CAISSE';
    }

    final items = (j['items'] as List? ?? [])
        .map((i) => KdsItem.fromJson(i as Map<String, dynamic>))
        .toList();

    final ts = j['kdsSentAt'] ?? j['createdAt'];
    return KitchenOrder(
      id:           j['_id']?.toString() ?? '',
      ticketNumber: '#${j['ticketNumber'] ?? '?'}',
      mode:         mode,
      createdAt:    ts != null
          ? DateTime.tryParse(ts as String) ?? DateTime.now()
          : DateTime.now(),
      items:        items,
      status:       status,
      note:         note,
    );
  }
}

/* ─── API ────────────────────────────────────────────────── */
class KdsApi {
  static Future<List<KitchenOrder>> fetchOrders() async {
    final res = await http
        .get(Uri.parse('$_kBaseUrl/kds/orders'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data
        .map((j) => KitchenOrder.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> advanceOrder(String id, String kdsStatus) async {
    await http.patch(
      Uri.parse('$_kBaseUrl/kds/orders/$id/kds-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'kdsStatus': kdsStatus}),
    ).timeout(const Duration(seconds: 6));
  }
}

/* ─── Screen ─────────────────────────────────────────────── */
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});
  @override State<KdsScreen> createState() => _KdsState();
}

enum _Tab { toutes, attente, preparation, pretes }

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
      case _Tab.toutes:      return _orders;
      case _Tab.attente:     return _orders.where((o) => o.status == OrderStatus.attente).toList();
      case _Tab.preparation: return _orders.where((o) => o.status == OrderStatus.preparation).toList();
      case _Tab.pretes:      return _orders.where((o) => o.status == OrderStatus.pret).toList();
    }
  }

  int _count(_Tab t) {
    switch (t) {
      case _Tab.toutes:      return _orders.length;
      case _Tab.attente:     return _orders.where((o) => o.status == OrderStatus.attente).length;
      case _Tab.preparation: return _orders.where((o) => o.status == OrderStatus.preparation).length;
      case _Tab.pretes:      return _orders.where((o) => o.status == OrderStatus.pret).length;
    }
  }

  Future<void> _advance(KitchenOrder order) async {
    String nextKds;
    if      (order.status == OrderStatus.attente)     { nextKds = 'in_progress'; }
    else if (order.status == OrderStatus.preparation) { nextKds = 'ready'; }
    else                                              { nextKds = 'served'; }

    // Optimistic UI update
    setState(() {
      if      (order.status == OrderStatus.attente)     { order.status = OrderStatus.preparation; }
      else if (order.status == OrderStatus.preparation) { order.status = OrderStatus.pret; order.note = 'PR\u00caT'; }
      else                                              { _orders.remove(order); }
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
    if (_error != null) {
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
          return _OrderCard(order: o, now: _now, r: gr, onAdvance: () => _advance(o));
        },
      );
    });
  }

  /* ── Header ── */
  Widget _buildHeader(R r) {
    String two(int v) => v.toString().padLeft(2, '0');
    final clock = '${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)}';
    final connected = _error == null && !_loading;
    final iconSize  = r.w < 800 ? 32.0 : 36.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.fs(18), vertical: r.w < 800 ? 8 : 11),
      decoration: BoxDecoration(
        color: C.cardBg,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(children: [
        Container(
          width: iconSize, height: iconSize,
          decoration: BoxDecoration(color: C.brown, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.restaurant, color: C.yellow, size: r.fs(17)),
        ),
        SizedBox(width: r.fs(8)),
        Text('SPRINTKITCHEN', style: TextStyle(fontWeight: FontWeight.w800,
            fontSize: r.fs(14), letterSpacing: 0.2, color: C.ink)),
        SizedBox(width: r.fs(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.fs(5), vertical: 2),
          decoration: BoxDecoration(color: C.brown, borderRadius: BorderRadius.circular(4)),
          child: Text('KDS', style: TextStyle(color: const Color(0xFFF5F0E6),
              fontWeight: FontWeight.w800, fontSize: r.fs(9), letterSpacing: 0.3)),
        ),
        Expanded(
          child: Center(
            child: Text('\u00c9CRAN CUISINE \u2013 POSTE PRINCIPAL',
              style: GoogleFonts.bebasNeue(fontSize: r.fs(22),
                  color: const Color(0xFF1C1917), fontWeight: FontWeight.w400, letterSpacing: 0.8)),
          ),
        ),
        if (r.w >= 700) ...[
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
          SizedBox(width: r.fs(14)),
        ],
        Text(clock, style: TextStyle(fontSize: r.fs(14), fontWeight: FontWeight.w700,
            color: C.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  /* ── Tabs ── */
  static const _tabLabels = {
    _Tab.toutes:      'TOUTES',
    _Tab.attente:     'EN ATTENTE',
    _Tab.preparation: 'EN PR\u00c9PARATION',
    _Tab.pretes:      'PR\u00caTES',
  };

  Widget _buildTabs(R r) {
    return Container(
      color: C.bg,
      padding: EdgeInsets.fromLTRB(r.hPad, r.w < 800 ? 8 : 10, r.hPad, r.w < 800 ? 6 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _Tab.values.map((t) {
          final active = t == _tab;
          return Padding(
            padding: EdgeInsets.only(right: r.fs(9)),
            child: GestureDetector(
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
          );
        }).toList()),
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
  const _OrderCard({required this.order, required this.now,
    required this.r, required this.onAdvance});
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
    if (widget.order.status == OrderStatus.pret) return Urgency.ready;
    final m = _elapsed.inMinutes;
    if (m >= 15) return Urgency.critical;
    if (m >= 10) return Urgency.warning;
    return Urgency.normal;
  }

  Color get _borderColor {
    switch (_urgency) {
      case Urgency.critical: return C.red;
      case Urgency.warning:  return C.orange;
      case Urgency.ready:    return C.teal;
      case Urgency.normal:   return C.border;
    }
  }

  Color get _cardBg => _urgency == Urgency.critical ? C.redBg : C.cardBg;

  Color get _timerColor {
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
      case OrderStatus.preparation: return (label: 'PR\u00caT \u2713', bg: C.green,  fg: Colors.white);
      case OrderStatus.pret:        return (label: 'TERMIN\u00c9',     bg: C.gray,   fg: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.r;
    final muted  = widget.order.status == OrderStatus.pret;
    final isCrit = _urgency == Urgency.critical;
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
            color: _borderColor, width: _urgency == Urgency.normal ? 1 : 1.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        /* ID + badge */
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.order.ticketNumber, style: TextStyle(fontSize: r.fs(13.5),
              fontWeight: FontWeight.w800, color: isCrit ? C.red : C.ink)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
            decoration: BoxDecoration(color: b.bg, borderRadius: BorderRadius.circular(5)),
            child: Text(b.label, style: TextStyle(fontSize: r.fs(9.5),
                fontWeight: FontWeight.w800, color: b.fg, letterSpacing: 0.1)),
          ),
        ]),
        SizedBox(height: r.fs(4)),
        /* Timer */
        Row(children: [
          Icon(Icons.access_time_rounded, size: r.fs(12), color: _timerColor),
          SizedBox(width: r.fs(4)),
          Text(widget.order.note ?? _elapsedLabel,
            style: TextStyle(fontSize: r.fs(11.5), fontWeight: FontWeight.w700,
              color: _timerColor,
              fontFeatures: widget.order.note == null
                  ? const [FontFeature.tabularFigures()] : null)),
        ]),
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
                  for (final item in widget.order.items) ...[
                    Text('${item.qty} ${item.name}', style: TextStyle(
                        fontSize: r.fs(13.5), fontWeight: FontWeight.w700,
                        color: muted ? C.muted : (isCrit ? C.red : C.ink))),
                    for (final sub in item.subLines)
                      Padding(
                        padding: EdgeInsets.only(top: 1, left: r.fs(2)),
                        child: Text('\u00b7 $sub', style: TextStyle(
                            fontSize: r.fs(11.5), color: C.muted,
                            fontWeight: FontWeight.w400))),
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
        /* Button */
        SizedBox(
          width: double.infinity,
          height: r.w < 800 ? 32 : 38,
          child: ElevatedButton(
            onPressed: _advancing ? null : () async {
              setState(() => _advancing = true);
              await widget.onAdvance();
              if (mounted) setState(() => _advancing = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: btn.bg, foregroundColor: btn.fg,
              elevation: 0, padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              shadowColor: Colors.transparent,
            ),
            child: Text(btn.label, style: TextStyle(fontSize: r.fs(11.5),
                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ),
      ]),
    );
  }
}
