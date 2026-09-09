const express = require('express');
const router = express.Router();
const {
  createPayment, getPaymentByOrder, refundPayment,
} = require('../controllers/paymentController');
const protect = require('../middleware/auth');

router.post('/', protect, createPayment);
router.get('/order/:orderId', protect, getPaymentByOrder);
router.patch('/:id/refund', protect, refundPayment);

module.exports = router;
