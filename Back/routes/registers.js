const express = require('express');
const router = express.Router();
const {
  getRegisters, getRegister, createRegister, openSession, closeSession,
} = require('../controllers/registerController');
const protect = require('../middleware/auth');

router.get('/', protect, getRegisters);
router.get('/:id', protect, getRegister);
router.post('/', protect, createRegister);
router.patch('/:id/open', protect, openSession);
router.patch('/:id/close', protect, closeSession);

module.exports = router;
