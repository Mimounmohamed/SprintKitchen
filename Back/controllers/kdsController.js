const Order = require('../models/Order');

/**
 * GET /api/kds/orders
 * Returns kitchen-relevant orders for TODAY only.
 * Statuses shown:  en_attente (waiting) + a_encaisser (ready, pending cashier)
 * Sorted oldest first → FIFO queue.
 *
 * KDS status flow (saved to DB on each button tap):
 *   COMMENCER  → kdsStatus: 'in_progress',  order.status stays 'en_attente'
 *   PRÊT ✓    → kdsStatus: 'ready',         order.status → 'a_encaisser'
 *   TERMINÉ   → kdsStatus: 'served',        order.status → 'terminee'  (disappears from KDS)
 */
exports.getKdsOrders = async (req, res) => {
  try {
    // Today's window in Africa/Algiers time (UTC+1 = offset 60 min)
    const now  = new Date();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(now);
    todayEnd.setHours(23, 59, 59, 999);

    const orders = await Order.find({
      status:    { $in: ['en_attente', 'a_encaisser'] },
      createdAt: { $gte: todayStart, $lte: todayEnd },
    })
      .select(
        'ticketNumber orderType status kdsStatus kdsSentAt ' +
        'items notes createdAt clientName buzzerNumber'
      )
      .sort({ createdAt: 1 }) // oldest first = FIFO
      .limit(60);

    res.json({ success: true, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * PATCH /api/kds/orders/:id/kds-status
 * Body: { kdsStatus: 'in_progress' | 'ready' | 'served' }
 *
 * Button       kdsStatus sent    Saved to DB
 * ─────────    ──────────────    ───────────────────────────────────
 * COMMENCER  → 'in_progress'  → kdsStatus='in_progress', order.status='en_attente'
 * PRÊT ✓    → 'ready'        → kdsStatus='ready',        order.status='a_encaisser', kdsReadyAt=now
 * TERMINÉ   → 'served'       → kdsStatus='served',       order.status='terminee',    completedAt=now
 */
exports.updateKdsStatus = async (req, res) => {
  try {
    const { kdsStatus } = req.body;
    const valid = ['in_progress', 'ready', 'served'];
    if (!valid.includes(kdsStatus)) {
      return res.status(400).json({
        success: false,
        message: `kdsStatus must be one of: ${valid.join(', ')}`,
      });
    }

    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Commande introuvable' });
    }

    // Always update kdsStatus
    order.kdsStatus = kdsStatus;

    if (kdsStatus === 'in_progress') {
      // Kitchen started — order stays visible on KDS as en_attente
      // (order.status unchanged)

    } else if (kdsStatus === 'ready') {
      // Kitchen done → notify cashier
      order.kdsReadyAt = new Date();
      order.status     = 'a_encaisser';

    } else if (kdsStatus === 'served') {
      // Handed to customer → archive
      order.status      = 'terminee';
      order.completedAt = new Date();
    }

    await order.save();

    res.json({
      success: true,
      data: {
        _id:        order._id,
        kdsStatus:  order.kdsStatus,
        status:     order.status,
        kdsReadyAt: order.kdsReadyAt,
        completedAt: order.completedAt,
      },
    });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};
