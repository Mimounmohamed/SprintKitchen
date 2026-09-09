const mongoose = require('mongoose');

const PaymentSchema = new mongoose.Schema(
  {
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: true,
    },
    storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    registerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Register' },
    operatorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    method: {
      type: String,
      enum: ['especes', 'carte_bancaire', 'mixte', 'ticket_restaurant', 'sans_contact'],
      required: true,
    },
    // Espèces (Cash)
    amountDue: { type: Number, required: true },
    amountReceived: { type: Number, required: true },
    change: { type: Number, default: 0 },
    // For split payments (mixte)
    splitDetails: [
      {
        method: String,
        amount: Number,
      },
    ],
    // TPE reference for card payments
    cardReference: String,    // "Art#TRS-6a821"
    cardAuthCode: String,
    // Receipt
    receiptPrinted: { type: Boolean, default: false },
    receiptReprintCount: { type: Number, default: 0 },
    // Refund info
    isRefunded: { type: Boolean, default: false },
    refundedAt: Date,
    refundReason: String,
    refundedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

PaymentSchema.index({ orderId: 1 });
PaymentSchema.index({ storeId: 1, createdAt: -1 });

module.exports = mongoose.model('Payment', PaymentSchema);
