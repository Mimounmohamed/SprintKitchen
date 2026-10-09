const Category = require('../models/Category');

// @desc  Get all categories
// @route GET /api/categories
exports.getCategories = async (req, res) => {
  try {
    const filter = { isActive: true };
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const categories = await Category.find(filter).sort('displayOrder');
    res.json({ success: true, count: categories.length, data: categories });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get single category
// @route GET /api/categories/:id
exports.getCategory = async (req, res) => {
  try {
    const cat = await Category.findById(req.params.id);
    if (!cat) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, data: cat });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

const escapeRegex = (str) => str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// @desc  Create category
// @route POST /api/categories
exports.createCategory = async (req, res) => {
  try {
    const name = req.body.name ? req.body.name.trim() : '';
    if (!name) {
      return res.status(400).json({ success: false, message: 'Le nom de la catégorie est requis.' });
    }

    const existingFilter = {
      name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
      isActive: true,
    };
    if (req.body.storeId) existingFilter.storeId = req.body.storeId;

    const existing = await Category.findOne(existingFilter);
    if (existing) {
      return res.status(400).json({ success: false, message: 'Une catégorie avec ce nom existe déjà.' });
    }

    // Check if an inactive category exists with the same name, reactivate it if so
    const inactiveFilter = {
      name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
      isActive: false,
    };
    if (req.body.storeId) inactiveFilter.storeId = req.body.storeId;
    const inactive = await Category.findOne(inactiveFilter);
    if (inactive) {
      Object.assign(inactive, req.body, { name, isActive: true });
      await inactive.save();
      return res.status(201).json({ success: true, data: inactive });
    }

    req.body.name = name;
    const cat = await Category.create(req.body);
    res.status(201).json({ success: true, data: cat });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(400).json({ success: false, message: 'Une catégorie avec ce nom existe déjà.' });
    }
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update category
// @route PUT /api/categories/:id
exports.updateCategory = async (req, res) => {
  try {
    if (req.body.name) {
      const name = req.body.name.trim();
      if (!name) {
        return res.status(400).json({ success: false, message: 'Le nom de la catégorie est requis.' });
      }

      const existingFilter = {
        _id: { $ne: req.params.id },
        name: { $regex: new RegExp(`^${escapeRegex(name)}$`, 'i') },
        isActive: true,
      };
      if (req.body.storeId) existingFilter.storeId = req.body.storeId;

      const existing = await Category.findOne(existingFilter);
      if (existing) {
        return res.status(400).json({ success: false, message: 'Une catégorie avec ce nom existe déjà.' });
      }
      req.body.name = name;
    }

    const cat = await Category.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!cat) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, data: cat });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(400).json({ success: false, message: 'Une catégorie avec ce nom existe déjà.' });
    }
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Delete category (soft)
// @route DELETE /api/categories/:id
exports.deleteCategory = async (req, res) => {
  try {
    const cat = await Category.findByIdAndUpdate(req.params.id, { isActive: false }, { new: true });
    if (!cat) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, message: 'Category deactivated' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
