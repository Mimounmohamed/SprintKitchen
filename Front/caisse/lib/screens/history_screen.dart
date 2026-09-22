import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order_models.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../widgets/order_details_panel.dart';
import '../widgets/date_range_popover.dart';

/// "Historique des ventes" — list of past orders, filtered by status tab,
/// date range and search, with pagination.
///
/// Open it from the Hub with:
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const HistoryScreen()),
/// );
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.posteLabel = 'Caisse 01'});

  final String posteLabel;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _Tab {
  const _Tab(this.status, this.label, this.countLabel);
  final String status; // matches Order.status on the backend
  final String label;
  final String countLabel;
}

class _ModeStyle {
  const _ModeStyle(this.label, this.bg, this.fg, this.dot);
  final String label;
  final Color bg;
  final Color fg;
  final Color dot;
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSize = 9;
  static const double _minTableWidth = 900;

  // Table palette (Figma): stone neutrals + brand brown.
  static const Color _ink = Color(0xFF1C1917); //        cells text
  static const Color _stone700 = Color(0xFF44403C);
  static const Color _stone600 = Color(0xFF57534E); //   headers, time
  static const Color _stone500 = Color(0xFF78716C);
  static const Color _ticketBrown = Color(0xFF583926); // #ticket number

  static const _tabs = [
    _Tab('en_attente', 'EN ATTENTE', 'commandes en attente'),
    _Tab('a_encaisser', 'À ENCAISSER', 'commandes à encaisser'),
    _Tab('terminee', 'TERMINÉES', 'commandes terminées'),
    _Tab('repas_employe', 'REPAS EMPL.', 'repas employés'),
  ];

  static const _months = [
    'JANV.', 'FÉVR.', 'MARS', 'AVR.', 'MAI', 'JUIN',
    'JUIL.', 'AOÛT', 'SEPT.', 'OCT.', 'NOV.', 'DÉC.',
  ];

  // Column flex: DATE, HEURE, NUMÉRO, MONTANT, CAISSE, CLIENT, MODE, ACTIONS
  static const _flex = [2, 2, 2, 2, 2, 3, 2, 2];

  final HistoryService _service = HistoryService();
  final LayerLink _calendarLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _status = 'terminee';
  late DateTimeRange _range;
  int _page = 1;

  OrdersPage? _data;
  OrdersSummary? _summary;
  bool _loading = true;
  String? _error;
  String? _selectedId;
  int _requestId = 0; // ignores answers from outdated requests

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(start: today, end: today);
    _loadSummary();
    _loadOrders();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────── data ─────────────────────────────

  DateTime get _from =>
      DateTime(_range.start.year, _range.start.month, _range.start.day);

  DateTime get _to => DateTime(
      _range.end.year, _range.end.month, _range.end.day, 23, 59, 59, 999);

  Future<void> _loadOrders({bool keepData = false}) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      if (!keepData) _data = null;
    });
    try {
      final data = await _service.fetchOrders(
        status: _status,
        from: _from,
        to: _to,
        search: _searchController.text,
        page: _page,
        limit: _pageSize,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _data = data;
        _loading = false;
        _selectedId = data.orders.isEmpty ? null : data.orders.first.id;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _service.fetchSummary(from: _from, to: _to);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      // Counters are cosmetic: the table still works without them.
      if (mounted) setState(() => _summary = null);
    }
  }

  void _selectTab(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _page = 1;
    });
    _loadOrders();
  }

  void _goToPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    _loadOrders(keepData: true);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _loadOrders(keepData: true);
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePopover(
      context: context,
      link: _calendarLink,
      initialRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = picked;
      _page = 1;
    });
    _loadSummary();
    _loadOrders();
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what : bientôt disponible.')),
    );
  }

  // ─────────────────────────── formatting ───────────────────────────

  /// Open Sans text style; [lineHeight] is in px (Figma) and converted to
  /// Flutter's height multiplier.
  TextStyle _os(
    double size,
    FontWeight weight,
    Color color, {
    double? lineHeight,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.openSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: lineHeight == null ? null : lineHeight / size,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _fmtTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _fmtLong(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  String _euro(num v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  _ModeStyle _modeStyle(String type) {
    switch (type) {
      case 'a_emporter':
        return const _ModeStyle('À emporter', Color(0xFFDBEAFE),
            Color(0xFF1E40AF), Color(0xFF2563EB));
      case 'livraison':
        return const _ModeStyle('Livraison', Color(0xFFCCFBF1),
            Color(0xFF115E59), Color(0xFF0D9488));
      default:
        return const _ModeStyle('Sur place', Color(0xFFFFE4E6),
            Color(0xFF9F1239), Color(0xFFE11D48));
    }
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopSection(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                    child: _buildTableCard(),
                  ),
                ],
              ),
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 14, color: Color(0xFF374151)),
                  SizedBox(width: 8),
                  Text(
                    "Retour à l'accueil",
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF583926),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_rounded,
                  color: Color(0xFFFACC15), size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SPRINTKITCHEN',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              letterSpacing: 1.2,
              color: const Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.posteLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 14,
              children: [
                _buildTitleBlock(),
                _buildSearchAndPrint(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _tabs.map(_buildTabPill).toList(),
                  ),
                  _buildStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock() {
    final title =
        'LISTE DES COMMANDES DU ${_fmtLong(_range.start)} AU ${_fmtLong(_range.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HISTORIQUE DES VENTES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Color(0xFF6B7280),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('•',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ),
            Text(
              'SYNCHRONISÉ KDS & COMPTOIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _calendarLink,
          child: InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF374151)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 30,
                      letterSpacing: 0.5,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down,
                    size: 22, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndPrint() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 300,
          height: 44,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher ticket #, client...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brandDark),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => _comingSoon('Impression de la clôture'),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text(
              'Imprimer Clôture',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1F2937),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(_Tab tab) {
    final selected = tab.status == _status;
    final count = _summary?.countFor(tab.status) ?? 0;
    return InkWell(
      onTap: () => _selectTab(tab.status),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          // Unselected = gray capsule with a soft outline; selected = brown
          // capsule with a light ring (as in the design).
          color: selected ? AppColors.brandDark : const Color(0xFFF3F2F0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                selected ? const Color(0xFFD6D3D1) : const Color(0xFFE2E0DC),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: _os(12, FontWeight.w700, selected ? Colors.white : _stone600,
                  lineHeight: 16, letterSpacing: 0.6),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: _os(11, FontWeight.w700, _ink, lineHeight: 16),
                ),
              ),
            ] else if (tab.status == 'en_attente') ...[
              // Gray dot when nothing is waiting (as in the design).
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFA8A29E),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final tab = _tabs.firstWhere((t) => t.status == _status);
    final total = _data?.total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Affichage : ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        Text(
          total == null ? '…' : '$total ${tab.countLabel}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        if (_summary != null) ...[
          Container(
            width: 1.5,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFF6B7280),
          ),
          Text(
            'Total session : ${_euro(_summary!.totalTerminee)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────── table ─────────────────────────────

  Widget _buildTableCard() {
    final orders = _data?.orders ?? const <HistoryOrder>[];

    Widget body;
    if (_error != null) {
      body = _buildErrorState();
    } else if (_data == null) {
      body = const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (orders.isEmpty) {
      body = const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Aucune commande pour cette période.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    } else {
      body = _buildTable(orders);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          // Soft, wide shadow: lifts the card off the page.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
          // Tight shadow: crisp edge right around the card.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading && _data != null)
            const LinearProgressIndicator(minHeight: 2),
          body,
          if (_data != null && _error == null) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les commandes.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _loadSummary();
                _loadOrders();
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<HistoryOrder> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, _minTableWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                _buildTableHeader(),
                for (var i = 0; i < orders.length; i++)
                  _buildRow(orders[i], isNewest: _page == 1 && i == 0, index: i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(int index, Widget child, {Alignment? align}) {
    return Expanded(
      flex: _flex[index],
      child: Align(
        alignment: align ?? Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildTableHeader() {
    Text h(String label, {TextAlign align = TextAlign.left}) => Text(
          label,
          textAlign: align,
          style: _os(12, FontWeight.w700, _stone600,
              lineHeight: 16, letterSpacing: 0.6),
        );

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF9),
        border: Border(bottom: BorderSide(color: Color(0xFFE7E5E4))),
      ),
      child: Row(
        children: [
          _cell(0, h('DATE')),
          _cell(1, h('HEURE')),
          _cell(2, h('NUMÉRO')),
          _cell(
            3,
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: h('MONTANT', align: TextAlign.right),
            ),
            align: Alignment.centerRight,
          ),
          _cell(4, h('CAISSE')),
          _cell(5, h('CLIENT')),
          _cell(6, h('MODE')),
          _cell(7, h('ACTIONS'), align: Alignment.center),
        ],
      ),
    );
  }

  Widget _buildRow(
    HistoryOrder o, {
    required bool isNewest,
    required int index,
  }) {
    final selected = o.id == _selectedId;
    final mode = _modeStyle(o.orderType);
    final client = o.displayClient;

    // Selected row = cream; the others alternate white / very light stone.
    final rowColor = selected
        ? const Color(0xFFFEF4A8)
        : (index.isOdd ? Colors.white : const Color(0xFFFAFAF9));

    return InkWell(
      onTap: () => setState(() => _selectedId = o.id),
      child: Container(
        height: 57,
        padding: const EdgeInsets.only(left: 21, right: 24),
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFFFACC15) : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFFF5F5F4)),
          ),
        ),
        child: Row(
          children: [
            _cell(
              0,
              Text(
                _fmtDate(o.createdAt),
                style: _os(14, FontWeight.w500, _ink, lineHeight: 20),
              ),
            ),
            _cell(
              1,
              Text(
                _fmtTime(o.createdAt),
                style: _os(14, FontWeight.w400, _stone600, lineHeight: 20),
              ),
            ),
            _cell(
              2,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE7E5E4)),
                    ),
                    child: Text(
                      '#${o.ticketNumber}',
                      style: _os(12, FontWeight.w700, _ticketBrown,
                          lineHeight: 16, letterSpacing: 0.6),
                    ),
                  ),
                  if (isNewest) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _cell(
              3,
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(
                  _euro(o.totalTTC),
                  style: selected
                      ? _os(16, FontWeight.w700, _ink, lineHeight: 24)
                      : _os(14, FontWeight.w700, _ink, lineHeight: 20),
                ),
              ),
              align: Alignment.centerRight,
            ),
            _cell(
              4,
              o.registerName == null
                  ? Text('—',
                      style: _os(14, FontWeight.w400, const Color(0xFFA8A29E)))
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        o.registerName!,
                        style: _os(12, FontWeight.w500, _stone700,
                            lineHeight: 16),
                      ),
                    ),
            ),
            _cell(
              5,
              Text(
                client ?? 'Client Passant',
                overflow: TextOverflow.ellipsis,
                style: client == null
                    ? _os(14, FontWeight.w400, _stone500,
                        lineHeight: 20, fontStyle: FontStyle.italic)
                    : _os(14, FontWeight.w400, _ink, lineHeight: 20),
              ),
            ),
            _cell(6, _modeChip(mode)),
            _cell(
              7,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailsButton(o, selected),
                  if (selected) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _comingSoon('Impression du ticket'),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.print_outlined,
                            size: 18, color: _stone600),
                      ),
                    ),
                  ],
                ],
              ),
              align: Alignment.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(_ModeStyle m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: m.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: m.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            m.label,
            style: _os(12, FontWeight.w700, m.fg, lineHeight: 16),
          ),
        ],
      ),
    );
  }

  Widget _detailsButton(HistoryOrder o, bool selected) {
    return InkWell(
      onTap: () => _showDetails(o),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? _ink : const Color(0xFFD6D3D1),
          ),
        ),
        child: Text(
          'Détails',
          style: selected
              ? _os(12, FontWeight.w600, Colors.white, lineHeight: 16)
              : _os(12, FontWeight.w500, _stone600, lineHeight: 16),
        ),
      ),
    );
  }

  // ─────────────────────────── pagination ───────────────────────────

  Widget _buildPaginationBar() {
    final data = _data!;
    final totalPages = data.totalPages;

    // Everything fits on one page: no footer / pagination at all.
    if (totalPages <= 1) return const SizedBox.shrink();

    final tab = _tabs.firstWhere((t) => t.status == _status);
    final firstShown = (_page - 1) * _pageSize + 1;
    final lastShown = firstShown + data.orders.length - 1;

    final firstPage = math.max(1, math.min(_page - 2, totalPages - 4));
    final lastPage = math.min(totalPages, firstPage + 4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF9),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Text(
            'Affichage de $firstShown à $lastShown sur ${data.total} ${tab.countLabel}',
            style: _os(12, FontWeight.w400, _stone600, lineHeight: 16),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageButton(
                'Précédent',
                enabled: _page > 1,
                onTap: () => _goToPage(_page - 1),
              ),
              for (var p = firstPage; p <= lastPage; p++) ...[
                const SizedBox(width: 6),
                _pageButton(
                  '$p',
                  isNumber: true,
                  selected: p == _page,
                  onTap: () => _goToPage(p),
                ),
              ],
              const SizedBox(width: 6),
              _pageButton(
                'Suivant',
                enabled: _page < totalPages,
                onTap: () => _goToPage(_page + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageButton(
    String label, {
    bool selected = false,
    bool enabled = true,
    bool isNumber = false,
    required VoidCallback onTap,
  }) {
    final text = Text(
      label,
      style: _os(
        12,
        selected ? FontWeight.w700 : FontWeight.w600,
        selected
            ? Colors.white
            : enabled
                ? _ink
                : const Color(0xFFD6D3D1),
        lineHeight: 16,
      ),
    );

    // Fixed sizes on purpose: a Container with `alignment` and no width
    // would stretch to the full row width.
    return InkWell(
      onTap: enabled && !selected ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 34,
        width: isNumber ? 34 : null,
        alignment: isNumber ? Alignment.center : null,
        padding: isNumber ? null : const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandDark : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.brandDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: isNumber
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [text],
              ),
      ),
    );
  }

  void _showDetails(HistoryOrder o) => showOrderDetailsPanel(context, o);

  // ───────────────────────────── status bar ─────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 5, backgroundColor: Color(0xFF10B981)),
          SizedBox(width: 10),
          Text(
            'Connecté',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          Spacer(),
          Text(
            'SprintKitchen OS v2.4.0-PROD',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}