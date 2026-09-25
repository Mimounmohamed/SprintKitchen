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

app.use('/api/kds',               require('./routes/kds'));

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
