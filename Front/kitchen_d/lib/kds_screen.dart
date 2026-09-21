import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/* ─── Responsive helpers ─────────────────────────────────── */
class R {
  final double w, h;
  const R(this.w, this.h);

  // Number of card columns based on available width
  int get cols {
    if (w < 650)  return 2;
    if (w < 950)  return 3;
    if (w < 1300) return 4;
    return 5;
  }

  // Gap between cards
  double get gap => w < 800 ? 10 : 14;

  // Horizontal padding around the grid
  double get hPad => w < 800 ? 12 : 18;

  // Card height — fills ~2 rows in the available height
  double get cardH {
    final rows = 2.0;
    final available = h - (hPad * 2) - (gap * (rows - 1));
    return (available / rows).clamp(220.0, 440.0);
  }

  // Scale factor for fonts/spacing (1.0 = 1280px reference)
  double get scale => (w / 1280).clamp(0.72, 1.3);

  double fs(double base) => (base * scale).roundToDouble();
}

/* ─── Models ─────────────────────────────────────────────── */
enum OrderMode   { surPlace, emporter, livraison }
enum OrderStatus { attente, preparation, pret }
enum Urgency     { normal, warning, critical, ready }

class OrderItem {
  final String qty, name;
  final List<String> subLines;
  final bool bold;
  const OrderItem({required this.qty, required this.name,
    this.subLines = const [], this.bold = true});
}

class KitchenOrder {
  final String id;
  final OrderMode mode;
  final DateTime createdAt;
  final List<OrderItem> items;
  OrderStatus status;
  String? note;
  KitchenOrder({required this.id, required this.mode,
    required this.createdAt, required this.items,
    required this.status, this.note});
}

/* ─── Screen ─────────────────────────────────────────────── */
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});
  @override State<KdsScreen> createState() => _KdsState();
}

enum _Tab { toutes, attente, preparation, pretes }

class _KdsState extends State<KdsScreen> {
  late List<KitchenOrder> _orders;
  _Tab _tab = _Tab.attente;
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _orders = _seed();
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  List<KitchenOrder> _seed() {
    final n = DateTime.now();
    ago(int m, int s) => n.subtract(Duration(minutes: m, seconds: s));
    return [
      KitchenOrder(id: '#0000143', mode: OrderMode.surPlace,  createdAt: ago(3,42),  status: OrderStatus.attente, items: const [
        OrderItem(qty: '1\u00d7', name: 'Menu B4 Cheese', subLines: ['Cuisson: \u00c0 point', 'Sauce: Alg\u00e9rienne']),
        OrderItem(qty: '1\u00d7', name: 'Frites Maison XL'),
        OrderItem(qty: '2\u00d7', name: 'Nuggets x6'),
        OrderItem(qty: '1\u00d7', name: 'Onion Rings L'),
        OrderItem(qty: '3\u00d7', name: 'Coca-Cola 50cl'),
        OrderItem(qty: '1\u00d7', name: 'Salade Caesar', subLines: ['Sans cro\u00fbtons']),
        OrderItem(qty: '2\u00d7', name: 'Milkshake Vanille'),
        OrderItem(qty: '1\u00d7', name: 'Brownie Maison'),
      ]),
      KitchenOrder(id: '#0000142', mode: OrderMode.emporter,  createdAt: ago(10,15), status: OrderStatus.preparation, items: const [
        OrderItem(qty: '2\u00d7', name: 'Menu Bacon BBQ', subLines: ['Sauce: BBQ Intense']),
        OrderItem(qty: '1\u00d7', name: 'Coca-Cola Sans Sucres'),
      ]),
      KitchenOrder(id: '#0000140', mode: OrderMode.livraison, createdAt: ago(17,40), status: OrderStatus.preparation, items: const [
        OrderItem(qty: '1\u00d7', name: 'Menu Crispy Wrap', subLines: ['Sauce: Spicy']),
        OrderItem(qty: '2\u00d7', name: 'Frites Cheddar'),
      ]),
      KitchenOrder(id: '#0000144', mode: OrderMode.surPlace,  createdAt: ago(1,12),  status: OrderStatus.attente, items: const [
        OrderItem(qty: '3\u00d7', name: 'Mozzarella Sticks'),
        OrderItem(qty: '2\u00d7', name: 'Oignons Rings L'),
      ]),
      KitchenOrder(id: '#0000145', mode: OrderMode.emporter,  createdAt: ago(5,2),   status: OrderStatus.preparation, items: const [
        OrderItem(qty: '1\u00d7', name: 'Double Cheese Bacon'),
        OrderItem(qty: '1\u00d7', name: 'Frites XL'),
      ]),
      KitchenOrder(id: '#0000141', mode: OrderMode.surPlace,  createdAt: ago(12,44), status: OrderStatus.preparation, items: const [
        OrderItem(qty: '3\u00d7', name: 'Menu Kid Box', subLines: ['Avec Compote & Jouet']),
      ]),
      KitchenOrder(id: '#0000139', mode: OrderMode.emporter,  createdAt: ago(6,30),  status: OrderStatus.pret, note: 'PR\u00caT \u2022 SERVEUR APPEL\u00c9', items: const [
        OrderItem(qty: '1\u00d7', name: 'Smash Burger',     bold: false),
        OrderItem(qty: '1\u00d7', name: 'Milkshake Fraise', bold: false),
      ]),
      KitchenOrder(id: '#0000146', mode: OrderMode.livraison, createdAt: ago(0,45),  status: OrderStatus.attente, items: const [
        OrderItem(qty: '2\u00d7', name: 'Burgers Simple Star'),
        OrderItem(qty: '1\u00d7', name: 'Frites XL'),
      ]),
    ];
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

  void _advance(KitchenOrder o) {
    setState(() {
      if      (o.status == OrderStatus.attente)     { o.status = OrderStatus.preparation; }
      else if (o.status == OrderStatus.preparation) { o.status = OrderStatus.pret; o.note = 'PR\u00caT'; }
      else                                          { _orders.remove(o); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: C.bg,
        body: LayoutBuilder(
          builder: (ctx, constraints) {
            final r = R(constraints.maxWidth, constraints.maxHeight);
            return Column(children: [
              _buildHeader(r),
              _buildTabs(r),
              Expanded(
                child: _visible.isEmpty
                  ? Center(child: Text('Aucune commande',
                      style: TextStyle(color: C.muted, fontSize: r.fs(15))))
                  : LayoutBuilder(
                      builder: (_, gc) {
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
                            return _OrderCard(order: o, now: _now, r: gr,
                              onAdvance: () => _advance(o));
                          },
                        );
                      },
                    ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  /* ── Header ── */
  Widget _buildHeader(R r) {
    String two(int v) => v.toString().padLeft(2, '0');
    final clock = '${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)}';
    final iconSize = r.w < 800 ? 32.0 : 36.0;
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
        Text('SPRINTKITCHEN',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: r.fs(14),
            letterSpacing: 0.2, color: C.ink)),
        SizedBox(width: r.fs(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.fs(5), vertical: 2),
          decoration: BoxDecoration(color: C.brown, borderRadius: BorderRadius.circular(4)),
          child: Text('KDS', style: TextStyle(color: const Color(0xFFF5F0E6),
            fontWeight: FontWeight.w800, fontSize: r.fs(9), letterSpacing: 0.3)),
        ),
        Expanded(
          child: Center(
            child: Text('ÉCRAN CUISINE \u2013 POSTE PRINCIPAL',
              style: GoogleFonts.bebasNeue(
                fontSize: r.fs(22),
                color: const Color(0xFF1C1917),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.8,
              )),
          ),
        ),
        if (r.w >= 700) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.fs(10), vertical: 5),
            decoration: BoxDecoration(color: C.greenBg, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7,
                decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
              SizedBox(width: r.fs(5)),
              Text('Cuisine Connect\u00e9e',
                style: TextStyle(fontSize: r.fs(11), fontWeight: FontWeight.w700, color: C.greenText)),
            ]),
          ),
          SizedBox(width: r.fs(14)),
        ],
        Text(clock, style: TextStyle(fontSize: r.fs(14), fontWeight: FontWeight.w700,
          color: C.ink, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  /* ── Tab bar ── */
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
                padding: EdgeInsets.symmetric(horizontal: r.fs(13), vertical: r.w < 800 ? 7 : 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFCF0CA) : C.cardBg,
                  border: Border.all(color: active ? C.yellow : C.border, width: active ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_tabLabels[t]!,
                    style: TextStyle(fontSize: r.fs(11.5), fontWeight: FontWeight.w800,
                      letterSpacing: 0.3, color: active ? C.ink : C.muted)),
                  SizedBox(width: r.fs(6)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.fs(6), vertical: 2),
                    decoration: BoxDecoration(
                      color: active ? C.yellow : const Color(0xFFEBE8E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${_count(t)}',
                      style: TextStyle(fontSize: r.fs(10), fontWeight: FontWeight.w800,
                        color: active ? C.brown : C.ink)),
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
  final VoidCallback onAdvance;
  const _OrderCard({required this.order, required this.now,
    required this.r, required this.onAdvance});
  @override State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late AnimationController _bounce;
  late Animation<double> _bounceAnim;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))
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
    if (can != _canScrollDown) setState(() => _canScrollDown = can);
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
      case OrderStatus.attente:     return (label: 'COMMENCER', bg: C.yellow, fg: C.brown);
      case OrderStatus.preparation: return (label: 'PR\u00caT \u2713',      bg: C.green,  fg: Colors.white);
      case OrderStatus.pret:        return (label: 'TERMIN\u00c9',      bg: C.gray,   fg: Colors.white);
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
        border: Border.all(color: _borderColor, width: _urgency == Urgency.normal ? 1 : 1.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        /* ID + badge */
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.order.id,
            style: TextStyle(fontSize: r.fs(13.5), fontWeight: FontWeight.w800,
              color: isCrit ? C.red : C.ink)),
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

        /* Items list + A (gradient) + D (bounce arrow) */
        Expanded(
          child: Stack(children: [
            /* Scrollable items */
            SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in widget.order.items) ...[
                    Text('${item.qty} ${item.name}',
                      style: TextStyle(
                        fontSize: r.fs(13.5),
                        fontWeight: item.bold ? FontWeight.w700 : FontWeight.w500,
                        color: muted ? C.muted : (isCrit ? C.red : C.ink))),
                    for (final sub in item.subLines)
                      Padding(
                        padding: EdgeInsets.only(top: 1, left: r.fs(2)),
                        child: Text('\u00b7 $sub',
                          style: TextStyle(fontSize: r.fs(11.5), color: C.muted,
                            fontWeight: FontWeight.w400))),
                    SizedBox(height: r.fs(7)),
                  ],
                ],
              ),
            ),

            /* A — Gradient fade */
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

            /* D — Bouncing chevron */
            if (_canScrollDown)
              Positioned(
                bottom: 2, left: 0, right: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (context2, child) => Transform.translate(
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
            onPressed: widget.onAdvance,
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
