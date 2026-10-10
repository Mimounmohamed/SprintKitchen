const Order = require('../models/Order');
const Payment = require('../models/Payment');
const Store = require('../models/Store');

// Escape user input before using it inside a RegExp (a lone "(" would crash).
const escapeRegex = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// Normalize table identifier (e.g. "Table 5" -> "5", "  5 " -> "5")
const normalizeTableNumber = (val) => {
  if (!val) return null;
  const s = String(val).trim();
  if (!s) return null;
  const match = s.match(/^table\s*(.+)$/i);
  if (match) return match[1].trim();
  if (/^buzzer/i.test(s)) return null;
  return s;
};

// Builds a createdAt range from ?from & ?to.
// - Date-only values ("2026-09-07") mean the whole day (UTC).
// - Full ISO timestamps are used exactly as sent, so the client can send
//   its own local start / end of day.
const buildDateRange = (from, to) => {
  if (!from && !to) return null;
  const range = {};
  if (from) range.$gte = new Date(from);
  if (to) {
    const end = new Date(to);
    if (/^\d{4}-\d{2}-\d{2}$/.test(to)) end.setUTCHours(23, 59, 59, 999);
    range.$lte = end;
  }
  return range;
};

// @desc  Get orders (with filters & date range)
// @route GET /api/orders
exports.getOrders = async (req, res) => {
  try {
    const filter = {};
    if (req.query.storeId) filter.storeId = req.query.storeId;
    if (req.query.registerId) filter.registerId = req.query.registerId;
    if (req.query.status) filter.status = req.query.status;
    if (req.query.orderType) filter.orderType = req.query.orderType;

    // Date range filter (from Order History)
    const range = buildDateRange(req.query.from, req.query.to);
    if (range) filter.createdAt = range;

    // Search by ticket number or client name
    if (req.query.search) {
      const term = escapeRegex(req.query.search);
      filter.$or = [
        { ticketNumber: { $regex: term, $options: 'i' } },
        { clientName: { $regex: term, $options: 'i' } },
        { buzzerNumber: { $regex: term, $options: 'i' } },
      ];
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const [orders, total] = await Promise.all([
      Order.find(filter)
        .populate('registerId', 'name type')
        .populate('operatorId', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Order.countDocuments(filter),
    ]);

    res.json({
      success: true,
      count: orders.length,
      total,
      totalPages: Math.ceil(total / limit),
      page,
      data: orders,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Order counts per status + revenue of paid orders (History tabs)
// @route GET /api/orders/summary?from=&to=
exports.getOrdersSummary = async (req, res) => {
  try {
    const match = {};
    const range = buildDateRange(req.query.from, req.query.to);
    if (range) match.createdAt = range;

    const rows = await Order.aggregate([
      { $match: match },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          total: { $sum: '$totalTTC' },
        },
      },
    ]);

    const counts = {
      en_cours: 0,
      en_attente: 0,
      a_encaisser: 0,
      terminee: 0,
      repas_employe: 0,
      annulee: 0,
    };
    let totalTerminee = 0;
    rows.forEach((r) => {
      counts[r._id] = r.count;
      if (r._id === 'terminee' || r._id === 'en_attente') totalTerminee += r.total;
    });

    res.json({
      success: true,
      data: { counts, totalTerminee: parseFloat(totalTerminee.toFixed(2)) },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get single order
// @route GET /api/orders/:id
exports.getOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('registerId', 'name type')
      .populate('operatorId', 'name')
      .populate('customerId', 'fullName phone')
      .populate('items.productId', 'name basePrice ingredients description categoryId kdsStation');
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Create new order (open ticket)
// @route POST /api/orders
// No login on this install: if the client doesn't send a storeId, we use
// the (single) store stored in the database.
exports.createOrder = async (req, res) => {
  try {
    const data = { ...req.body };

    if (!data.storeId) {
      const store = await Store.findOne();
      if (!store) {
        return res
          .status(400)
          .json({ success: false, message: 'Aucun magasin configuré' });
      }
      data.storeId = store._id;
    }

    // Check table occupancy if order is linked to a table
    const rawTable = data.tableNumber || (data.orderType === 'sur_place' ? data.buzzerNumber : null);
    const table = normalizeTableNumber(rawTable);
    if (table) {
      data.tableNumber = table;
      if (!data.buzzerNumber) {
        data.buzzerNumber = `Table ${table}`;
      }

      // Table conflict check only applies to dine-in orders
      if (data.orderType === 'sur_place') {
        const occupiedOrder = await Order.findOne({
          storeId: data.storeId,
          orderType: 'sur_place',
          status: { $nin: ['terminee', 'annulee'] },
          $or: [
            { tableNumber: table },
            { buzzerNumber: `Table ${table}` },
            { buzzerNumber: table },
            { buzzerNumber: new RegExp(`^Table\\s*${escapeRegex(table)}$`, 'i') },
          ],
        });

        if (occupiedOrder) {
          return res.status(400).json({
            success: false,
            message: `La table ${table} est déjà liée à une commande active (#${occupiedOrder.ticketNumber || occupiedOrder._id}). Elle ne peut pas être réutilisée tant que cette commande n'est pas marquée terminée.`,
            occupiedTable: table,
            activeTicketNumber: occupiedOrder.ticketNumber,
          });
        }
      }
    }

    const order = new Order(data);
    if (!order.kdsSentAt) {
      order.kdsSentAt = new Date();
    }
    if (data.items && Array.isArray(data.items) && data.items.length > 0) {
      order.initialItems = data.items;
    }
    order.recalculateTotals();
    await order.save();
    res.status(201).json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// Helper to extract options/sauces/removes as a comparable string
function formatItemSummary(item) {
  const parts = [];
  if (item.customizations && item.customizations.length > 0) {
    for (const c of item.customizations) {
      if (c.selectedOptions && c.selectedOptions.length > 0) {
        const opts = c.selectedOptions.map((o) => o.label || o).join(', ');
        if (opts) parts.push(opts);
      }
    }
  }
  if (item.removedIngredients && item.removedIngredients.length > 0) {
    for (const r of item.removedIngredients) {
      const clean = String(r).replace(/^sans\s+/i, '').trim();
      if (clean) parts.push(`Sans ${clean}`);
    }
  }
  if (item.notes && String(item.notes).trim()) {
    parts.push(String(item.notes).trim());
  }
  return parts.join(' • ');
}

// Clean text to extract product name for matching modifications across edits
function cleanProductNameFromText(text) {
  if (!text) return '';
  return String(text)
    .replace(/^(?:Modifié|Supprimé|Ajouté)\s*:\s*/i, '')
    .replace(/^\d+×\s*/, '')
    .replace(/\s*:\s*Quantité modifiée.*$/i, '')
    .trim()
    .toLowerCase();
}

// Helper to compare modifications on a matched line
function checkItemModifications(oldIt, newIt, changes) {
  const oldSumm = formatItemSummary(oldIt);
  const newSumm = formatItemSummary(newIt);
  const detailsList = [];

  if (oldIt.quantity !== newIt.quantity) {
    detailsList.push(`Quantité : ${oldIt.quantity}× ➔ ${newIt.quantity}×`);
  }
  if (oldSumm !== newSumm) {
    detailsList.push(`Nouvelles options : ${newSumm || 'Aucune'}`);
  }

  if (detailsList.length > 0) {
    changes.push({
      action: 'modified',
      text: `Modifié : ${oldIt.productName}`,
      details: detailsList.join(' • '),
    });
  }
}

// Computes specific changes made between oldOrder and newBody (items, table, notes)
function computeOrderChanges(oldOrder, newBody) {
  const changes = [];
  const oldItems = oldOrder.items || [];
  const newItems = newBody.items || [];

  if (newBody.items && Array.isArray(newBody.items)) {
    const matchedNewIndices = new Set();
    const matchedOldIndices = new Set();

    // 1. Try matching by _id / id
    for (let i = 0; i < oldItems.length; i++) {
      const oldIt = oldItems[i];
      const oldId = oldIt._id ? String(oldIt._id) : (oldIt.id ? String(oldIt.id) : null);
      if (!oldId) continue;

      for (let j = 0; j < newItems.length; j++) {
        if (matchedNewIndices.has(j)) continue;
        const newIt = newItems[j];
        const newId = newIt._id ? String(newIt._id) : (newIt.id ? String(newIt.id) : null);
        if (newId && newId === oldId) {
          matchedOldIndices.add(i);
          matchedNewIndices.add(j);
          checkItemModifications(oldIt, newIt, changes);
          break;
        }
      }
    }

    // 2. Try exact matches (same productName and identical options summary)
    for (let i = 0; i < oldItems.length; i++) {
      if (matchedOldIndices.has(i)) continue;
      const oldIt = oldItems[i];
      const oldSumm = formatItemSummary(oldIt);

      for (let j = 0; j < newItems.length; j++) {
        if (matchedNewIndices.has(j)) continue;
        const newIt = newItems[j];
        const newSumm = formatItemSummary(newIt);

        if (oldIt.productName === newIt.productName && oldSumm === newSumm) {
          matchedOldIndices.add(i);
          matchedNewIndices.add(j);
          if (oldIt.quantity !== newIt.quantity) {
            changes.push({
              action: 'modified',
              text: `${oldIt.productName} : Quantité modifiée (${oldIt.quantity}× ➔ ${newIt.quantity}×)`,
              details: oldSumm || null,
            });
          }
          break;
        }
      }
    }

    // 3. Match remaining items by productName
    for (let i = 0; i < oldItems.length; i++) {
      if (matchedOldIndices.has(i)) continue;
      const oldIt = oldItems[i];

      for (let j = 0; j < newItems.length; j++) {
        if (matchedNewIndices.has(j)) continue;
        const newIt = newItems[j];

        if (oldIt.productName === newIt.productName) {
          matchedOldIndices.add(i);
          matchedNewIndices.add(j);
          checkItemModifications(oldIt, newIt, changes);
          break;
        }
      }
    }

    // 4. Any old items not matched were DELETED
    for (let i = 0; i < oldItems.length; i++) {
      if (!matchedOldIndices.has(i)) {
        const it = oldItems[i];
        const summ = formatItemSummary(it);
        changes.push({
          action: 'deleted',
          text: `Supprimé : ${it.quantity}× ${it.productName}`,
          details: summ || null,
        });
      }
    }

    // 5. Any new items not matched were ADDED
    for (let j = 0; j < newItems.length; j++) {
      if (!matchedNewIndices.has(j)) {
        const it = newItems[j];
        const summ = formatItemSummary(it);
        changes.push({
          action: 'added',
          text: `Ajouté : ${it.quantity}× ${it.productName}`,
          details: summ || null,
        });
      }
    }
  }

  // Table check
  const newTable = newBody.tableNumber !== undefined ? newBody.tableNumber : null;
  const oldTable = oldOrder.tableNumber;
  if (newTable !== null && String(newTable).trim() !== String(oldTable || '').trim()) {
    changes.push({
      action: 'table',
      text: `Table : ${oldTable && String(oldTable).trim() ? 'Table ' + oldTable : 'Non assignée'} ➔ ${newTable && String(newTable).trim() ? 'Table ' + newTable : 'Non assignée'}`,
    });
  }

  // Order type check
  if (newBody.orderType && newBody.orderType !== oldOrder.orderType) {
    const typeLabel = (t) => {
      if (t === 'sur_place') return 'Sur place';
      if (t === 'a_emporter') return 'À emporter';
      if (t === 'livraison') return 'Livraison';
      return t;
    };
    changes.push({
      action: 'general',
      text: `Mode : ${typeLabel(oldOrder.orderType)} ➔ ${typeLabel(newBody.orderType)}`,
    });
  }

  // Client name check
  if (newBody.clientName !== undefined && (newBody.clientName || '').trim() !== (oldOrder.clientName || '').trim()) {
    const oldClient = (oldOrder.clientName || '').trim();
    const newClient = (newBody.clientName || '').trim();
    if (oldClient !== newClient) {
      changes.push({
        action: 'general',
        text: `Client : ${oldClient || 'Non assigné'} ➔ ${newClient || 'Non assigné'}`,
      });
    }
  }

  // Delivery info check
  if (newBody.delivery && typeof newBody.delivery === 'object') {
    const oldPhone = (oldOrder.delivery && oldOrder.delivery.phone) || '';
    const newPhone = newBody.delivery.phone || '';
    if (newPhone.trim() && newPhone.trim() !== oldPhone.trim()) {
      changes.push({
        action: 'general',
        text: `Téléphone : ${oldPhone || 'Non renseigné'} ➔ ${newPhone.trim()}`,
      });
    }
    const oldAddress = (oldOrder.delivery && oldOrder.delivery.address) || '';
    const newAddress = newBody.delivery.address || '';
    if (newAddress.trim() && newAddress.trim() !== oldAddress.trim()) {
      changes.push({
        action: 'general',
        text: `Adresse : ${oldAddress || 'Non renseignée'} ➔ ${newAddress.trim()}`,
      });
    }
  }

  // Note check
  if (newBody.notes !== undefined && (newBody.notes || '').trim() !== (oldOrder.notes || '').trim()) {
    const noteText = (newBody.notes || '').trim();
    changes.push({
      action: 'note',
      text: noteText ? `Note cuisine : "${noteText}"` : 'Note cuisine supprimée',
    });
  }

  return changes;
}

// Merges existing order modifications with new incoming changes without losing previous modifications
function mergeModifications(existingList, incomingList) {
  const existing = (existingList || []).map((item) => ({
    action: item.action || 'modified',
    text: item.text,
    details: item.details || null,
  }));
  const incoming = incomingList || [];

  if (existing.length === 0) return incoming;
  if (incoming.length === 0) return existing;

  const result = [...existing];

  for (const inc of incoming) {
    if (!inc || !inc.text) continue;

    const incAction = inc.action || 'modified';
    const incText = inc.text;
    const incDetails = inc.details || null;

    // Check for exact duplicates
    const isDup = result.some(
      (e) => e.action === incAction && e.text === incText && (e.details || null) === incDetails
    );
    if (isDup) continue;

    // General action: update existing general change with same prefix if present
    if (incAction === 'general') {
      const prefix = incText.split(' : ')[0];
      const genIdx = result.findIndex((e) => e.action === 'general' && e.text.startsWith(prefix + ' : '));
      if (genIdx !== -1) {
        result[genIdx] = inc;
      } else {
        result.push(inc);
      }
      continue;
    }

    // Table action: update existing table change if present
    if (incAction === 'table') {
      const tableIdx = result.findIndex((e) => e.action === 'table');
      if (tableIdx !== -1) {
        const oldMatch = result[tableIdx].text.match(/Table\s*:\s*([^➔]+)➔/i);
        const newMatch = incText.match(/➔\s*(.+)$/);
        if (oldMatch && newMatch) {
          result[tableIdx] = {
            action: 'table',
            text: `Table : ${oldMatch[1].trim()} ➔ ${newMatch[1].trim()}`,
          };
        } else {
          result[tableIdx] = inc;
        }
      } else {
        result.push(inc);
      }
      continue;
    }

    // Note action: update existing note change if present
    if (incAction === 'note') {
      const noteIdx = result.findIndex((e) => e.action === 'note');
      if (noteIdx !== -1) {
        result[noteIdx] = inc;
      } else {
        result.push(inc);
      }
      continue;
    }

    // Item actions
    const incProd = cleanProductNameFromText(incText);
    if (incProd) {
      // If deleted, check if this item was previously marked as 'added'
      const addedIdx = result.findIndex(
        (e) => e.action === 'added' && cleanProductNameFromText(e.text) === incProd
      );
      if (incAction === 'deleted' && addedIdx !== -1) {
        result[addedIdx] = {
          action: 'deleted',
          text: `Supprimé : ${incProd} (Annulé)`,
          details: incDetails || result[addedIdx].details || null,
        };
        continue;
      }

      // If modified, check if this item was already modified
      const modIdx = result.findIndex(
        (e) => e.action === 'modified' && cleanProductNameFromText(e.text) === incProd
      );
      if (incAction === 'modified' && modIdx !== -1) {
        result[modIdx] = inc;
        continue;
      }

      // If deleted, check if this item was previously modified
      if (incAction === 'deleted' && modIdx !== -1) {
        result.splice(modIdx, 1);
        result.push(inc);
        continue;
      }
    }

    // Default: append modification
    result.push(inc);
  }

  return result;
}

// @desc  Update order (add items, change status, etc.)
// @route PUT /api/orders/:id
exports.updateOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    // Validate table if updating tableNumber or buzzerNumber
    const targetStatus = req.body.status || order.status;
    const targetOrderType = req.body.orderType || order.orderType;

    const rawTable = req.body.tableNumber !== undefined
      ? req.body.tableNumber
      : (req.body.buzzerNumber !== undefined ? req.body.buzzerNumber : null);

    if (rawTable !== null) {
      const table = normalizeTableNumber(rawTable);
      if (table) {
        if (!['terminee', 'annulee'].includes(targetStatus) && targetOrderType === 'sur_place') {
          const occupiedOrder = await Order.findOne({
            _id: { $ne: order._id },
            storeId: order.storeId,
            orderType: 'sur_place',
            status: { $nin: ['terminee', 'annulee'] },
            $or: [
              { tableNumber: table },
              { buzzerNumber: `Table ${table}` },
              { buzzerNumber: table },
              { buzzerNumber: new RegExp(`^Table\\s*${escapeRegex(table)}$`, 'i') },
            ],
          });

          if (occupiedOrder) {
            return res.status(400).json({
              success: false,
              message: `La table ${table} est déjà liée à une commande active (#${occupiedOrder.ticketNumber || occupiedOrder._id}). Elle ne peut pas être réutilisée tant que cette commande n'est pas marquée terminée.`,
              occupiedTable: table,
              activeTicketNumber: occupiedOrder.ticketNumber,
            });
          }
        }
        req.body.tableNumber = table;
        if (!req.body.buzzerNumber && targetOrderType === 'sur_place') {
          req.body.buzzerNumber = `Table ${table}`;
        }
      }
    }

    // Compute changes before assigning req.body to order
    const sessionChanges = computeOrderChanges(order, req.body);

    const incomingSummary = (req.body.modificationSummary && Array.isArray(req.body.modificationSummary) && req.body.modificationSummary.length > 0)
      ? req.body.modificationSummary
      : null;

    const existingSummary = (order.modificationSummary && order.modificationSummary.length > 0)
      ? order.modificationSummary.map(m => (m.toObject ? m.toObject() : m))
      : [];

    let finalSummary = [];
    if (incomingSummary) {
      finalSummary = mergeModifications(existingSummary, incomingSummary);
    } else if (sessionChanges.length > 0) {
      finalSummary = mergeModifications(existingSummary, sessionChanges);
    } else {
      finalSummary = existingSummary;
    }

    // Preserve initialItems snapshot if not present
    if (!order.initialItems || order.initialItems.length === 0) {
      order.initialItems = order.items.slice();
    }

    // Preserve existing delivery details if partial delivery object provided
    if (req.body.delivery && typeof req.body.delivery === 'object') {
      const existingDelivery = order.delivery ? (order.delivery.toObject ? order.delivery.toObject() : order.delivery) : {};
      req.body.delivery = { ...existingDelivery, ...req.body.delivery };
    }

    Object.assign(order, req.body);
    if (req.body.items) order.recalculateTotals();

    if (order.status === 'a_encaisser' && !order.kdsReadyAt) {
      order.kdsReadyAt = new Date();
    }
    if (order.status === 'terminee') {
      if (!order.kdsReadyAt) order.kdsReadyAt = new Date();
      if (!order.completedAt) order.completedAt = new Date();
    }

    // Flag order as edited whenever items/notes/table updated from POS/history
    if (sessionChanges.length > 0 || incomingSummary) {
      order.isEdited = true;
      order.editedAt = new Date();
    }
    order.modificationSummary = finalSummary;

    await order.save();
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Update order status
// @route PATCH /api/orders/:id/status
exports.updateStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    order.status = status;
    if (status === 'a_encaisser') {
      if (!order.kdsReadyAt) order.kdsReadyAt = new Date();
      order.kdsStatus = 'ready';
    }
    if (status === 'terminee') {
      if (!order.kdsReadyAt) order.kdsReadyAt = new Date();
      order.completedAt = new Date();
      order.kdsStatus = 'served';
    }
    if (status === 'annulee') {
      order.cancelledAt = new Date();
      order.cancelReason = req.body.cancelReason;
    }
    // Send to KDS
    if (status === 'en_attente') {
      order.kdsStatus = 'pending';
      order.kdsSentAt = new Date();
    }
    await order.save();
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// @desc  Cancel / refund order
// @route PATCH /api/orders/:id/cancel
exports.cancelOrder = async (req, res) => {
  try {
    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { status: 'annulee', cancelledAt: new Date(), cancelReason: req.body.reason },
      { new: true }
    );
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
    res.json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get daily summary stats
// @route GET /api/orders/stats/daily
exports.getDailyStats = async (req, res) => {
  try {
    const date = req.query.date ? new Date(req.query.date) : new Date();
    const start = new Date(date.setHours(0, 0, 0, 0));
    const end = new Date(date.setHours(23, 59, 59, 999));
    const storeId = req.query.storeId;

    const filter = { createdAt: { $gte: start, $lte: end }, status: { $in: ['terminee', 'en_attente'] } };
    if (storeId) filter.storeId = storeId;

    const stats = await Order.aggregate([
      { $match: filter },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          totalRevenue: { $sum: '$totalTTC' },
          avgOrderValue: { $avg: '$totalTTC' },
          surPlace: { $sum: { $cond: [{ $eq: ['$orderType', 'sur_place'] }, 1, 0] } },
          aEmporter: { $sum: { $cond: [{ $eq: ['$orderType', 'a_emporter'] }, 1, 0] } },
          livraison: { $sum: { $cond: [{ $eq: ['$orderType', 'livraison'] }, 1, 0] } },
        },
      },
    ]);

    res.json({ success: true, data: stats[0] || { totalOrders: 0, totalRevenue: 0 } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// @desc  Get list of currently occupied tables (active orders not yet terminee)
// @route GET /api/orders/occupied-tables
exports.getOccupiedTables = async (req, res) => {
  try {
    const filter = {
      orderType: 'sur_place',
      status: { $nin: ['terminee', 'annulee'] },
    };
    if (req.query.storeId) filter.storeId = req.query.storeId;

    const orders = await Order.find(filter)
      .select('ticketNumber tableNumber buzzerNumber createdAt totalTTC clientName status kdsStatus')
      .sort({ createdAt: -1 });

    const occupied = [];
    const seenTables = new Set();

    for (const o of orders) {
      const tbl = normalizeTableNumber(o.tableNumber || o.buzzerNumber);
      if (tbl && !seenTables.has(tbl.toLowerCase())) {
        seenTables.add(tbl.toLowerCase());
        occupied.push({
          tableNumber: tbl,
          ticketNumber: o.ticketNumber || '',
          orderId: o._id,
          createdAt: o.createdAt,
          clientName: o.clientName || '',
          status: o.status,
        });
      }
    }

    res.json({
      success: true,
      data: occupied,
      tables: occupied.map((o) => o.tableNumber),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};