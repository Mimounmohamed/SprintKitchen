const Register = require('../models/Register');

exports.getRegisters = async (req, res) => {
  try {
    const filter = { isActive: true };
    if (req.query.storeId) filter.storeId = req.query.storeId;
    const registers = await Register.find(filter).populate('currentSession.openedBy', 'name');
    res.json({ success: true, data: registers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getRegister = async (req, res) => {
  try {
    const register = await Register.findById(req.params.id);
    if (!register) return res.status(404).json({ success: false, message: 'Register not found' });
    res.json({ success: true, data: register });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createRegister = async (req, res) => {
  try {
    const register = await Register.create(req.body);
    res.status(201).json({ success: true, data: register });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Open a register session
// @route PATCH /api/registers/:id/open
exports.openSession = async (req, res) => {
  try {
    const { openingFloat } = req.body;
    const register = await Register.findByIdAndUpdate(
      req.params.id,
      {
        currentSession: {
          openedAt: new Date(),
          openedBy: req.user?.id,
          openingFloat: openingFloat || 0,
        },
        lastActivity: new Date(),
      },
      { new: true }
    );
    if (!register) return res.status(404).json({ success: false, message: 'Register not found' });
    res.json({ success: true, data: register });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Close a register session
// @route PATCH /api/registers/:id/close
exports.closeSession = async (req, res) => {
  try {
    const { closingFloat } = req.body;
    const register = await Register.findById(req.params.id);
    if (!register) return res.status(404).json({ success: false, message: 'Register not found' });
    register.currentSession.closedAt = new Date();
    register.currentSession.closingFloat = closingFloat;
    await register.save();
    res.json({ success: true, data: register });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};
