const IngredientFamily = require('../models/IngredientFamily');
const Ingredient       = require('../models/Ingredient');

/* slugify helper */
const slugify = (s) =>
  s.toLowerCase()
   .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
   .replace(/[^a-z0-9]+/g, '_')
   .replace(/^_|_$/g, '');

/* GET /api/ingredient-families */
exports.getFamilies = async (req, res, next) => {
  try {
    const data = await IngredientFamily.find({ isActive: true }).sort('displayOrder name');
    res.json({ success: true, count: data.length, data });
  } catch (err) { next(err); }
};

/* POST /api/ingredient-families */
exports.createFamily = async (req, res, next) => {
  try {
    const { name, emoji, displayOrder } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'name is required' });

    let baseSlug = slugify(name);
    let slug     = baseSlug;
    let counter  = 1;
    // Deduplicate slug
    while (await IngredientFamily.findOne({ slug })) {
      slug = `${baseSlug}_${counter++}`;
    }

    const family = await IngredientFamily.create({
      name,
      slug,
      emoji:        emoji        || '📦',
      displayOrder: displayOrder ?? 0,
    });
    res.status(201).json({ success: true, data: family });
  } catch (err) { next(err); }
};

/* PUT /api/ingredient-families/:id */
exports.updateFamily = async (req, res, next) => {
  try {
    const family = await IngredientFamily.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    if (!family) return res.status(404).json({ success: false, message: 'Family not found' });
    res.json({ success: true, data: family });
  } catch (err) { next(err); }
};

/* DELETE /api/ingredient-families/:id — soft delete, guard against active ingredients */
exports.deleteFamily = async (req, res, next) => {
  try {
    const family = await IngredientFamily.findById(req.params.id);
    if (!family) return res.status(404).json({ success: false, message: 'Family not found' });

    // Check if any active ingredients still reference this slug
    const activeCount = await Ingredient.countDocuments({ family: family.slug, isActive: true });
    if (activeCount > 0) {
      return res.status(400).json({
        success: false,
        message: `Impossible de supprimer : ${activeCount} ingrédient(s) actif(s) utilisent cette famille. Supprimez-les d'abord.`,
      });
    }

    family.isActive = false;
    await family.save();
    res.json({ success: true, message: 'Family deactivated' });
  } catch (err) { next(err); }
};
