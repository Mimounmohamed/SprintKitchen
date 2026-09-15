const express = require('express');
const router  = express.Router();
const { getDashboardKpis } = require('../controllers/dashboardController');
const protect = require('../middleware/auth');

// GET /api/dashboard — protected
router.get('/', protect, getDashboardKpis);

module.exports = router;
