const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Session length. Long on purpose: the admin panel stays logged in on the
// browser, and the token is renewed on every visit (see getMe).
const SESSION_TTL = process.env.SESSION_TTL || '365d';

// Generate JWT token
const generateToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: SESSION_TTL,
  });

const clean = (v) => (typeof v === 'string' ? v.trim().toLowerCase() : '');

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public (first admin) / Admin only after
exports.register = async (req, res) => {
  try {
    const { name, password, role, storeId, pin } = req.body;
    const username = clean(req.body.username) || undefined;
    const email = clean(req.body.email) || undefined;

    if (!username && !email) {
      return res.status(400).json({ success: false, message: 'Username or email is required' });
    }
    if (username && (await User.findOne({ username }))) {
      return res.status(400).json({ success: false, message: 'Username already in use' });
    }
    if (email && (await User.findOne({ email }))) {
      return res.status(400).json({ success: false, message: 'Email already in use' });
    }

    const user = await User.create({ name, username, email, passwordHash: password, role, storeId, pin });
    const token = generateToken(user._id);
    res.status(201).json({ success: true, token, user: { id: user._id, name, username, email, role: user.role } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc    Login with username OR email (the caisse/serveur apps still use email)
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { password } = req.body;
    const identifier = clean(req.body.username) || clean(req.body.identifier) || clean(req.body.email);
    if (!identifier || !password) {
      return res.status(400).json({ success: false, message: 'Identifier and password are required' });
    }

    const user = await User.findOne({
      $or: [{ username: identifier }, { email: identifier }],
    }).select('+passwordHash');

    if (!user || user.isActive === false || !(await user.matchPassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }
    user.lastLogin = new Date();
    await user.save();
    const token = generateToken(user._id);
    res.json({
      success: true,
      token,
      user: { id: user._id, name: user.name, username: user.username, email: user.email, role: user.role, storeId: user.storeId },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc    Get current logged-in user + a renewed token (sliding session)
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  const user = await User.findById(req.user.id).select('-passwordHash');
  res.json({ success: true, data: user, token: generateToken(user._id) });
};
