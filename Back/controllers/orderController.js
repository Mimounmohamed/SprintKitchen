const Order = require('../models/Order');
const Payment = require('../models/Payment');
const Store = require('../models/Store');

// Escape user input before using it inside a RegExp (a lone "(" would crash).
const escapeRegex = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Normalize table identifier (e.g. "Table 5" -> "5", "  5 " -> "5")
const normalizeTableNumber = (val) => {
  if (!val) return null;
  const s = String(val).trim();
  if (!s) return null;
  const match = s.match(/^table\s*(.+)$/i);
  if (match) return match[1].trim();
  if (/^buzzer/i.test(s)) return null;
  return s;
};

// Builds a createdAt range from ?from & ?to.
// - Date-only values ("2026-09-07") mean the whole day (UTC).
// - Full ISO timestamps are used exactly as sent, so the client can send
//   its own local start / end of day.
const buildDateRange = (from, to) => {
  if (!from && !to) return null;
  const range = {};
  if (from) range.$gte = new Date(from);
  if (to) {
    const end = new Date(to);
    if (/^\d{4}-\d{2}-\d{2}$/.test(to)) end.setUTCHours(23, 59, 59, 999);
    range.$lte = end;
  }
  return range;
};

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
    const range = buildDateRange(req.query.from, req.query.to);
    if (range) filter.createdAt = range;

    // Search by ticket number or client name
    if (req.query.search) {
      const term = escapeRegex(req.query.search);
      filter.$or = [
        { ticketNumber: { $regex: term, $options: 'i' } },
        { clientName: { $regex: term, $options: 'i' } },
        { buzzerNumber: { $regex: term, $options: 'i' } },
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

// @desc  Order counts per status + revenue of paid orders (History tabs)
// @route GET /api/orders/summary?from=&to=
exports.getOrdersSummary = async (req, res) => {
  try {
    const match = {};
    const range = buildDateRange(req.query.from, req.query.to);
    if (range) match.createdAt = range;

    const rows = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          total: { $sum: '$totalTTC' },
        },
      },
    ]);

    const counts = {
      en_cours: 0,
      en_attente: 0,
      a_encaisser: 0,
      terminee: 0,
      repas_employe: 0,
      annulee: 0,
    };
    let totalTerminee = 0;
    rows.forEach((r) => {
      counts[r._id] = r.count;
      if (r._id === 'terminee' || r._id === 'en_attente') totalTerminee += r.total;
    });

    res.json({
      success: true,
      data: { counts, totalTerminee: parseFloat(totalTerminee.toFixed(2)) },
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
      .populate('items.productId', 'name basePrice ingredients description categoryId kdsStation');
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Create new order (open ticket)
// @route POST /api/orders
// No login on this install: if the client doesn't send a storeId, we use
// the (single) store stored in the database.
exports.createOrder = async (req, res) => {
  try {
    const data = { ...req.body };

    if (!data.storeId) {
      const store = await Store.findOne();
      if (!store) {
        return res
          .status(400)
          .json({ success: false, message: 'Aucun magasin configuré' });
      }
      data.storeId = store._id;
    }

    // Check table occupancy if order is linked to a table
    const rawTable = data.tableNumber || (data.orderType === 'sur_place' ? data.buzzerNumber : null);
    const table = normalizeTableNumber(rawTable);
    if (table) {
      data.tableNumber = table;
      if (!data.buzzerNumber) {
        data.buzzerNumber = `Table ${table}`;
      }

      const occupiedOrder = await Order.findOne({
        storeId: data.storeId,
        status: { $nin: ['terminee', 'annulee'] },
        kdsStatus: { $ne: 'served' },
        $or: [
          { tableNumber: table },
          { buzzerNumber: `Table ${table}` },
          { buzzerNumber: table },
          { buzzerNumber: new RegExp(`^Table\\s*${escapeRegex(table)}$`, 'i') },
        ],
      });

      if (occupiedOrder) {
        return res.status(400).json({
          success: false,
          message: `La table ${table} est déjà liée à une commande active (#${occupiedOrder.ticketNumber || occupiedOrder._id}). Elle ne peut pas être réutilisée tant que cette commande n'est pas marquée terminée.`,
          occupiedTable: table,
          activeTicketNumber: occupiedOrder.ticketNumber,
        });
      }
    }

    const order = new Order(data);
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

    // Validate table if updating tableNumber or buzzerNumber
    const rawTable = req.body.tableNumber !== undefined
      ? req.body.tableNumber
      : (req.body.buzzerNumber !== undefined ? req.body.buzzerNumber : null);

    if (rawTable !== null) {
      const table = normalizeTableNumber(rawTable);
      if (table) {
        const targetStatus = req.body.status || order.status;
        if (!['terminee', 'annulee'].includes(targetStatus)) {
          const occupiedOrder = await Order.findOne({
            _id: { $ne: order._id },
            storeId: order.storeId,
            status: { $nin: ['terminee', 'annulee'] },
            kdsStatus: { $ne: 'served' },
            $or: [
              { tableNumber: table },
              { buzzerNumber: `Table ${table}` },
              { buzzerNumber: table },
              { buzzerNumber: new RegExp(`^Table\\s*${escapeRegex(table)}$`, 'i') },
            ],
          });

          if (occupiedOrder) {
            return res.status(400).json({
              success: false,
              message: `La table ${table} est déjà liée à une commande active (#${occupiedOrder.ticketNumber || occupiedOrder._id}). Elle ne peut pas être réutilisée tant que cette commande n'est pas marquée terminée.`,
              occupiedTable: table,
              activeTicketNumber: occupiedOrder.ticketNumber,
            });
          }
        }
        req.body.tableNumber = table;
      }
    }

    Object.assign(order, req.body);
    if (req.body.items) order.recalculateTotals();

    // Flag order as edited whenever updated from POS/history
    order.isEdited = true;
    order.editedAt = new Date();

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
    if (status === 'terminee') {
      order.completedAt = new Date();
      order.kdsStatus = 'served';
    }
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

    const filter = { createdAt: { $gte: start, $lte: end }, status: { $in: ['terminee', 'en_attente'] } };
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

// @desc  Get list of currently occupied tables (active orders not yet terminee)
// @route GET /api/orders/occupied-tables
exports.getOccupiedTables = async (req, res) => {
  try {
    const filter = {
      status: { $nin: ['terminee', 'annulee'] },
      kdsStatus: { $ne: 'served' },
    };
    if (req.query.storeId) filter.storeId = req.query.storeId;

    const orders = await Order.find(filter)
      .select('ticketNumber tableNumber buzzerNumber createdAt totalTTC clientName status kdsStatus')
      .sort({ createdAt: -1 });

    const occupied = [];
    const seenTables = new Set();

    for (const o of orders) {
      const tbl = normalizeTableNumber(o.tableNumber || o.buzzerNumber);
      if (tbl && !seenTables.has(tbl.toLowerCase())) {
        seenTables.add(tbl.toLowerCase());
        occupied.push({
          tableNumber: tbl,
          ticketNumber: o.ticketNumber || '',
          orderId: o._id,
          createdAt: o.createdAt,
          clientName: o.clientName || '',
          status: o.status,
        });
      }
    }

    res.json({
      success: true,
      data: occupied,
      tables: occupied.map((o) => o.tableNumber),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};