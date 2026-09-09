const mongoose = require('mongoose');

const RegisterSchema = new mongoose.Schema(
  {
    name: { type: String, required: true }, // "Caisse 01", "Borne 02"
    type: {
      type: String,
      enum: ['caisse', 'borne', 'tablette', 'kds'],
      default: 'caisse',
    },
    storeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Store',
      required: true,
    },
    isActive: { type: Boolean, default: true },
    // Current open session info
    currentSession: {
      openedAt: Date,
      openedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      openingFloat: { type: Number, default: 0 }, // starting cash
      closedAt: Date,
      closingFloat: Number,
    },
    // Hardware info
    hardware: {
      printerModel: String, // e.g. "Epson TM-T88"
      printerIp: String,
      drawerConnected: { type: Boolean, default: false },
    },
    lastActivity: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Register', RegisterSchema);
