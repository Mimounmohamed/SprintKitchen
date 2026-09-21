const express = require('express');
const router = express.Router();
const {
  getOrders, getOrdersSummary, getOrder, createOrder, updateOrder,
  updateStatus, cancelOrder, getDailyStats,
} = require('../controllers/orderController');

// NOTE: fixed paths (/stats/daily, /summary) must stay above '/:id'.
router.get('/stats/daily', getDailyStats);
router.get('/summary', getOrdersSummary);
router.get('/', getOrders);
router.post('/', createOrder);
router.get('/:id', getOrder);
router.put('/:id', updateOrder);
router.patch('/:id/status', updateStatus);
router.patch('/:id/cancel', cancelOrder);

module.exports = router;