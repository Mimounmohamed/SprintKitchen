const mongoose = require('mongoose');

const AddressSchema = new mongoose.Schema(
  {
    label: String,          // "Domicile", "Bureau"
    street: String,         // "14 Rue de la République, Bâtiment B"
    floor: String,          // "3ème ét., porte gauche"
    digicode: String,       // "#4912"
    instructions: String,   // "Sonner à l'interphone #4"
    city: String,
    postalCode: String,
    isDefault: { type: Boolean, default: false },
  },
  { _id: true }
);

const CustomerSchema = new mongoose.Schema(
  {
    phone: { type: String, required: true, unique: true, trim: true },
    // "06 42 98 11 05"
    fullName: { type: String, required: true, trim: true },
    email: String,
    addresses: [AddressSchema],
    loyaltyPoints: { type: Number, default: 0 },
    totalOrders: { type: Number, default: 0 },
    totalSpent: { type: Number, default: 0 },
    notes: String,
    storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    isActive: { type: Boolean, default: true },
    lastOrderAt: Date,
  },
  { timestamps: true }
);

CustomerSchema.index({ phone: 1 });
CustomerSchema.index({ fullName: 'text' });

module.exports = mongoose.model('Customer', CustomerSchema);
