const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Generate JWT token
const generateToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '7d',
  });

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public (first admin) / Admin only after
exports.register = async (req, res) => {
  try {
    const { name, email, password, role, storeId, pin } = req.body;
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ success: false, message: 'Email already in use' });

    const user = await User.create({ name, email, passwordHash: password, role, storeId, pin });
    const token = generateToken(user._id);
    res.status(201).json({ success: true, token, user: { id: user._id, name, email, role } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc    Login
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email }).select('+passwordHash');
    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }
    user.lastLogin = new Date();
    await user.save();
    const token = generateToken(user._id);
    res.json({ success: true, token, user: { id: user._id, name: user.name, email, role: user.role, storeId: user.storeId } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc    Get current logged-in user
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  const user = await User.findById(req.user.id).select('-passwordHash');
  res.json({ success: true, data: user });
};
