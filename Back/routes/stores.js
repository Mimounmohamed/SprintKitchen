const express = require('express');
const router = express.Router();
const { getStores, getStore, createStore, updateStore } = require('../controllers/storeController');
const protect = require('../middleware/auth');

router.get('/', protect, getStores);
router.get('/:id', protect, getStore);
router.post('/', protect, createStore);
router.put('/:id', protect, updateStore);

module.exports = router;
