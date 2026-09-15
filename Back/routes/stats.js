const express = require('express');
const router  = express.Router();
const {
  getRapportZ,
  getSalesByHour,
  getTopProducts,
  getByChannel,
  getSalesTrend,
  getKpis,
  getPaymentMethods,
  getSummary,
} = require('../controllers/statsController');
const protect = require('../middleware/auth');

// All routes protected
router.get('/rapport-z',       protect, getRapportZ);
router.get('/sales-by-hour',   protect, getSalesByHour);
router.get('/top-products',    protect, getTopProducts);
router.get('/by-channel',      protect, getByChannel);
router.get('/sales-trend',     protect, getSalesTrend);
router.get('/kpis',            protect, getKpis);
router.get('/payment-methods', protect, getPaymentMethods);
router.get('/summary',         protect, getSummary);   // one-shot for the stats page

module.exports = router;
