const express = require('express');
const router = express.Router();
const {
  getOrders, getOrder, createOrder, updateOrder,
  updateStatus, cancelOrder, getDailyStats,
} = require('../controllers/orderController');
const protect = require('../middleware/auth');

router.get('/stats/daily', protect, getDailyStats);
router.get('/', protect, getOrders);
router.post('/', protect, createOrder);
router.get('/:id', protect, getOrder);
router.put('/:id', protect, updateOrder);
router.patch('/:id/status', protect, updateStatus);
router.patch('/:id/cancel', protect, cancelOrder);

module.exports = router;
