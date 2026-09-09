const express = require('express');
const router = express.Router();
const {
  getCategories, getCategory, createCategory, updateCategory, deleteCategory,
} = require('../controllers/categoryController');
const protect = require('../middleware/auth');

router.get('/', getCategories);
router.get('/:id', getCategory);
router.post('/', protect, createCategory);
router.put('/:id', protect, updateCategory);
router.delete('/:id', protect, deleteCategory);

module.exports = router;
