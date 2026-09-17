const mongoose = require('mongoose');

const IngredientSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // e.g. "Steak Haché 180g", "Frites Maison", "Sauce BBQ Fumée", "Coca-Cola 33cl", "Cheddar Affiné"

    family: { type: String, required: true, trim: true },

    unit: { type: String, default: 'unité' }, // kg, L, unité, portion

    availability: {
      type: String,
      enum: ['available', 'epuise', 'bloque'],
      default: 'available',
    },

    isOnList86:  { type: Boolean, default: false },
    notes:       { type: String },  // reason for being out of stock
    storeId:     { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    displayOrder:{ type: Number, default: 0 },
    isActive:    { type: Boolean, default: true },
  },
  { timestamps: true }
);

IngredientSchema.index({ family: 1, displayOrder: 1 });
IngredientSchema.index({ availability: 1 });
IngredientSchema.index({ storeId: 1 });

module.exports = mongoose.model('Ingredient', IngredientSchema);
