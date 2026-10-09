const Ingredient = require('../models/Ingredient');

/* GET /api/ingredients?family=viandes&search=steak&limit=20 */
exports.getIngredients = async (req, res, next) => {
  try {
    const filter = { isActive: true };
    if (req.query.family)       filter.family       = req.query.family;
    if (req.query.storeId)      filter.storeId      = req.query.storeId;
    if (req.query.availability) filter.availability = req.query.availability;
    if (req.query.search) {
      filter.name = { $regex: req.query.search, $options: 'i' };
    }

    const limit = parseInt(req.query.limit) || 200;
    const data  = await Ingredient.find(filter).sort('family displayOrder name').limit(limit);
    res.json({ success: true, count: data.length, data });
  } catch (err) { next(err); }
};

/* GET /api/ingredients/families — list of families with épuisé counts */
exports.getFamilies = async (req, res, next) => {
  try {
    const filter = { isActive: true };
    if (req.query.storeId) filter.storeId = req.query.storeId;

    const counts = await Ingredient.aggregate([
      { $match: filter },
      { $group: {
        _id:      '$family',
        total:    { $sum: 1 },
        epuise:   { $sum: { $cond: [{ $ne: ['$availability', 'available'] }, 1, 0] } },
      }},
      { $sort: { _id: 1 } },
    ]);
    res.json({ success: true, data: counts });
  } catch (err) { next(err); }
};

/* GET /api/ingredients/:id */
exports.getIngredient = async (req, res, next) => {
  try {
    const item = await Ingredient.findById(req.params.id);
    if (!item) return res.status(404).json({ success: false, message: 'Ingredient not found' });
    res.json({ success: true, data: item });
  } catch (err) { next(err); }
};

const escapeRegex = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/* POST /api/ingredients */
exports.createIngredient = async (req, res, next) => {
  try {
    const name = req.body.name ? req.body.name.trim() : '';
    if (!name) {
      return res.status(400).json({ success: false, message: "Le nom de l'ingrédient est requis." });
    }

    const existingFilter = {
      name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
      isActive: true,
    };
    if (req.body.storeId) existingFilter.storeId = req.body.storeId;

    const existing = await Ingredient.findOne(existingFilter);
    if (existing) {
      return res.status(400).json({
        success: false,
        message: 'Un ingrédient avec ce nom existe déjà.',
      });
    }

    // Check if an inactive ingredient exists with the same name, reactivate it if so
    const inactiveFilter = {
      name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
      isActive: false,
    };
    if (req.body.storeId) inactiveFilter.storeId = req.body.storeId;
    const inactive = await Ingredient.findOne(inactiveFilter);
    if (inactive) {
      Object.assign(inactive, req.body, { name, isActive: true });
      await inactive.save();
      return res.status(201).json({ success: true, data: inactive });
    }

    req.body.name = name;
    const item = await Ingredient.create(req.body);
    res.status(201).json({ success: true, data: item });
  } catch (err) { next(err); }
};

/* PUT /api/ingredients/:id */
exports.updateIngredient = async (req, res, next) => {
  try {
    if (req.body.name) {
      const name = req.body.name.trim();
      if (!name) {
        return res.status(400).json({ success: false, message: "Le nom de l'ingrédient est requis." });
      }

      const existingFilter = {
        _id: { $ne: req.params.id },
        name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
        isActive: true,
      };
      if (req.body.storeId) existingFilter.storeId = req.body.storeId;

      const existing = await Ingredient.findOne(existingFilter);
      if (existing) {
        return res.status(400).json({
          success: false,
          message: 'Un ingrédient avec ce nom existe déjà.',
        });
      }
      req.body.name = name;
    }

    const item = await Ingredient.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!item) return res.status(404).json({ success: false, message: 'Ingredient not found' });
    res.json({ success: true, data: item });
  } catch (err) { next(err); }
};

/* PATCH /api/ingredients/:id/availability */
exports.updateAvailability = async (req, res, next) => {
  try {
    const { availability, notes } = req.body;
    if (!['available', 'epuise', 'bloque'].includes(availability)) {
      return res.status(400).json({ success: false, message: 'Invalid availability value' });
    }
    const item = await Ingredient.findById(req.params.id);
    if (!item) return res.status(404).json({ success: false, message: 'Ingredient not found' });

    item.availability = availability;
    item.isOnList86   = availability !== 'available';
    if (notes !== undefined) item.notes = notes;
    await item.save();

    res.json({ success: true, data: item });
  } catch (err) { next(err); }
};

/* PATCH /api/ingredients/bulk-availability */
exports.bulkAvailability = async (req, res, next) => {
  try {
    const { family, storeId, availability } = req.body;
    if (!['available', 'epuise', 'bloque'].includes(availability)) {
      return res.status(400).json({ success: false, message: 'Invalid availability value' });
    }
    const filter = {};
    if (family)  filter.family  = family;
    if (storeId) filter.storeId = storeId;
    await Ingredient.updateMany(filter, { availability, isOnList86: availability !== 'available' });
    res.json({ success: true, message: `All ingredients set to ${availability}` });
  } catch (err) { next(err); }
};

/* DELETE /api/ingredients/:id (soft) */
exports.deleteIngredient = async (req, res, next) => {
  try {
    await Ingredient.findByIdAndUpdate(req.params.id, { isActive: false });
    res.json({ success: true, message: 'Ingredient deactivated' });
  } catch (err) { next(err); }
};
