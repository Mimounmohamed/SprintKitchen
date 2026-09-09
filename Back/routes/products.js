const express = require('express');
const router = express.Router();
const {
  getProducts, getProduct, createProduct, updateProduct,
  updateAvailability, bulkAvailability, deleteProduct,
} = require('../controllers/productController');
const protect = require('../middleware/auth');

router.get('/', getProducts);
router.post('/bulk-availability', protect, bulkAvailability);
router.get('/:id', getProduct);
router.post('/', protect, createProduct);
router.put('/:id', protect, updateProduct);
router.patch('/:id/availability', protect, updateAvailability);
router.delete('/:id', protect, deleteProduct);

module.exports = router;
