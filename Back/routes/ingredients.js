const express = require('express');
const router  = express.Router();
const {
  getIngredients, getFamilies, getIngredient,
  createIngredient, updateIngredient,
  updateAvailability, bulkAvailability, deleteIngredient,
} = require('../controllers/ingredientController');

router.get('/families',              getFamilies);
router.get('/',                      getIngredients);
router.get('/:id',                   getIngredient);
router.post('/bulk-availability',    bulkAvailability);
router.post('/',                     createIngredient);
router.put('/:id',                   updateIngredient);
router.patch('/:id/availability',    updateAvailability);
router.delete('/:id',                deleteIngredient);

module.exports = router;