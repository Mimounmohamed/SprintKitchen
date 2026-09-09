const express = require('express');
const router = express.Router();
const {
  searchCustomer, getCustomer, createCustomer, updateCustomer, addAddress,
} = require('../controllers/customerController');
const protect = require('../middleware/auth');

router.get('/search', protect, searchCustomer);
router.get('/:id', protect, getCustomer);
router.post('/', protect, createCustomer);
router.put('/:id', protect, updateCustomer);
router.post('/:id/addresses', protect, addAddress);

module.exports = router;
