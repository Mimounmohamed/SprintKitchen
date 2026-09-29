const express = require('express');
const router = express.Router();
const { getKdsOrders, updateKdsStatus, updateKdsItemStatus } = require('../controllers/kdsController');

router.get('/orders',                                    getKdsOrders);
router.patch('/orders/:id/kds-status',                   updateKdsStatus);
router.patch('/orders/:orderId/items/:itemId/kds-status', updateKdsItemStatus);

module.exports = router;
