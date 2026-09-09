const mongoose = require('mongoose');

const StockLogSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: true,
    },
    storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    // Action taken on the product availability
    action: {
      type: String,
      enum: ['disponible', 'epuise', 'bloque_caisse_borne'],
      required: true,
    },
    previousStatus: {
      type: String,
      enum: ['available', 'epuise', 'bloque_caisse_borne'],
    },
    operatorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    notes: String,
    // How many units remain (optional for future stock counting)
    quantityRemaining: Number,
  },
  { timestamps: true }
);

StockLogSchema.index({ productId: 1, createdAt: -1 });
StockLogSchema.index({ storeId: 1, createdAt: -1 });

module.exports = mongoose.model('StockLog', StockLogSchema);
