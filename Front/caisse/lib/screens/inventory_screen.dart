import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_models.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../widgets/inventory/family_modal.dart';
import '../widgets/inventory/ingredient_modal.dart';

/// "Disponibilité des articles" — availability toggling for ingredients,
/// grouped by family, with add/edit/delete for both.
///
/// Open it from the Hub with:
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const InventoryScreen()),
/// );
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.posteLabel = 'Caisse 01'});

  final String posteLabel;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Tints the shared AppColors palette doesn't have, matching the web
  // admin's local C object exactly.
  static const Color _greenBg = Color(0xFFE8F8EF);
  static const Color _greenText = Color(0xFF1A7A45);
  static const Color _epuiseBg = Color(0xFFFDF7F6);
  static const Color _orangeChipBg = Color(0xFFFEF0E0);
  static const Color _dimText = Color(0xFFA8978F);

  final InventoryService _service = InventoryService();
  final TextEditingController _searchController = TextEditingController();

  List<IngredientFamily> _families = [];
  List<FamilyStat> _familyStats = [];
  List<Ingredient> _ingredients = [];
  String? _activeFamily;

  bool _loadingFamilies = true;
  bool _loadingIngredients = false;
  String? _togglingId;
  String? _familiesError;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
    _loadFamilyStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────── data ─────────────────────────────

  Future<void> _loadFamilies() async {
    setState(() {
      _loadingFamilies = true;
      _familiesError = null;
    });
    try {
      final families = await _service.fetchFamilies();
      if (!mounted) return;
      setState(() {
        _families = families;
        _loadingFamilies = false;
        _activeFamily ??= families.isNotEmpty ? families.first.slug : null;
      });
      if (_activeFamily != null) _loadIngredients();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _familiesError = e.toString();
        _loadingFamilies = false;
      });
    }
  }

  Future<void> _loadFamilyStats() async {
    try {
      final stats = await _service.fetchFamilyStats();
      if (mounted) setState(() => _familyStats = stats);
    } catch (_) {
      // Badges are cosmetic: the page still works without them.
    }
  }

  Future<void> _loadIngredients() async {
    final family = _activeFamily;
    if (family == null) return;
    setState(() {
      _loadingIngredients = true;
      _ingredients = [];
    });
    try {
      final data = await _service.fetchIngredients(family: family);
      if (!mounted || _activeFamily != family) return;
      setState(() {
        _ingredients = data;
        _loadingIngredients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingIngredients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les ingrédients : $e')),
      );
    }
  }

  Future<void> _refreshAll() async {
    await _loadFamilies();
    await _loadFamilyStats();
  }

  void _selectFamily(String slug) {
    if (slug == _activeFamily) return;
    setState(() {
      _activeFamily = slug;
      _searchController.clear();
    });
    _loadIngredients();
  }

  Future<void> _toggleAvailability(Ingredient ing, String newAvailability) async {
    if (_togglingId != null) return;
    setState(() => _togglingId = ing.id);
    try {
      final updated = await _service.setAvailability(ing.id, newAvailability);
      if (!mounted) return;
      setState(() {
        _ingredients = _ingredients
            .map((i) => i.id == updated.id ? updated : i)
            .toList();
        _familyStats = _familyStats.map((s) {
          if (s.slug != _activeFamily) return s;
          final delta = newAvailability == 'available' ? -1 : 1;
          final next = (s.epuise + delta).clamp(0, s.total);
          return FamilyStat(slug: s.slug, total: s.total, epuise: next);
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _togglingId = null);
    }
  }

  Future<void> _openIngredientModal({Ingredient? ingredient, required bool mobile}) async {
    final result = await showIngredientModal(
      context,
      ingredient: ingredient,
      families: _families,
      defaultFamily: _activeFamily,
      mobile: mobile,
    );
    if (result == null) return;

    if (result.deletedId != null) {
      setState(() =>
          _ingredients = _ingredients.where((i) => i.id != result.deletedId).toList());
    } else if (result.ingredient != null) {
      final saved = result.ingredient!;
      setState(() {
        if (result.isNew) {
          if (saved.family == _activeFamily) _ingredients = [..._ingredients, saved];
        } else {
          _ingredients =
              _ingredients.map((i) => i.id == saved.id ? saved : i).toList();
        }
      });
    }
    _loadFamilyStats();
  }

  Future<void> _openFamilyModal({IngredientFamily? family, required bool mobile}) async {
    final result = await showFamilyModal(context, family: family, mobile: mobile);
    if (result == null) return;

    if (result.deletedId != null) {
      setState(() {
        _families = _families.where((f) => f.id != result.deletedId).toList();
        if (_activeFamily == family?.slug) {
          _activeFamily = _families.isNotEmpty ? _families.first.slug : null;
        }
      });
      if (_activeFamily != null) _loadIngredients();
    } else if (result.family != null) {
      final saved = result.family!;
      setState(() {
        if (result.isNew) {
          _families = [..._families, saved]
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          _activeFamily = saved.slug;
        } else {
          _families = _families.map((f) => f.id == saved.id ? saved : f).toList();
        }
      });
      if (result.isNew) _loadIngredients();
    }
  }

  // ─────────────────────────── computed ───────────────────────────

  List<Ingredient> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _ingredients;
    return _ingredients
        .where((i) =>
            i.name.toLowerCase().contains(q) ||
            (i.notes ?? '').toLowerCase().contains(q))
        .toList();
  }

  IngredientFamily? get _activeFamilyObj {
    for (final f in _families) {
      if (f.slug == _activeFamily) return f;
    }
    return null;
  }

  FamilyStat _statFor(String slug) {
    for (final s in _familyStats) {
      if (s.slug == slug) return s;
    }
    return const FamilyStat(slug: '', total: 0, epuise: 0);
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 900;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _buildHeader(mobile),
              _buildTitleBar(mobile),
              Expanded(child: _buildBody(mobile)),
              if (mobile) _buildMobileBulkButtons(),
              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool mobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 28, vertical: 13),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back, size: 13, color: AppColors.ink),
                  const SizedBox(width: 7),
                  Text(
                    "Retour à l'accueil",
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
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
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('🍔', style: TextStyle(fontSize: 14))),
          ),
          if (!mobile) ...[
            const SizedBox(width: 9),
            Text(
              'SPRINTKITCHEN',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: AppColors.ink),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(widget.posteLabel,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(bool mobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, mobile ? 14 : 18, mobile ? 16 : 28, mobile ? 12 : 14),
      color: AppColors.background,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DISPONIBILITÉ DES ARTICLES',
                  style: GoogleFonts.bebasNeue(
                      fontSize: mobile ? 28 : 34, letterSpacing: 0.6, color: AppColors.ink, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  'Activez ou désactivez les ingrédients en stock sur la caisse POS et les bornes en temps réel.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: mobile ? 220 : 300,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 15, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Rechercher un ingrédient…',
                          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _refreshAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 14, color: AppColors.ink),
                      if (!mobile) ...[
                        const SizedBox(width: 7),
                        Text('Actualiser',
                            style: GoogleFonts.inter(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool mobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 28, 12, mobile ? 14 : 28, 24),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMobileFamilyTabs(),
                const SizedBox(height: 12),
                _buildRightPanel(mobile: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebar(),
                const SizedBox(width: 16),
                Expanded(child: _buildRightPanel(mobile: false)),
              ],
            ),
    );
  }

  // ─────────────────────────── sidebar (desktop) ───────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              "FAMILLES D'INGRÉDIENTS",
              style: GoogleFonts.inter(
                  fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted),
            ),
          ),
          if (_loadingFamilies)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [for (final fam in _families) _buildSidebarRow(fam)],
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: InkWell(
              onTap: () => _openFamilyModal(mobile: false),
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                child: Row(
                  children: [
                    const Text('+', style: TextStyle(fontSize: 15, color: AppColors.muted)),
                    const SizedBox(width: 5),
                    Text('Nouvelle famille',
                        style: GoogleFonts.inter(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarRow(IngredientFamily fam) {
    final active = fam.slug == _activeFamily;
    final stat = _statFor(fam.slug);

    return InkWell(
      onTap: () => _selectFamily(fam.slug),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        child: active
            ? Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AppColors.brown, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Text(fam.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fam.name,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFFF5F0E6))),
                    ),
                    if (stat.epuise > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration:
                            BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(4)),
                        child: Text('${stat.total} articles',
                            style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    _editPencil(() => _openFamilyModal(family: fam, mobile: false)),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(fam.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fam.name,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                    ),
                    if (stat.epuise > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration:
                            BoxDecoration(color: _orangeChipBg, borderRadius: BorderRadius.circular(4)),
                        child: Text('${stat.epuise} épuisé',
                            style: GoogleFonts.inter(
                                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      )
                    else if (stat.total > 0)
                      Text('Tous dispo',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted)),
                    _editPencil(() => _openFamilyModal(family: fam, mobile: false)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _editPencil(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(Icons.edit_outlined, size: 14, color: AppColors.muted.withValues(alpha: 0.85)),
      ),
    );
  }

  // ─────────────────────────── family tabs (mobile) ───────────────────────────

  Widget _buildMobileFamilyTabs() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _families.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final fam = _families[i];
          final active = fam.slug == _activeFamily;
          final stat = _statFor(fam.slug);
          return InkWell(
            onTap: () => _selectFamily(fam.slug),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.brown : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: active ? null : Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fam.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    fam.name.split(' ').first,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? const Color(0xFFF5F0E6) : AppColors.ink,
                    ),
                  ),
                  if (stat.epuise > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration:
                          BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(3)),
                      child: Text('${stat.epuise}',
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── right panel ───────────────────────────

  Widget _buildRightPanel({required bool mobile}) {
    final filtered = _filtered;
    final dispoCount = filtered.where((i) => !i.isEpuise).length;
    final epuiseCount = filtered.where((i) => i.isEpuise).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(_activeFamilyObj?.emoji ?? '', style: const TextStyle(fontSize: 20)),
                    Text(
                      _activeFamilyObj?.name ?? '—',
                      style: GoogleFonts.bebasNeue(
                          fontSize: mobile ? 20 : 24, letterSpacing: 0.5, color: AppColors.ink),
                    ),
                    if (!_loadingIngredients && filtered.isNotEmpty)
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                          children: [
                            TextSpan(
                              text: '$dispoCount disponibles',
                              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                            ),
                            if (epuiseCount > 0)
                              TextSpan(
                                text: ' · $epuiseCount épuisés',
                                style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (!mobile)
                  InkWell(
                    onTap: () => _openIngredientModal(mobile: false),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text('+ Ajouter un ingrédient',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ),
                  ),
              ],
            ),
          ),
          if (_loadingIngredients)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(
                children: [
                  Text(_activeFamilyObj?.emoji ?? '', style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 10),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'Aucun ingrédient pour "${_searchController.text}"'
                        : 'Aucun ingrédient dans cette famille',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
                  ),
                  if (_searchController.text.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Cliquez sur "Ajouter un ingrédient" pour commencer',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted)),
                  ],
                ],
              ),
            )
          else
            for (var i = 0; i < filtered.length; i++)
              mobile
                  ? _buildMobileRow(filtered[i], isLast: i == filtered.length - 1)
                  : _buildDesktopRow(filtered[i], isLast: i == filtered.length - 1),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(Ingredient ing, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: ing.isEpuise ? _epuiseBg : AppColors.surface,
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: ing.isEpuise ? AppColors.red : const Color(0xFFB5B0A8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ing.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ing.isEpuise ? _dimText : AppColors.ink,
                    decoration: ing.isEpuise ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (ing.unit.isNotEmpty)
                  Text(
                    'Unité : ${ing.unit}${ing.notes != null && ing.notes!.isNotEmpty ? " · ${ing.notes}" : ""}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (ing.isEpuise)
            SizedBox(
              width: 140,
              child: ing.isBloque
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bloqué Caisse & Bne',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red)),
                        Text('Ingrédient bloqué',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted)),
                      ],
                    )
                  : Text(
                      ing.notes?.isNotEmpty == true ? ing.notes! : 'Rupture de stock',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
                    ),
            ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _openIngredientModal(ingredient: ing, mobile: false),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          _toggleButton(ing, mobile: false),
        ],
      ),
    );
  }

  Widget _buildMobileRow(Ingredient ing, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ing.isEpuise ? _epuiseBg : AppColors.surface,
        border: Border(
          bottom: isLast ? BorderSide.none : const BorderSide(color: AppColors.border),
          left: BorderSide(color: ing.isEpuise ? AppColors.red : Colors.transparent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ing.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    decoration: ing.isEpuise ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ing.isEpuise ? const Color(0xFFFDEAE8) : _greenBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  ing.isEpuise ? '86 ACTIF' : 'En vente',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: ing.isEpuise ? AppColors.red : _greenText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _openIngredientModal(ingredient: ing, mobile: true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(Icons.edit_outlined, size: 15, color: AppColors.muted),
                ),
              ),
            ],
          ),
          if (ing.unit.isNotEmpty || (ing.notes?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (ing.unit.isNotEmpty) 'Unité : ${ing.unit}',
                  if (ing.notes?.isNotEmpty ?? false) ing.notes!,
                ].join(' · '),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
              ),
            ),
          if (ing.isEpuise)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ing.isBloque
                  ? Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text('Bloqué Caisse & Bne',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red)),
                        Text('· Ingrédient bloqué',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.muted)),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration:
                          BoxDecoration(color: _orangeChipBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '⚠  ${ing.notes?.isNotEmpty == true ? ing.notes! : "Rupture de stock"}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.orange),
                      ),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _toggleButton(ing, mobile: true),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(Ingredient ing, {required bool mobile}) {
    final loading = _togglingId == ing.id;
    final epuise = ing.isEpuise;

    return InkWell(
      onTap: loading ? null : () => _toggleAvailability(ing, epuise ? 'available' : 'epuise'),
      borderRadius: BorderRadius.circular(mobile ? 9 : 8),
      child: Container(
        width: mobile ? double.infinity : null,
        constraints: mobile ? null : const BoxConstraints(minWidth: 148),
        padding: EdgeInsets.symmetric(horizontal: mobile ? 0 : 18, vertical: mobile ? 11 : 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: epuise ? AppColors.ink : _greenBg,
          borderRadius: BorderRadius.circular(mobile ? 9 : 8),
          border: (!epuise && mobile) ? Border.all(color: AppColors.green, width: 1.5) : null,
        ),
        child: Opacity(
          opacity: loading ? 0.6 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: epuise ? const Color(0xFFE03C31) : AppColors.green),
              const SizedBox(width: 8),
              Text(
                epuise
                    ? (mobile ? 'ÉPUISÉ — CAISSE & BORNES' : '× ÉPUISÉ')
                    : 'DISPONIBLE',
                style: GoogleFonts.inter(
                  fontSize: mobile ? 12.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: epuise ? Colors.white : _greenText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBulkButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openIngredientModal(mobile: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.brown,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('+ Ajouter un ingrédient',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openFamilyModal(mobile: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.muted,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('+ Nouvelle famille',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Connecté',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ],
          ),
          Text('SprintKitchen OS v2.4.0-PROD',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}