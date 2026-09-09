const StockLog = require('../models/StockLog');
const Product = require('../models/Product');

// @desc  Get stock log history for a store
// @route GET /api/stock/logs
exports.getStockLogs = async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.productId) filter.productId = req.query.productId;

    const logs = await StockLog.find(filter)
      .populate('productId', 'name basePrice')
      .populate('operatorId', 'name')
      .sort({ createdAt: -1 })
      .limit(100);
    res.json({ success: true, count: logs.length, data: logs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get all products with their availability (stock overview page)
// @route GET /api/stock/overview
exports.getStockOverview = async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.categoryId) filter.categoryId = req.query.categoryId;

    const products = await Product.find(filter)
      .populate('categoryId', 'name')
      .select('name description availability isOnList86 blockedOnCaisse blockedOnBorne categoryId basePrice')
      .sort('categoryId displayOrder');

    const summary = {
      total: products.length,
      available: products.filter(p => p.availability === 'available').length,
      epuise: products.filter(p => p.availability === 'epuise').length,
      bloque: products.filter(p => p.availability === 'bloque_caisse_borne').length,
    };

    res.json({ success: true, summary, data: products });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
