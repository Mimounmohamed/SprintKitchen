const Order   = require('../models/Order');
const Payment = require('../models/Payment');

/* helpers */
function parseDateRange(query) {
  const now  = new Date();
  const from = query.from ? new Date(query.from) : new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const to   = query.to   ? new Date(query.to)   : new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  return { from, to };
}
function regF(q) { return q.registerId ? { registerId: q.registerId } : {}; }

/* ── GET /api/stats/rapport-z ─────────────────────────────── */
exports.getRapportZ = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);
    const baseMatch = { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } };

    const [[totals], payBreak, [annulees], repasCount] = await Promise.all([
      Order.aggregate([
        { $match: baseMatch },
        { $group: { _id: null, totalTTC: { $sum: '$totalTTC' }, totalHT: { $sum: '$subtotalHT' }, totalTVA: { $sum: '$tvaAmount' }, ticketCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } },
      ]),
      Payment.aggregate([
        { $match: { ...rf, createdAt: { $gte: from, $lte: to }, isRefunded: { $ne: true } } },
        { $group: { _id: '$method', total: { $sum: '$amountDue' }, count: { $sum: 1 } } },
        { $sort: { total: -1 } },
      ]),
      Order.aggregate([
        { $match: { ...rf, status: 'annulee', createdAt: { $gte: from, $lte: to } } },
        { $group: { _id: null, count: { $sum: 1 }, amount: { $sum: '$totalTTC' } } },
      ]),
      Order.countDocuments({ ...rf, status: 'repas_employe', createdAt: { $gte: from, $lte: to } }),
    ]);

    res.json({
      success: true,
      data: {
        period: { from, to },
        totalTTC:    Math.round((totals?.totalTTC   ?? 0) * 100) / 100,
        totalHT:     Math.round((totals?.totalHT    ?? 0) * 100) / 100,
        totalTVA:    Math.round((totals?.totalTVA   ?? 0) * 100) / 100,
        ticketCount: totals?.ticketCount ?? 0,
        avgBasket:   Math.round((totals?.avgBasket  ?? 0) * 100) / 100,
        annulees:    { count: annulees?.count ?? 0, amount: Math.round((annulees?.amount ?? 0) * 100) / 100 },
        repasEmployeCount: repasCount,
        paymentBreakdown: payBreak.map(p => ({ method: p._id, total: Math.round(p.total * 100) / 100, count: p.count })),
      },
    });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/sales-by-hour ─────────────────────────── */
exports.getSalesByHour = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);

    const raw = await Order.aggregate([
      { $match: { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } } },
      { $group: { _id: { $hour: { date: '$createdAt', timezone: 'Europe/Paris' } }, revenue: { $sum: '$totalTTC' }, orderCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } },
      { $sort: { _id: 1 } },
      { $project: { _id: 0, hour: '$_id', revenue: { $round: ['$revenue', 2] }, orderCount: 1, avgBasket: { $round: ['$avgBasket', 2] } } },
    ]);

    const data = Array.from({ length: 24 }, (_, h) => raw.find(d => d.hour === h) ?? { hour: h, revenue: 0, orderCount: 0, avgBasket: 0 });
    res.json({ success: true, data });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/top-products ──────────────────────────── */
exports.getTopProducts = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf    = regF(req.query);
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);

    const raw = await Order.aggregate([
      { $match: { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } } },
      { $unwind: '$items' },
      { $group: { _id: '$items.productId', productName: { $first: '$items.productName' }, qty: { $sum: '$items.quantity' }, revenue: { $sum: '$items.lineTotal' }, orderCount: { $sum: 1 } } },
      { $sort: { qty: -1 } },
      { $limit: limit },
      { $project: { _id: 0, productId: '$_id', productName: 1, qty: 1, revenue: { $round: ['$revenue', 2] }, orderCount: 1 } },
    ]);

    const totalQty = raw.reduce((s, d) => s + d.qty, 0);
    const data = raw.map(d => ({ ...d, percent: totalQty > 0 ? Math.round((d.qty / totalQty) * 100) : 0 }));
    res.json({ success: true, data });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/by-channel ────────────────────────────── */
exports.getByChannel = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);

    const raw = await Order.aggregate([
      { $match: { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } } },
      { $group: { _id: '$orderType', revenue: { $sum: '$totalTTC' }, orderCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } },
      { $project: { _id: 0, channel: '$_id', revenue: { $round: ['$revenue', 2] }, orderCount: 1, avgBasket: { $round: ['$avgBasket', 2] } } },
      { $sort: { revenue: -1 } },
    ]);

    const totalRev = raw.reduce((s, d) => s + d.revenue, 0);
    const data = raw.map(d => ({ ...d, percent: totalRev > 0 ? Math.round((d.revenue / totalRev) * 100) : 0 }));
    res.json({ success: true, data });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/sales-trend ───────────────────────────── */
exports.getSalesTrend = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);

    const data = await Order.aggregate([
      { $match: { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt', timezone: 'Europe/Paris' } }, revenue: { $sum: '$totalTTC' }, orderCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } },
      { $sort: { _id: 1 } },
      { $project: { _id: 0, date: '$_id', revenue: { $round: ['$revenue', 2] }, orderCount: 1, avgBasket: { $round: ['$avgBasket', 2] } } },
    ]);

    res.json({ success: true, data });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/kpis ──────────────────────────────────── */
exports.getKpis = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);

    const duration = to.getTime() - from.getTime();
    const prevFrom = new Date(from.getTime() - duration - 1);
    const prevTo   = new Date(from.getTime() - 1);

    const agg = (dateFrom, dateTo) => Order.aggregate([
      { $match: { ...rf, status: 'terminee', createdAt: { $gte: dateFrom, $lte: dateTo } } },
      { $group: { _id: null, totalTTC: { $sum: '$totalTTC' }, ticketCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } },
    ]);

    const [[current], [previous]] = await Promise.all([agg(from, to), agg(prevFrom, prevTo)]);

    const pct = (c, p) => (p && p !== 0) ? Math.round(((c - p) / p) * 100) : null;

    res.json({
      success: true,
      data: {
        period: { from, to },
        current:  { totalTTC: current?.totalTTC ?? 0, ticketCount: current?.ticketCount ?? 0, avgBasket: current?.avgBasket ?? 0 },
        previous: { totalTTC: previous?.totalTTC ?? 0, ticketCount: previous?.ticketCount ?? 0, avgBasket: previous?.avgBasket ?? 0 },
        evolution: {
          totalTTC:    pct(current?.totalTTC ?? 0, previous?.totalTTC),
          ticketCount: pct(current?.ticketCount ?? 0, previous?.ticketCount),
          avgBasket:   pct(current?.avgBasket ?? 0, previous?.avgBasket),
        },
      },
    });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/payment-methods ───────────────────────── */
exports.getPaymentMethods = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);

    const raw = await Payment.aggregate([
      { $match: { ...rf, isRefunded: { $ne: true }, createdAt: { $gte: from, $lte: to } } },
      { $group: { _id: '$method', total: { $sum: '$amountDue' }, count: { $sum: 1 } } },
      { $sort: { total: -1 } },
    ]);

    const grandTotal = raw.reduce((s, d) => s + d.total, 0);
    const data = raw.map(d => ({ method: d._id, total: Math.round(d.total * 100) / 100, count: d.count, percent: grandTotal > 0 ? Math.round((d.total / grandTotal) * 100) : 0 }));
    res.json({ success: true, data, grandTotal: Math.round(grandTotal * 100) / 100 });
  } catch (err) { next(err); }
};

/* ── GET /api/stats/summary  (one-shot for the stats page) ── */
exports.getSummary = async (req, res, next) => {
  try {
    const { from, to } = parseDateRange(req.query);
    const rf = regF(req.query);
    const baseMatch = { ...rf, status: 'terminee', createdAt: { $gte: from, $lte: to } };

    const [totalsArr, byHourArr, topPArr, byChanArr, payArr, annArr] = await Promise.all([
      Order.aggregate([{ $match: baseMatch }, { $group: { _id: null, totalTTC: { $sum: '$totalTTC' }, totalHT: { $sum: '$subtotalHT' }, totalTVA: { $sum: '$tvaAmount' }, ticketCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } }]),
      Order.aggregate([{ $match: baseMatch }, { $group: { _id: { $hour: { date: '$createdAt', timezone: 'Europe/Paris' } }, revenue: { $sum: '$totalTTC' }, orderCount: { $sum: 1 } } }, { $sort: { _id: 1 } }, { $project: { _id: 0, hour: '$_id', revenue: { $round: ['$revenue', 2] }, orderCount: 1 } }]),
      Order.aggregate([{ $match: baseMatch }, { $unwind: '$items' }, { $group: { _id: '$items.productId', productName: { $first: '$items.productName' }, qty: { $sum: '$items.quantity' }, revenue: { $sum: '$items.lineTotal' } } }, { $sort: { qty: -1 } }, { $limit: 10 }, { $project: { _id: 0, productId: '$_id', productName: 1, qty: 1, revenue: { $round: ['$revenue', 2] } } }]),
      Order.aggregate([{ $match: baseMatch }, { $group: { _id: '$orderType', revenue: { $sum: '$totalTTC' }, orderCount: { $sum: 1 }, avgBasket: { $avg: '$totalTTC' } } }, { $project: { _id: 0, channel: '$_id', revenue: { $round: ['$revenue', 2] }, orderCount: 1, avgBasket: { $round: ['$avgBasket', 2] } } }, { $sort: { revenue: -1 } }]),
      Payment.aggregate([{ $match: { ...rf, isRefunded: { $ne: true }, createdAt: { $gte: from, $lte: to } } }, { $group: { _id: '$method', total: { $sum: '$amountDue' }, count: { $sum: 1 } } }, { $sort: { total: -1 } }]),
      Order.aggregate([{ $match: { ...rf, status: 'annulee', createdAt: { $gte: from, $lte: to } } }, { $group: { _id: null, count: { $sum: 1 }, amount: { $sum: '$totalTTC' } } }]),
    ]);

    const t   = totalsArr[0]  ?? {};
    const ann = annArr[0]     ?? {};
    const gp  = payArr.reduce((s, p) => s + p.total, 0);
    const tq  = topPArr.reduce((s, p) => s + p.qty, 0);
    const tr  = byChanArr.reduce((s, c) => s + c.revenue, 0);

    const salesByHour = Array.from({ length: 24 }, (_, h) => byHourArr.find(d => d.hour === h) ?? { hour: h, revenue: 0, orderCount: 0 });

    res.json({
      success: true,
      data: {
        period: { from, to },
        rapportZ: {
          totalTTC:    Math.round((t.totalTTC   ?? 0) * 100) / 100,
          totalHT:     Math.round((t.totalHT    ?? 0) * 100) / 100,
          totalTVA:    Math.round((t.totalTVA   ?? 0) * 100) / 100,
          ticketCount: t.ticketCount ?? 0,
          avgBasket:   Math.round((t.avgBasket  ?? 0) * 100) / 100,
          annulees:    { count: ann.count ?? 0, amount: Math.round((ann.amount ?? 0) * 100) / 100 },
        },
        salesByHour,
        topProducts: topPArr.map(p => ({ ...p, percent: tq > 0 ? Math.round((p.qty / tq) * 100) : 0 })),
        byChannel:   byChanArr.map(c => ({ ...c, percent: tr > 0 ? Math.round((c.revenue / tr) * 100) : 0 })),
        paymentMethods: payArr.map(p => ({ method: p._id, total: Math.round(p.total * 100) / 100, count: p.count, percent: gp > 0 ? Math.round((p.total / gp) * 100) : 0 })),
      },
    });
  } catch (err) { next(err); }
};
