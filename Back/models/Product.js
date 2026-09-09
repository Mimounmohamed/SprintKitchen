const mongoose = require('mongoose');

// ── Embedded: one selectable option within a group ──────────────────────────
const OptionSchema = new mongoose.Schema(
  {
    label: { type: String, required: true },      // "Algérienne", "Double Cheese"
    priceModifier: { type: Number, default: 0 },  // +1.50 for extra, 0 for included
    isDefault: { type: Boolean, default: false },  // pre-selected option
    isAvailable: { type: Boolean, default: true },
    displayOrder: { type: Number, default: 0 },
  },
  { _id: false }
);

// ── Embedded: a customization group on the personnalisation modal ────────────
const CustomizationGroupSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    // "Cuisson de la viande", "Choix de la sauce", "Accompagnement",
    // "Suppléments & Extras", "Ingrédients à retirer"
    type: {
      type: String,
      enum: ['single', 'multi'],  // single = radio, multi = checkbox
      default: 'single',
    },
    isRequired: { type: Boolean, default: false },
    minChoices: { type: Number, default: 0 },
    maxChoices: { type: Number, default: 1 }, // 3 for sauce group
    stepNumber: Number,  // display order (1, 2, 3, 5, 6 as seen in UI)
    options: [OptionSchema],
  },
  { _id: false }
);

// ── Main Product schema ──────────────────────────────────────────────────────
const ProductSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // e.g. "Menu B4 Cheese", "Menu B1", "Frites Maison XL"
    description: { type: String, trim: true },
    // e.g. "Sauce Algérienne, Cuisson à point"
    categoryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Category',
      required: true,
    },
    storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    basePrice: { type: Number, required: true }, // price in euros
    // Availability status (86 list / stock management)
    availability: {
      type: String,
      enum: ['available', 'epuise', 'bloque_caisse_borne'],
      default: 'available',
    },
    // Whether product is on the 86-list (out-of-stock tracking)
    isOnList86: { type: Boolean, default: false },
    // For items "ÉPUISÉ" that block both caisse and borne
    blockedOnCaisse: { type: Boolean, default: false },
    blockedOnBorne: { type: Boolean, default: false },
    // Customization groups (embedded) — the personnalisation modal
    customizationGroups: [CustomizationGroupSchema],
    // Image/display
    imageUrl: String,
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    // KDS routing — which screen handles this product
    kdsStation: {
      type: String,
      enum: ['grill', 'frites', 'boissons', 'desserts', 'general'],
      default: 'general',
    },
  },
  { timestamps: true }
);

ProductSchema.index({ categoryId: 1, displayOrder: 1 });
ProductSchema.index({ availability: 1 });

module.exports = mongoose.model('Product', ProductSchema);
