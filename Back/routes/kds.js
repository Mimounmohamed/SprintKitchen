const express = require('express');
const router = express.Router();
const { getKdsOrders, updateKdsStatus } = require('../controllers/kdsController');

router.get('/orders',                  getKdsOrders);
router.patch('/orders/:id/kds-status', updateKdsStatus);

module.exports = router;
