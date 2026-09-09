const mongoose = require('mongoose');

const CategorySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // e.g. "Menus B", "Menus L", "Nos Burgers", "Nos Starters", "Nos Sandwichs"
    // "Menu Enfant", "Nos Desserts", "Boissons & Cafés"
    slug: { type: String, unique: true, lowercase: true },
    icon: String, // icon name or URL
    displayOrder: { type: Number, default: 0 },
    storeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Store' },
    isActive: { type: Boolean, default: true },
    color: String, // hex color for UI
  },
  { timestamps: true }
);

// Auto-generate slug from name
CategorySchema.pre('save', function (next) {
  if (this.isModified('name') && !this.slug) {
    this.slug = this.name
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '');
  }
  next();
});

module.exports = mongoose.model('Category', CategorySchema);
