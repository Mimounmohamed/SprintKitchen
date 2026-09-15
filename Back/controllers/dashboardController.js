const Order      = require('../models/Order');
const Ingredient = require('../models/Ingredient');

/**
 * GET /api/dashboard
 * Returns live KPIs for the admin portal:
 *   - revenue.today        (sum of totalTTC for terminee orders today)
 *   - revenue.vsLastYear   (% change vs same calendar day last year)
 *   - tickets.today        (count of terminee orders today)
 *   - rupture.count        (ingredients on 86 list)
 *   - rupture.items        (names of épuisé ingredients, max 10)
 */
exports.getDashboardKpis = async (req, res, next) => {
  try {
    // ── Date ranges ────────────────────────────────────────────────────────────
    const now   = new Date();
    const todayStart = new Date(now); todayStart.setHours(0,0,0,0);
    const todayEnd   = new Date(now); todayEnd.setHours(23,59,59,999);

    // Same day last year
    const ly = new Date(now);
    ly.setFullYear(ly.getFullYear() - 1);
    const lyStart = new Date(ly); lyStart.setHours(0,0,0,0);
    const lyEnd   = new Date(ly); lyEnd.setHours(23,59,59,999);

    // ── Parallel queries ───────────────────────────────────────────────────────
    const [todayAgg, lyAgg, ruptureList] = await Promise.all([

      // Today revenue + ticket count
      Order.aggregate([
        { $match: {
            status: 'terminee',
            createdAt: { $gte: todayStart, $lte: todayEnd },
        }},
        { $group: {
            _id: null,
            totalTTC: { $sum: '$totalTTC' },
            count:    { $sum: 1 },
        }},
      ]),

      // Last year same day revenue
      Order.aggregate([
        { $match: {
            status: 'terminee',
            createdAt: { $gte: lyStart, $lte: lyEnd },
        }},
        { $group: {
            _id: null,
            totalTTC: { $sum: '$totalTTC' },
        }},
      ]),

      // Épuisé ingredients
      Ingredient.find(
        { availability: { $ne: 'available' }, isActive: true },
        'name family availability'
      ).sort('family name').limit(20),

    ]);

    const revenueToday  = todayAgg[0]?.totalTTC  || 0;
    const ticketsToday  = todayAgg[0]?.count      || 0;
    const revenueLY     = lyAgg[0]?.totalTTC      || 0;

    // % change vs last year (null if no LY data)
    let vsLastYear = null;
    if (revenueLY > 0) {
      vsLastYear = Math.round(((revenueToday - revenueLY) / revenueLY) * 100);
    }

    res.json({
      success: true,
      data: {
        revenue: {
          today:      Math.round(revenueToday * 100) / 100,
          vsLastYear, // number (e.g. 14) or null
        },
        tickets: {
          today: ticketsToday,
        },
        rupture: {
          count: ruptureList.length,
          items: ruptureList.map(i => ({
            _id:          i._id,
            name:         i.name,
            family:       i.family,
            availability: i.availability,
          })),
        },
      },
    });
  } catch (err) { next(err); }
};
