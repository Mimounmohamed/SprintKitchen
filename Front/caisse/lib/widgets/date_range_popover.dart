import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the "Sélectionner une période de vente" popover right below
/// [link]'s target (the calendar trigger in the History screen), matching
/// the Figma design: quick shortcuts on the left, a two-month calendar on
/// the right, and a footer with the selected period + Annuler/Appliquer.
///
/// Resolves when the popover closes: with the new range if "Appliquer la
/// période" was pressed, or null if cancelled / dismissed.
Future<DateTimeRange?> showDateRangePopover({
  required BuildContext context,
  required LayerLink link,
  required DateTimeRange initialRange,
  DateTime? lastDate,
}) {
  final completer = Completer<DateTimeRange?>();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _DateRangePopoverOverlay(
      link: link,
      initialRange: initialRange,
      lastDate: lastDate ?? DateTime.now(),
      onClose: (result) {
        entry.remove();
        if (!completer.isCompleted) completer.complete(result);
      },
    ),
  );

  Overlay.of(context).insert(entry);
  return completer.future;
}

// ───────────────────────────── overlay shell ─────────────────────────────

class _DateRangePopoverOverlay extends StatelessWidget {
  const _DateRangePopoverOverlay({
    required this.link,
    required this.initialRange,
    required this.lastDate,
    required this.onClose,
  });

  final LayerLink link;
  final DateTimeRange initialRange;
  final DateTime lastDate;
  final void Function(DateTimeRange? result) onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible barrier: tapping outside the card cancels.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onClose(null),
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(-4, 10),
          child: GestureDetector(
            // Absorb taps so they don't fall through to the barrier.
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: _DateRangePopoverCard(
              initialRange: initialRange,
              lastDate: lastDate,
              onCancel: () => onClose(null),
              onApply: (range) => onClose(range),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── the card itself ─────────────────────────────

class _Shortcut {
  const _Shortcut(this.label, this.rangeBuilder, {this.valueLabelBuilder});
  final String label;
  final DateTimeRange Function(DateTime today) rangeBuilder;
  final String Function(DateTime today)? valueLabelBuilder;
}

class _DateRangePopoverCard extends StatefulWidget {
  const _DateRangePopoverCard({
    required this.initialRange,
    required this.lastDate,
    required this.onCancel,
    required this.onApply,
  });

  final DateTimeRange initialRange;
  final DateTime lastDate;
  final VoidCallback onCancel;
  final ValueChanged<DateTimeRange> onApply;

  @override
  State<_DateRangePopoverCard> createState() => _DateRangePopoverCardState();
}

class _DateRangePopoverCardState extends State<_DateRangePopoverCard> {
  static const Color _ink = Color(0xFF1C1917);
  static const Color _stone600 = Color(0xFF57534E);
  static const Color _stone500 = Color(0xFF78716C);
  static const Color _stone400 = Color(0xFFA8A29E);
  static const Color _border = Color(0xFFE7E5E4);
  static const Color _brandDark = Color(0xFF452B1E);
  static const Color _gold = Color(0xFFFACC15);
  static const Color _rangeFill = Color(0xFFFDE9A0);

  static const _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _monthNamesShort = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  static const _weekdayHeaders = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  late DateTime _today;
  late DateTime? _start;
  late DateTime? _end;
  late DateTime _rightMonth; // first-of-month for the right calendar

  late final List<_Shortcut> _shortcuts;

  @override
  void initState() {
    super.initState();
    final now = widget.lastDate;
    _today = DateTime(now.year, now.month, now.day);
    _start = widget.initialRange.start;
    _end = widget.initialRange.end;
    final anchor = _end ?? _today;
    _rightMonth = DateTime(anchor.year, anchor.month, 1);

    _shortcuts = [
      _Shortcut('Aujourd\'hui', (t) => DateTimeRange(start: t, end: t),
          valueLabelBuilder: (t) => _fmtShort(t)),
      _Shortcut(
        'Hier',
        (t) {
          final y = t.subtract(const Duration(days: 1));
          return DateTimeRange(start: y, end: y);
        },
        valueLabelBuilder: (t) => _fmtShort(t.subtract(const Duration(days: 1))),
      ),
      _Shortcut(
        '7 derniers jours',
        (t) => DateTimeRange(start: t.subtract(const Duration(days: 6)), end: t),
      ),
      _Shortcut(
        'Ce mois-ci',
        (t) => DateTimeRange(start: DateTime(t.year, t.month, 1), end: t),
        valueLabelBuilder: (t) => _monthNames[t.month - 1],
      ),
      _Shortcut(
        'Mois dernier',
        (t) {
          final lastMonthEnd = DateTime(t.year, t.month, 1)
              .subtract(const Duration(days: 1));
          final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
          return DateTimeRange(start: lastMonthStart, end: lastMonthEnd);
        },
        valueLabelBuilder: (t) {
          final prev = DateTime(t.year, t.month - 1, 1);
          return _monthNames[prev.month - 1];
        },
      ),
      _Shortcut(
        'Tout l\'historique',
        (t) => DateTimeRange(start: DateTime(2020, 1, 1), end: t),
        valueLabelBuilder: (_) => 'Toutes dates',
      ),
    ];
  }

  DateTime get _leftMonth => DateTime(_rightMonth.year, _rightMonth.month - 1, 1);

  bool get _canGoNext {
    final next = DateTime(_rightMonth.year, _rightMonth.month + 1, 1);
    return !next.isAfter(DateTime(_today.year, _today.month, 1));
  }

  String _fmtShort(DateTime d) => '${d.day} ${_monthNamesShort[d.month - 1]}';
  String _fmtSlash(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesShortcut(_Shortcut s) {
    if (_start == null || _end == null) return false;
    if (s.label == 'Tout l\'historique') {
      return _start!.year <= 2020 && _isSameDay(_end!, _today);
    }
    final r = s.rangeBuilder(_today);
    return _isSameDay(_start!, r.start) && _isSameDay(_end!, r.end);
  }

  void _applyShortcut(_Shortcut s) {
    final r = s.rangeBuilder(_today);
    setState(() {
      _start = r.start;
      _end = r.end;
      _rightMonth = DateTime(r.end.year, r.end.month, 1);
    });
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  void _goPrevMonth() =>
      setState(() => _rightMonth = DateTime(_rightMonth.year, _rightMonth.month - 1, 1));

  void _goNextMonth() {
    if (!_canGoNext) return;
    setState(() => _rightMonth = DateTime(_rightMonth.year, _rightMonth.month + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 860,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 50,
              spreadRadius: -12,
              offset: const Offset(0, 25),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: _buildShortcuts()),
                  const SizedBox(width: 32),
                  Expanded(child: _buildCalendars()),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 18, 20),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brandDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                size: 17, color: _gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SÉLECTIONNER UNE PÉRIODE DE VENTE',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Filtrer l'historique des encaissements, tickets et statistiques",
                  style: GoogleFonts.openSans(fontSize: 12.5, color: _stone500),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: widget.onCancel,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 20, color: _stone500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RACCOURCIS RAPIDES',
          style: GoogleFonts.openSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _stone500,
          ),
        ),
        const SizedBox(height: 12),
        for (final s in _shortcuts) ...[
          _buildShortcutRow(s),
          const SizedBox(height: 4),
        ],
        _buildCustomRow(),
      ],
    );
  }

  Widget _buildShortcutRow(_Shortcut s) {
    final active = _matchesShortcut(s);
    final valueLabel = s.valueLabelBuilder?.call(_today);
    return InkWell(
      onTap: () => _applyShortcut(s),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _brandDark : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (active) ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Expanded(
              child: Text(
                s.label,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Colors.white : _ink,
                ),
              ),
            ),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Actif',
                  style: GoogleFonts.openSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              )
            else if (valueLabel != null)
              Text(
                valueLabel,
                style: GoogleFonts.openSans(fontSize: 12, color: _stone500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRow() {
    // "Personnalisé" is active whenever the current range doesn't match a
    // preset above: the free two-month calendar to the right is always the
    // way to make a custom pick, so this row is informational.
    final active = _shortcuts.every((s) => !_matchesShortcut(s));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? _brandDark : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (active) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Expanded(
            child: Text(
              'Personnalisé',
              style: GoogleFonts.openSans(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : _ink,
              ),
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: active ? Colors.white : _stone400),
        ],
      ),
    );
  }

  Widget _buildCalendars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _goPrevMonth,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_left, size: 20, color: _stone600),
              ),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_leftMonth.month - 1].toUpperCase()} ${_leftMonth.year}',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _ink,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_rightMonth.month - 1].toUpperCase()} ${_rightMonth.year}',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _ink,
                ),
              ),
            ),
            InkWell(
              onTap: _canGoNext ? _goNextMonth : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.chevron_right,
                    size: 20, color: _canGoNext ? _stone600 : _border),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildMonthGrid(_leftMonth)),
            const SizedBox(width: 28),
            Expanded(child: _buildMonthGrid(_rightMonth)),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;

    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final h in _weekdayHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _stone500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _buildDayCell(
                      cells[row * 7 + col],
                      col: col,
                      isFirstInMonth: cells[row * 7 + col]?.day == 1,
                      isLastInMonth: cells[row * 7 + col]?.day == daysInMonth,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime? day, {
    required int col,
    bool isFirstInMonth = false,
    bool isLastInMonth = false,
  }) {
    const double cellH = 38.0;
    const double brownSize = 32.0;
    const double haloSize = 38.0;
    const double radius = haloSize / 2;

    if (day == null) return const SizedBox(height: cellH);

    final isAllHistory = _start != null && _start!.year <= 2020;
    final isStart = _start != null && !isAllHistory && _isSameDay(day, _start!);
    final isEnd = _end != null && !isAllHistory && _isSameDay(day, _end!);
    final isSingleDay = isStart && isEnd;
    final isEndpoint = isStart || isEnd;
    final inRange = !isAllHistory &&
        _start != null &&
        _end != null &&
        day.isAfter(_start!) &&
        day.isBefore(_end!);
    final isToday = _isSameDay(day, _today);
    final disabled = day.isAfter(_today);

    // Strip behind the cell (for multi-day ranges)
    Widget? strip;
    if (!isSingleDay && (_start != null && _end != null && !isAllHistory)) {
      if (inRange) {
        final roundLeft = col == 0 || isFirstInMonth;
        final roundRight = col == 6 || isLastInMonth;
        strip = Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _rangeFill,
              borderRadius: BorderRadius.horizontal(
                left: roundLeft ? const Radius.circular(radius) : Radius.zero,
                right: roundRight ? const Radius.circular(radius) : Radius.zero,
              ),
            ),
          ),
        );
      } else if (isStart) {
        strip = Positioned.fill(
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                child: Container(
                  color: (col == 6 || isLastInMonth)
                      ? Colors.transparent
                      : _rangeFill,
                ),
              ),
            ],
          ),
        );
      } else if (isEnd) {
        strip = Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: (col == 0 || isFirstInMonth)
                      ? Colors.transparent
                      : _rangeFill,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        );
      }
    }

    // Halo behind endpoints
    Widget? halo;
    if (!isSingleDay && isEndpoint) {
      halo = Center(
        child: Container(
          width: haloSize,
          height: haloSize,
          decoration: const BoxDecoration(
            color: _rangeFill,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    // Day content
    Widget dayContent;
    if (isEndpoint) {
      dayContent = Center(
        child: Container(
          width: brownSize,
          height: brownSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _brandDark,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${day.day}',
            style: GoogleFonts.openSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      dayContent = Center(
        child: Container(
          width: brownSize,
          height: brownSize,
          alignment: Alignment.center,
          decoration: (isToday && !inRange)
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _brandDark, width: 1.4),
                )
              : null,
          child: Text(
            '${day.day}',
            style: GoogleFonts.openSans(
              fontSize: 13.5,
              fontWeight: inRange ? FontWeight.w700 : FontWeight.w500,
              color: disabled
                  ? _stone400
                  : inRange
                      ? _brandDark
                      : _ink,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: cellH,
      child: InkWell(
        onTap: disabled ? null : () => _onDayTap(day),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ?strip,
            ?halo,
            dayContent,
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final hasRange = _start != null && _end != null;
    final isAllHistory = _start != null && _start!.year <= 2020;
    final days = hasRange ? _end!.difference(_start!).inDays + 1 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Période sélectionnée : ',
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _stone600,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasRange
                          ? (isAllHistory
                              ? 'Tout l\'historique'
                              : '${_fmtSlash(_start!)} — ${_fmtSlash(_end!)}')
                          : 'Choisissez une période',
                      style: GoogleFonts.openSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (hasRange) ...[
                      const SizedBox(width: 8),
                      Text(
                        isAllHistory
                            ? '(Toutes dates)'
                            : '($days jour${days > 1 ? 's' : ''})',
                        style: GoogleFonts.openSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _stone500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: _stone600,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.openSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: hasRange
                    ? () => widget.onApply(DateTimeRange(start: _start!, end: _end!))
                    : null,
                icon: const Icon(Icons.check, size: 16, color: _ink),
                label: Text(
                  'Appliquer la période',
                  style: GoogleFonts.openSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                  disabledBackgroundColor: _gold.withValues(alpha: 0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}