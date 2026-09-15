const mongoose = require('mongoose');
const IngredientFamilySchema = new mongoose.Schema({
  name:         { type: String, required: true, trim: true },
  slug:         { type: String, required: true, unique: true, trim: true, lowercase: true },
  emoji:        { type: String, default: '📦' },
  displayOrder: { type: Number, default: 0 },
  isActive:     { type: Boolean, default: true },
}, { timestamps: true });
module.exports = mongoose.model('IngredientFamily', IngredientFamilySchema);
