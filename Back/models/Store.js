const mongoose = require('mongoose');

const StoreSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    storeNumber: { type: String, unique: true }, // e.g. "04"
    address: {
      street: String,
      city: String,
      postalCode: String,
      country: { type: String, default: 'France' },
    },
    phone: String,
    timezone: { type: String, default: 'Europe/Paris' },
    // Active meal services (Déjeuner, Dîner, etc.)
    services: [
      {
        name: String, // e.g. "Déjeuner", "Dîner"
        startTime: String, // "11:00"
        endTime: String,   // "15:00"
        isActive: { type: Boolean, default: true },
      },
    ],
    tvaRate: { type: Number, default: 10 }, // 10% TVA
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Store', StoreSchema);
