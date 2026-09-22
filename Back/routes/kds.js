const express = require('express');
const router = express.Router();
const { getKdsOrders, updateKdsStatus } = require('../controllers/kdsController');

// No auth middleware — kitchen tablet has no login session
// Optionally add a simple API-key check later

router.get('/orders',                   getKdsOrders);
router.patch('/orders/:id/kds-status',  updateKdsStatus);

module.exports = router;
