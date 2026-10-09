import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_models.dart';
import '../services/inventory_service.dart';
import '../theme/app_colors.dart';
import '../widgets/inventory/ingredient_modal.dart';

/// "Disponibilité des articles" — availability toggling for ingredients,
/// grouped by family. Cashier can only add ingredients and mark them unavailable / available.
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
            "BOBO'S",
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              letterSpacing: 1.5,
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

  Widget _buildTitleBar(bool mobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 20, mobile ? 16 : 32, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DISPONIBILITÉ DES ARTICLES',
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
                    'SYNCHRONISÉ POS & BORNES',
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
              Text(
                'DISPONIBILITÉ DES ARTICLES',
                style: GoogleFonts.bebasNeue(
                  fontSize: mobile ? 28 : 34,
                  letterSpacing: 0.5,
                  color: const Color(0xFF111827),
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Activez ou désactivez les ingrédients en stock sur la caisse POS et les bornes en temps réel.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                width: mobile ? 200 : 260,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF1F2937)),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Rechercher un ingrédient…',
                          hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _refreshAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 14, color: Color(0xFF374151)),
                      if (!mobile) ...[
                        const SizedBox(width: 7),
                        const Text(
                          'Actualiser',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openIngredientModal(mobile: mobile),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEAB308)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Color(0xFF1F2937)),
                      SizedBox(width: 6),
                      Text(
                        'Ajouter un ingrédient',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
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
    if (_familiesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text('Erreur de chargement: $_familiesError',
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _refreshAll,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 32, 20, mobile ? 16 : 32, 24),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMobileFamilyTabs(),
                const SizedBox(height: 14),
                _buildRightPanel(mobile: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebar(),
                const SizedBox(width: 20),
                Expanded(child: _buildRightPanel(mobile: false)),
              ],
            ),
    );
  }

  // ─────────────────────────── sidebar (desktop) ───────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Text(
              "FAMILLES D'INGRÉDIENTS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          if (_loadingFamilies)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [for (final fam in _families) _buildSidebarRow(fam)],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: active
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF583926),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(fam.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fam.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5F0E6),
                        ),
                      ),
                    ),
                    if (stat.epuise > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9720C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${stat.epuise} épuisé',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Text(fam.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fam.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    if (stat.epuise > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF0E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${stat.epuise} épuisé',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD9720C),
                          ),
                        ),
                      )
                    else if (stat.total > 0)
                      const Text(
                        'Tous dispo',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ─────────────────────────── family tabs (mobile) ───────────────────────────

  Widget _buildMobileFamilyTabs() {
    return SizedBox(
      height: 36,
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
                color: active ? const Color(0xFF583926) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: active ? null : Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fam.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    fam.name.split(' ').first,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? const Color(0xFFF5F0E6) : const Color(0xFF1F2937),
                    ),
                  ),
                  if (stat.epuise > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9720C),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${stat.epuise}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          fontSize: mobile ? 20 : 24, letterSpacing: 0.5, color: const Color(0xFF111827)),
                    ),
                    if (!_loadingIngredients && filtered.isNotEmpty)
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          children: [
                            TextSpan(
                              text: '$dispoCount disponibles',
                              style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600),
                            ),
                            if (epuiseCount > 0)
                              TextSpan(
                                text: ' · $epuiseCount épuisés',
                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                  ],
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
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  if (_searchController.text.isEmpty) ...[
                    const SizedBox(height: 6),
                    const Text('Cliquez sur "Ajouter un ingrédient" pour commencer',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: ing.isEpuise ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
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
                    color: ing.isEpuise ? _dimText : const Color(0xFF111827),
                    decoration: ing.isEpuise ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (ing.unit.isNotEmpty)
                  Text(
                    'Unité : ${ing.unit}${ing.notes != null && ing.notes!.isNotEmpty ? " · ${ing.notes}" : ""}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
              ],
            ),
          ),
          if (ing.isEpuise)
            SizedBox(
              width: 140,
              child: ing.isBloque
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bloqué Caisse & Bne',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        Text('Ingrédient bloqué',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    )
                  : Text(
                      ing.notes?.isNotEmpty == true ? ing.notes! : 'Rupture de stock',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
            ),
          const SizedBox(width: 12),
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
          bottom: isLast ? BorderSide.none : const BorderSide(color: Color(0xFFE5E7EB)),
          left: BorderSide(color: ing.isEpuise ? const Color(0xFFEF4444) : Colors.transparent, width: 3),
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
                    color: const Color(0xFF111827),
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
                    color: ing.isEpuise ? const Color(0xFFEF4444) : _greenText,
                  ),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          if (ing.isEpuise)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ing.isBloque
                  ? const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text('Bloqué Caisse & Bne',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        Text('· Ingrédient bloqué',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration:
                          BoxDecoration(color: _orangeChipBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '⚠  ${ing.notes?.isNotEmpty == true ? ing.notes! : "Rupture de stock"}',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFD9720C)),
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
          color: epuise ? const Color(0xFF1C1917) : _greenBg,
          borderRadius: BorderRadius.circular(mobile ? 9 : 8),
          border: (!epuise && mobile) ? Border.all(color: const Color(0xFF059669), width: 1.5) : null,
        ),
        child: Opacity(
          opacity: loading ? 0.6 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: epuise ? const Color(0xFFE03C31) : const Color(0xFF059669)),
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _openIngredientModal(mobile: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFACC15),
            foregroundColor: const Color(0xFF1F2937),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 6),
              Text(
                'Ajouter un ingrédient',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Connecté',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
            ],
          ),
          Text("Bobo's OS v1.00",
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }
}