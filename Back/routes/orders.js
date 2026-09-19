const express = require('express');
const router = express.Router();
const {
  getOrders, getOrder, createOrder, updateOrder,
  updateStatus, cancelOrder, getDailyStats,
} = require('../controllers/orderController');

router.get('/stats/daily', getDailyStats);
router.get('/', getOrders);
router.post('/', createOrder);
router.get('/:id', getOrder);
router.put('/:id', updateOrder);
router.patch('/:id/status', updateStatus);
router.patch('/:id/cancel', cancelOrder);

module.exports = router;