require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');
const errorHandler = require('./middleware/errorHandler');

// ── Connect Database ──────────────────────────────────────────────────────────
connectDB();

const app = express();

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: '🍔 SprintKitchen API is running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth',              require('./routes/auth'));
app.use('/api/stores',            require('./routes/stores'));
app.use('/api/registers',         require('./routes/registers'));
app.use('/api/categories',        require('./routes/categories'));
app.use('/api/products',          require('./routes/products'));
app.use('/api/orders',            require('./routes/orders'));
app.use('/api/customers',         require('./routes/customers'));
app.use('/api/payments',          require('./routes/payments'));
app.use('/api/stock',             require('./routes/stock'));
app.use('/api/stats',             require('./routes/stats'));
app.use('/api/ingredients',       require('./routes/ingredients'));
app.use('/api/dashboard',         require('./routes/dashboard'));
app.use('/api/ingredient-families', require('./routes/ingredientFamilies'));

// ── KDS (inline — no external file needed) ───────────────────────────────────
const Order = require('./models/Order');

app.get('/api/kds/orders', async (req, res) => {
  try {
    const now   = new Date();
    const start = new Date(now); start.setHours(0, 0, 0, 0);
    const end   = new Date(now); end.setHours(23, 59, 59, 999);
    const orders = await Order.find({
      status:    { $in: ['en_attente', 'a_encaisser'] },
      createdAt: { $gte: start, $lte: end },
    })
      .select('ticketNumber orderType status kdsStatus kdsSentAt items notes createdAt clientName buzzerNumber')
      .sort({ createdAt: 1 })
      .limit(60);
    res.json({ success: true, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.patch('/api/kds/orders/:id/kds-status', async (req, res) => {
  try {
    const { kdsStatus } = req.body;
    if (!['in_progress', 'ready', 'served'].includes(kdsStatus)) {
      return res.status(400).json({ success: false, message: 'Invalid kdsStatus' });
    }
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    order.kdsStatus = kdsStatus;
    if (kdsStatus === 'ready')  { order.kdsReadyAt = new Date(); order.status = 'a_encaisser'; }
    if (kdsStatus === 'served') { order.status = 'terminee'; order.completedAt = new Date(); }
    await order.save();
    res.json({ success: true, data: { _id: order._id, kdsStatus: order.kdsStatus, status: order.status } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start server ──────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 SprintKitchen API running on http://localhost:${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV}`);
});

module.exports = app;
