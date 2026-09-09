const Product = require('../models/Product');
const StockLog = require('../models/StockLog');

// @desc  Get all products (with optional filters)
// @route GET /api/products
exports.getProducts = async (req, res) => {
  try {
    const filter = {};
    if (req.query.categoryId) filter.categoryId = req.query.categoryId;
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.availability) filter.availability = req.query.availability;
    if (req.query.isActive !== undefined) filter.isActive = req.query.isActive === 'true';

    const products = await Product.find(filter)
      .populate('categoryId', 'name slug')
      .sort('displayOrder');
    res.json({ success: true, count: products.length, data: products });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get single product
// @route GET /api/products/:id
exports.getProduct = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id).populate('categoryId', 'name slug');
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, data: product });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Create product
// @route POST /api/products
exports.createProduct = async (req, res) => {
  try {
    const product = await Product.create(req.body);
    res.status(201).json({ success: true, data: product });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update product
// @route PUT /api/products/:id
exports.updateProduct = async (req, res) => {
  try {
    const product = await Product.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, data: product });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Toggle product availability (86 list management)
// @route PATCH /api/products/:id/availability
exports.updateAvailability = async (req, res) => {
  try {
    const { availability, notes } = req.body;
    const product = await Product.findById(req.params.id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    const previousStatus = product.availability;
    product.availability = availability;
    product.isOnList86 = availability !== 'available';
    await product.save();

    // Log the stock change
    await StockLog.create({
      productId: product._id,
      storeId: product.storeId,
      action: availability,
      previousStatus,
      operatorId: req.user?.id,
      notes,
    });

    res.json({ success: true, data: product });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Bulk toggle all products in a category
// @route PATCH /api/products/bulk-availability
exports.bulkAvailability = async (req, res) => {
  try {
    const { categoryId, availability } = req.body;
    await Product.updateMany({ categoryId }, { availability, isOnList86: availability !== 'available' });
    res.json({ success: true, message: `All products in category set to ${availability}` });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Delete product (soft)
// @route DELETE /api/products/:id
exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByIdAndUpdate(req.params.id, { isActive: false }, { new: true });
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, message: 'Product deactivated' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
