const Order = require('../models/Order');
const Payment = require('../models/Payment');

// @desc  Get orders (with filters & date range)
// @route GET /api/orders
exports.getOrders = async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.registerId) filter.registerId = req.query.registerId;
    if (req.query.status) filter.status = req.query.status;
    if (req.query.orderType) filter.orderType = req.query.orderType;

    // Date range filter (from Order History)
    if (req.query.from || req.query.to) {
      filter.createdAt = {};
      if (req.query.from) filter.createdAt.$gte = new Date(req.query.from);
      if (req.query.to) {
        const to = new Date(req.query.to);
        to.setHours(23, 59, 59, 999);
        filter.createdAt.$lte = to;
      }
    }

    // Search by ticket number or client name
    if (req.query.search) {
      filter.$or = [
        { ticketNumber: { $regex: req.query.search, $options: 'i' } },
        { clientName: { $regex: req.query.search, $options: 'i' } },
      ];
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const [orders, total] = await Promise.all([
      Order.find(filter)
        .populate('registerId', 'name type')
        .populate('operatorId', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Order.countDocuments(filter),
    ]);

    res.json({
      success: true,
      count: orders.length,
      total,
      totalPages: Math.ceil(total / limit),
      page,
      data: orders,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get single order
// @route GET /api/orders/:id
exports.getOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('registerId', 'name type')
      .populate('operatorId', 'name')
      .populate('customerId', 'fullName phone')
      .populate('items.productId', 'name basePrice');
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Create new order (open ticket)
// @route POST /api/orders
exports.createOrder = async (req, res) => {
  try {
    const order = new Order(req.body);
    order.recalculateTotals();
    await order.save();
    res.status(201).json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update order (add items, change status, etc.)
// @route PUT /api/orders/:id
exports.updateOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    Object.assign(order, req.body);
    if (req.body.items) order.recalculateTotals();

    await order.save();
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update order status
// @route PATCH /api/orders/:id/status
exports.updateStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    order.status = status;
    if (status === 'terminee') order.completedAt = new Date();
    if (status === 'annulee') {
      order.cancelledAt = new Date();
      order.cancelReason = req.body.cancelReason;
    }
    // Send to KDS
    if (status === 'en_attente') {
      order.kdsStatus = 'pending';
      order.kdsSentAt = new Date();
    }
    await order.save();
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Cancel / refund order
// @route PATCH /api/orders/:id/cancel
exports.cancelOrder = async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { status: 'annulee', cancelledAt: new Date(), cancelReason: req.body.reason },
      { new: true }
    );
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get daily summary stats
// @route GET /api/orders/stats/daily
exports.getDailyStats = async (req, res) => {
  try {
    const date = req.query.date ? new Date(req.query.date) : new Date();
    const start = new Date(date.setHours(0, 0, 0, 0));
    const end = new Date(date.setHours(23, 59, 59, 999));
    const storeId = req.query.storeId;

    const filter = { createdAt: { $gte: start, $lte: end }, status: 'terminee' };
    if (storeId) filter.storeId = storeId;

    const stats = await Order.aggregate([
      { $match: filter },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          totalRevenue: { $sum: '$totalTTC' },
          avgOrderValue: { $avg: '$totalTTC' },
          surPlace: { $sum: { $cond: [{ $eq: ['$orderType', 'sur_place'] }, 1, 0] } },
          aEmporter: { $sum: { $cond: [{ $eq: ['$orderType', 'a_emporter'] }, 1, 0] } },
          livraison: { $sum: { $cond: [{ $eq: ['$orderType', 'livraison'] }, 1, 0] } },
        },
      },
    ]);

    res.json({ success: true, data: stats[0] || { totalOrders: 0, totalRevenue: 0 } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
