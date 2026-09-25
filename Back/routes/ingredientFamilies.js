const express  = require('express');
const router   = express.Router();
const {
  getFamilies, createFamily, updateFamily, deleteFamily,
} = require('../controllers/ingredientFamilyController');

router.get('/',      getFamilies);
router.post('/',     createFamily);
router.put('/:id',   updateFamily);
router.delete('/:id',deleteFamily);

module.exports = router;