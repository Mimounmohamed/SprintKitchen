const Payment = require('../models/Payment');
const Order = require('../models/Order');

// @desc  Process payment for an order
// @route POST /api/payments
exports.createPayment = async (req, res) => {
  try {
    const { orderId, method, amountReceived, splitDetails, cardReference } = req.body;

    const order = await Order.findById(orderId);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    if (order.status === 'terminee') {
      return res.status(400).json({ success: false, message: 'Order already paid' });
    }

    const change = method === 'especes' ? Math.max(0, amountReceived - order.totalTTC) : 0;

    const payment = await Payment.create({
      orderId,
      storeId: order.storeId,
      registerId: order.registerId,
      operatorId: req.user?.id,
      method,
      amountDue: order.totalTTC,
      amountReceived,
      change,
      splitDetails,
      cardReference,
      receiptPrinted: req.body.receiptPrinted || false,
    });

    // Mark order as completed
    order.status = 'terminee';
    order.completedAt = new Date();
    await order.save();

    res.status(201).json({ success: true, data: payment, change });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Get payment by order
// @route GET /api/payments/order/:orderId
exports.getPaymentByOrder = async (req, res) => {
  try {
    const payment = await Payment.findOne({ orderId: req.params.orderId });
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    res.json({ success: true, data: payment });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Refund / cancel payment
// @route PATCH /api/payments/:id/refund
exports.refundPayment = async (req, res) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (payment.isRefunded) return res.status(400).json({ success: false, message: 'Already refunded' });

    payment.isRefunded = true;
    payment.refundedAt = new Date();
    payment.refundReason = req.body.reason;
    payment.refundedBy = req.user?.id;
    await payment.save();

    // Cancel the order
    await Order.findByIdAndUpdate(payment.orderId, {
      status: 'annulee',
      cancelledAt: new Date(),
      cancelReason: req.body.reason,
    });

    res.json({ success: true, data: payment });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
