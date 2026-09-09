const express = require('express');
const router = express.Router();
const { getStockLogs, getStockOverview } = require('../controllers/stockController');
const protect = require('../middleware/auth');

router.get('/overview', protect, getStockOverview);
router.get('/logs', protect, getStockLogs);

module.exports = router;
