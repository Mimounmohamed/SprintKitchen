const mongoose = require('mongoose');

// ── Embedded: a selected option within a customization group ─────────────────
const SelectedOptionSchema = new mongoose.Schema(
  {
    label: String,           // "Algérienne", "Double Cheese"
    priceModifier: { type: Number, default: 0 },
  },
  { _id: false }
);

// ── Embedded: customization applied to an order item ─────────────────────────
const AppliedCustomizationSchema = new mongoose.Schema(
  {
    groupName: String,       // "Cuisson de la viande", "Choix de la sauce"
    selectedOptions: [SelectedOptionSchema],
  },
  { _id: false }
);

// ── Embedded: one line item in the order ─────────────────────────────────────
const OrderItemSchema = new mongoose.Schema(
  {
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
    productName: { type: String, required: true }, // snapshot at time of order
    unitPrice: { type: Number, required: true },   // base price
    quantity: { type: Number, default: 1, min: 1 },
    customizations: [AppliedCustomizationSchema],
    removedIngredients: [String], // ["Sans Tomate", "Sans Cornichon"]
    lineTotal: { type: Number, required: true }, // (unitPrice + extras) * qty
    // KDS status per item
    kdsStatus: {
      type: String,
      enum: ['pending', 'in_progress', 'ready', 'served'],
      default: 'pending',
    },
    kdsStation: String, // "grill", "frites", etc.
    notes: String,
  },
  { _id: true }
);

// ── Embedded: delivery details ────────────────────────────────────────────────
const DeliveryDetailsSchema = new mongoose.Schema(
  {
    customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer' },
    phone: String,
    fullName: String,
    address: String,       // "14 Rue de la République, Bâtiment B"
    floor: String,         // "3ème ét., porte gauche"
    digicode: String,      // "#4912"
    instructions: String,  // "Sonner à l'interphone #4, laisser devant la porte"
    city: String,
    postalCode: String,
    estimatedDeliveryAt: Date,
    deliveredAt: Date,
  },
  { _id: false }
);

// ── Counter schema for auto-incrementing ticket numbers ───────────────────────
const CounterSchema = new mongoose.Schema({
  _id: String,
  seq: { type: Number, default: 0 },
});
const Counter = mongoose.model('Counter', CounterSchema);

// ── Main Order schema ─────────────────────────────────────────────────────────
const OrderSchema = new mongoose.Schema(
  {
    // Auto-incremented, zero-padded: "0000123"
    ticketNumber: { type: String, unique: true },
    storeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Store',
      required: true,
    },
    registerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Register' },
    operatorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    status: {
      type: String,
      enum: [
        'en_cours',       // being built at POS
        'en_attente',     // sent to kitchen, waiting
        'a_encaisser',    // ready, pending payment
        'terminee',       // paid & complete
        'repas_employe',  // staff meal
        'annulee',        // cancelled
      ],
      default: 'en_cours',
    },
    orderType: {
      type: String,
      enum: ['sur_place', 'a_emporter', 'livraison'],
      default: 'sur_place',
    },
    // Client identification
    customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer' },
    clientName: String,       // "Thomas B.", "Julie V."
    buzzerNumber: String,     // "Buzzer #14 (Comptoir)"
    // Delivery info (only for livraison)
    delivery: DeliveryDetailsSchema,
    // Order lines
    items: [OrderItemSchema],
    // Financials
    subtotalHT: { type: Number, default: 0 },
    tvaRate: { type: Number, default: 10 },
    tvaAmount: { type: Number, default: 0 },
    totalTTC: { type: Number, default: 0 },
    // Discount
    discount: {
      type: { type: String, enum: ['percent', 'fixed'] },
      value: Number,
      reason: String,
    },
    // KDS sync status
    kdsStatus: {
      type: String,
      enum: ['pending', 'in_progress', 'ready', 'served'],
      default: 'pending',
    },
    kdsSentAt: Date,
    kdsReadyAt: Date,
    // Timing
    completedAt: Date,
    cancelledAt: Date,
    cancelReason: String,
    // Reprinted
    reprintCount: { type: Number, default: 0 },
    // Notes
    notes: String,
  },
  { timestamps: true }
);

// ── Auto-generate ticketNumber before save ────────────────────────────────────
OrderSchema.pre('save', async function (next) {
  if (this.ticketNumber) return next();
  try {
    const counter = await Counter.findByIdAndUpdate(
      'orderTicket',
      { $inc: { seq: 1 } },
      { new: true, upsert: true }
    );
    this.ticketNumber = String(counter.seq).padStart(7, '0');
    next();
  } catch (err) {
    next(err);
  }
});

// ── Recalculate totals ────────────────────────────────────────────────────────
OrderSchema.methods.recalculateTotals = function () {
  this.totalTTC = this.items.reduce((sum, item) => sum + item.lineTotal, 0);
  if (this.discount) {
    if (this.discount.type === 'percent') {
      this.totalTTC = this.totalTTC * (1 - this.discount.value / 100);
    } else {
      this.totalTTC = Math.max(0, this.totalTTC - this.discount.value);
    }
  }
  this.tvaAmount = parseFloat(
    (this.totalTTC - this.totalTTC / (1 + this.tvaRate / 100)).toFixed(2)
  );
  this.subtotalHT = parseFloat((this.totalTTC - this.tvaAmount).toFixed(2));
  this.totalTTC = parseFloat(this.totalTTC.toFixed(2));
};

OrderSchema.index({ storeId: 1, createdAt: -1 });
OrderSchema.index({ status: 1 });
OrderSchema.index({ registerId: 1, status: 1 });

module.exports = mongoose.model('Order', OrderSchema);