const express = require('express');
const router = express.Router();
const {
  createPayment, getPaymentByOrder, refundPayment,
} = require('../controllers/paymentController');

router.post('/', createPayment);
router.get('/order/:orderId', getPaymentByOrder);
router.patch('/:id/refund', refundPayment);

module.exports = router;