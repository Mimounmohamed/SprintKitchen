const express = require('express');
const router  = express.Router();
const {
  getIngredients, getFamilies, getIngredient,
  createIngredient, updateIngredient,
  updateAvailability, bulkAvailability, deleteIngredient,
} = require('../controllers/ingredientController');
const protect = require('../middleware/auth');

router.get('/families',              getFamilies);
router.get('/',                      getIngredients);
router.get('/:id',                   getIngredient);
router.post('/bulk-availability',    protect, bulkAvailability);
router.post('/',                     protect, createIngredient);
router.put('/:id',                   protect, updateIngredient);
router.patch('/:id/availability',    protect, updateAvailability);
router.delete('/:id',                protect, deleteIngredient);

module.exports = router;
