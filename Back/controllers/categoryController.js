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

// @desc  Create category
// @route POST /api/categories
exports.createCategory = async (req, res) => {
  try {
    const cat = await Category.create(req.body);
    res.status(201).json({ success: true, data: cat });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update category
// @route PUT /api/categories/:id
exports.updateCategory = async (req, res) => {
  try {
    const cat = await Category.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!cat) return res.status(404).json({ success: false, message: 'Category not found' });
    res.json({ success: true, data: cat });
  } catch (err) {
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
