const express  = require('express');
const router   = express.Router();
const {
  getFamilies, createFamily, updateFamily, deleteFamily,
} = require('../controllers/ingredientFamilyController');
const protect = require('../middleware/auth');

router.get('/',      getFamilies);
router.post('/',     protect, createFamily);
router.put('/:id',   protect, updateFamily);
router.delete('/:id',protect, deleteFamily);

module.exports = router;
