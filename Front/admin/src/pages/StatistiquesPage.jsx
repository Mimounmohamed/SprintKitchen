import React from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, Circle, Download, Printer, ChevronRight, TrendingUp, TrendingDown } from "lucide-react";
import { statsService } from "../services";

const C = {
  bg: "#F5F4F0", cardBg: "#FFFFFF", ink: "#1C1917", brown: "#2E2117",
  yellow: "#F2B705", yellowBg: "#FCEFCB", muted: "#8B8378", border: "#E7E4DD",
  green: "#2FAE5C", greenBg: "#E6F9EE", red: "#C0392B", redBg: "#FBEAE7", blue: "#2E5BD9",
};

function fmtDA(n) {
  return `${(n || 0).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DA`;
}

/* Period definitions — maps label to { from, to } date ranges */
const PERIODS = ["Aujourd'hui", "Hier", "7 Derniers Jours", "Ce Mois-ci"];

function getPeriodRange(period) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const eod = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);
  if (period === "Aujourd'hui") {
    return { from: today.toISOString(), to: eod(today).toISOString() };
  }
  if (period === "Hier") {
    const y = new Date(today); y.setDate(y.getDate() - 1);
    return { from: y.toISOString(), to: eod(y).toISOString() };
  }
  if (period === "7 Derniers Jours") {
    const s = new Date(today); s.setDate(s.getDate() - 6);
    return { from: s.toISOString(), to: eod(today).toISOString() };
  }
  if (period === "Ce Mois-ci") {
    const s = new Date(today.getFullYear(), today.getMonth(), 1);
    return { from: s.toISOString(), to: eod(today).toISOString() };
  }
  return { from: today.toISOString(), to: eod(today).toISOString() };
}

/* Channel label map */
const CHANNEL_LABELS = {
  sur_place: "Sur Place",
  a_emporter: "A Emporter",
  livraison: "Livraison (Coursiers)",
};

/* Payment method label map */
const PAYMENT_LABELS_MAP = {
  especes: "Espèces (Tiroir Caisse)",
  carte_bancaire: "Carte Bancaire",
  sans_contact: "Carte Bancaire (Sans Contact)",
  ticket_restaurant: "Titres Restaurant / Autres",
  mixte: "Paiement Mixte",
};

const CHANNEL_COLORS = [C.brown, C.muted, C.yellow];
const PAYMENT_COLORS = [C.brown, C.red, C.yellow, C.blue, C.green];

/* ── Sub-components (unchanged UI) ──────────────────────────────────────────── */
function Card({ children, style = {} }) {
  return (
    <div style={{ background: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 14, padding: "16px 18px", ...style }}>
      {children}
    </div>
  );
}

function SecTitle({ children, right }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
      <span style={{ color: "#583926", fontFamily: "'Bebas Neue',sans-serif", fontSize: 18, fontWeight: 400, lineHeight: "22.5px", letterSpacing: "0.45px" }}>
        {children}
      </span>
      {right && <span style={{ fontSize: 11, fontWeight: 600, color: C.muted }}>{right}</span>}
    </div>
  );
}

function Bar({ pct, color }) {
  return (
    <div style={{ height: 6, borderRadius: 3, background: "#EDEAE3" }}>
      <div style={{ height: "100%", width: `${pct}%`, background: color, borderRadius: 3 }} />
    </div>
  );
}

function Delta({ v, up, suffix = "" }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 3, fontSize: 10.5, fontWeight: 700, color: up ? C.green : C.red }}>
      {up ? <TrendingUp size={10} /> : <TrendingDown size={10} />}
      {up ? "+" : "-"}{v}{suffix}
    </span>
  );
}

function KpiCard({ label, value, delta, deltaUp, deltaLabel, sub, icon }) {
  return (
    <Card style={{ minWidth: 0 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 6 }}>
        <span style={{ color: "#78716C", fontFamily: "Inter,sans-serif", fontSize: 10, fontWeight: 700, lineHeight: "15px", letterSpacing: "0.5px", textTransform: "uppercase" }}>
          {label}
        </span>
        {icon && (
          <div style={{ width: 24, height: 24, borderRadius: 6, background: "#F1F0EC", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, flexShrink: 0 }}>
            {icon}
          </div>
        )}
      </div>
      <div style={{ color: "#583926", fontFamily: "'Bebas Neue',sans-serif", fontSize: 24, fontWeight: 400, lineHeight: "24px", letterSpacing: "0.6px", marginTop: 4 }}>
        {value}
      </div>
      {sub && <div style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{sub}</div>}
      {delta !== undefined && (
        <div style={{ display: "flex", alignItems: "center", gap: 5, marginTop: 4 }}>
          <Delta v={delta} up={deltaUp} suffix="%" />
          {deltaLabel && <span style={{ fontSize: 10, color: C.muted }}>{deltaLabel}</span>}
        </div>
      )}
    </Card>
  );
}

/* HourlyChart — receives data as prop */
function HourlyChart({ isMobile, data }) {
  const hourly = data || [];
  /* Filter to business hours (6h–23h) or show all with revenue */
  const bars = hourly.filter(h => h.revenue > 0 || (h.hour >= 11 && h.hour <= 22));
  /* Fallback: show hours 11–22 */
  const display = bars.length > 0 ? bars : hourly.slice(11, 23);
  const maxV = Math.max(...display.map(h => h.revenue), 1);
  const peak = display.reduce((best, h) => h.revenue > best.revenue ? h : best, display[0] || { revenue: 0, hour: 0 });
  const peakLabel = peak ? `${peak.hour}h-${peak.hour + 1}h (${fmtDA(peak.revenue)})` : "";

  return (
    <Card>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8, marginBottom: 10, flexWrap: "wrap" }}>
        <div>
          <div style={{ color: "#583926", fontFamily: "'Bebas Neue',sans-serif", fontSize: 18, fontWeight: 400, lineHeight: "22.5px", letterSpacing: "0.45px" }}>
            Evolution des Ventes par Heure
          </div>
          <div style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>Distribution du CA sur la période</div>
        </div>
        {peakLabel && (
          <span style={{ fontSize: 10.5, fontWeight: 700, background: C.yellowBg, color: C.brown, padding: "3px 9px", borderRadius: 6, whiteSpace: "nowrap", flexShrink: 0 }}>
            Pic : {peakLabel}
          </span>
        )}
      </div>
      {display.length === 0 ? (
        <div style={{ padding: "30px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>Aucune donnée</div>
      ) : (
        <>
          <div style={{ textAlign: "right", fontSize: 9.5, color: C.muted, marginBottom: 3 }}>{Math.round(maxV)} DA</div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: isMobile ? 3 : 5, height: 110 }}>
            {display.map((bar, i) => {
              const pct = bar.revenue / maxV;
              const isPeak = peak && bar.hour === peak.hour;
              const isActive = i === display.length - 1;
              return (
                <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "flex-end", height: "100%", gap: 2 }}>
                  {isPeak && (
                    <span style={{ fontSize: 8, fontWeight: 800, background: C.yellow, color: C.brown, padding: "1px 3px", borderRadius: 3 }}>
                      {Math.round(pct * 100)}%
                    </span>
                  )}
                  <div style={{ width: "100%", borderRadius: "3px 3px 0 0", height: `${Math.max(pct * 100, 2)}%`, background: isPeak ? C.brown : isActive ? C.yellow : "#D4CFC8" }} />
                </div>
              );
            })}
          </div>
          <div style={{ display: "flex", gap: isMobile ? 3 : 5, marginTop: 5 }}>
            {display.map((bar, i) => (
              <div key={i} style={{ flex: 1, textAlign: "center", fontSize: 8.5, color: i === display.length - 1 ? C.yellow : C.muted, fontWeight: i === display.length - 1 ? 700 : 400 }}>
                {bar.hour}h
              </div>
            ))}
          </div>
        </>
      )}
    </Card>
  );
}

/* TopArticles — receives data as prop */
function TopArticles({ data, totalCA }) {
  const items = (data || []).slice(0, 4).map((a, i) => ({ ...a, rank: i + 1 }));
  const total = items.reduce((s, a) => s + a.revenue, 0);
  const pctOfCA = totalCA > 0 ? ((total / totalCA) * 100).toFixed(1) : "0.0";

  return (
    <Card>
      <SecTitle right={`Top ${items.length}`}>Articles les Plus Vendus</SecTitle>
      <div style={{ fontSize: 11, color: C.muted, marginTop: -8, marginBottom: 12 }}>Classement par volume de commande</div>
      {items.length === 0 && (
        <div style={{ padding: "20px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>Aucune donnée</div>
      )}
      {items.map((a, i) => (
        <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 0", borderBottom: i < items.length - 1 ? `1px solid ${C.border}` : "none" }}>
          <div style={{ width: 24, height: 24, borderRadius: "50%", background: a.rank === 1 ? C.brown : a.rank === 2 ? "#6B7280" : "#B58B3A", color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 800, flexShrink: 0 }}>
            {a.rank}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{a.productName}</div>
            <div style={{ fontSize: 10.5, color: C.muted }}>{a.qty} unités vendues</div>
          </div>
          <div style={{ textAlign: "right", flexShrink: 0 }}>
            <div style={{ fontSize: 12.5, fontWeight: 700, color: C.ink }}>{fmtDA(a.revenue)}</div>
            {a.percent != null && <div style={{ fontSize: 10, color: C.muted }}>{a.percent}%</div>}
          </div>
        </div>
      ))}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 12, paddingTop: 12, borderTop: `1px solid ${C.border}` }}>
        <span style={{ fontSize: 11, color: C.muted }}>Total : {pctOfCA}% du CA</span>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 3, fontSize: 11, fontWeight: 700, color: C.blue, cursor: "pointer" }}>
          Catalogue complet <ChevronRight size={12} />
        </span>
      </div>
    </Card>
  );
}

/* Canaux — receives data as prop */
function Canaux({ data }) {
  const items = (data || []).map((c, i) => ({
    label: CHANNEL_LABELS[c.channel] || c.channel,
    tickets: c.orderCount,
    pct: c.percent,
    color: CHANNEL_COLORS[i % CHANNEL_COLORS.length],
  }));

  return (
    <Card>
      <SecTitle right="Tickets">Canaux de Restauration</SecTitle>
      <div style={{ fontSize: 11, color: C.muted, marginTop: -8, marginBottom: 14 }}>Volume de tickets par type de service</div>
      {items.length === 0 && (
        <div style={{ padding: "20px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>Aucune donnée</div>
      )}
      {items.map((canal, i) => (
        <div key={i} style={{ marginBottom: i < items.length - 1 ? 14 : 0 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <span style={{ width: 9, height: 9, borderRadius: 2, background: canal.color, display: "inline-block", flexShrink: 0 }} />
              <span style={{ fontSize: 12, fontWeight: 600, color: C.ink }}>{canal.label}</span>
            </div>
            <span style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>
              {canal.tickets} <span style={{ fontWeight: 400, color: C.muted }}>({canal.pct}%)</span>
            </span>
          </div>
          <Bar pct={canal.pct} color={canal.color} />
        </div>
      ))}
    </Card>
  );
}

/* Moyens de paiement card */
function Paiements({ data }) {
  const items = (data || []).map((p, i) => ({
    label: PAYMENT_LABELS_MAP[p.method] || p.method,
    amount: p.total,
    pct: p.percent,
    color: PAYMENT_COLORS[i % PAYMENT_COLORS.length],
  }));

  return (
    <Card>
      <SecTitle right="Montant">Moyens de Paiement</SecTitle>
      <div style={{ fontSize: 11, color: C.muted, marginTop: -8, marginBottom: 14 }}>Répartition par mode d'encaissement</div>
      {items.length === 0 && (
        <div style={{ padding: "20px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>Aucune donnée</div>
      )}
      {items.map((p, i) => (
        <div key={i} style={{ marginBottom: i < items.length - 1 ? 14 : 0 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <span style={{ width: 9, height: 9, borderRadius: 2, background: p.color, display: "inline-block", flexShrink: 0 }} />
              <span style={{ fontSize: 12, fontWeight: 600, color: C.ink }}>{p.label}</span>
            </div>
            <span style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>
              {fmtDA(p.amount)} <span style={{ fontWeight: 400, color: C.muted }}>({p.pct}%)</span>
            </span>
          </div>
          <Bar pct={p.pct} color={p.color} />
        </div>
      ))}
    </Card>
  );
}

/* ── Page ────────────────────────────────────────────────────────────────────── */
export default function StatistiquesPage() {
  const navigate = useNavigate();
  const [period, setPeriod] = React.useState("Aujourd'hui");
  const [mobile, setMobile] = React.useState(window.innerWidth < 900);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState(null);
  const [summary, setSummary] = React.useState(null);

  React.useEffect(() => {
    const h = () => setMobile(window.innerWidth < 900);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);

  React.useEffect(() => {
    const range = getPeriodRange(period);
    setLoading(true);
    setError(null);
    statsService.getSummary({ from: range.from, to: range.to })
      .then(res => {
        setSummary(res.data.data);
      })
      .catch(e => {
        console.error("StatistiquesPage: failed to load summary", e);
        setError("Erreur de chargement des statistiques.");
      })
      .finally(() => setLoading(false));
  }, [period]);

  /* Derive display values from API data (with safe fallbacks) */
  const rz = summary?.rapportZ || {};
  const ca = rz.totalTTC || 0;
  const tickets = rz.ticketCount || 0;
  const panier = rz.avgBasket || 0;
  const tva = rz.totalTVA || 0;

  const salesByHour = summary?.salesByHour || [];
  const topProducts = summary?.topProducts || [];
  const byChannel = summary?.byChannel || [];
  const paymentMethods = summary?.paymentMethods || [];

  const pad = mobile ? "14px 14px" : "24px 32px 40px";

  const spinner = (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", padding: "60px 0" }}>
      <div style={{
        width: 32, height: 32,
        border: `3px solid ${C.border}`,
        borderTopColor: C.yellow,
        borderRadius: "50%",
        animation: "spin .7s linear infinite",
      }} />
    </div>
  );

  return (
    <div style={{ minHeight: "100vh", background: C.bg, fontFamily: "'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif", color: C.ink, display: "flex", flexDirection: "column" }}>

      {/* Header */}
      <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: mobile ? "11px 14px" : "13px 32px", borderBottom: `1px solid ${C.border}`, background: C.cardBg, flexShrink: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <button onClick={() => navigate("/")} style={{ display: "inline-flex", alignItems: "center", gap: 7, fontSize: 12.5, fontWeight: 600, color: C.ink, background: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 8, padding: "7px 12px", cursor: "pointer", fontFamily: "inherit" }}>
            <ArrowLeft size={13} />{mobile ? "" : "Retour au Hub"}
          </button>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 28, height: 28, borderRadius: "50%", background: C.brown, color: C.yellow, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 800 }}>SK</div>
            {!mobile && <span style={{ fontSize: 14, fontWeight: 800, letterSpacing: "0.02em" }}>SPRINTKITCHEN</span>}
          </div>
        </div>
      </header>

      {/* Main */}
      <main style={{ flex: 1, padding: pad, maxWidth: 1340, margin: "0 auto", width: "100%", boxSizing: "border-box" }}>
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.06em", color: C.muted, marginBottom: 4 }}>
            PORTAIL OPÉRATIONNEL &bull; <span style={{ color: C.green }}>RAPPORTS &amp; STATISTIQUES</span>
          </div>
          <h1 style={{ margin: "0 0 4px", color: "#583926", fontFamily: "'Bebas Neue',sans-serif", fontSize: 30, fontWeight: 400, lineHeight: "30px", letterSpacing: "0.75px" }}>
            RAPPORTS &amp; STATISTIQUES
          </h1>
          <p style={{ margin: 0, fontSize: 12, color: C.muted }}>Performances de caisse et export comptable en direct.</p>
        </div>

        {/* Period tabs */}
        <div style={{ display: "flex", gap: 6, overflowX: "auto", paddingBottom: 4, marginBottom: 14 }}>
          {PERIODS.map(p => (
            <button key={p} onClick={() => setPeriod(p)}
              style={{ padding: "9px 15px", borderRadius: 9, border: `1px solid ${period === p ? C.brown : C.border}`, background: period === p ? C.brown : C.cardBg, color: period === p ? "#F5F0E6" : C.ink, fontSize: 12.5, fontWeight: 700, cursor: "pointer", fontFamily: "inherit", whiteSpace: "nowrap", flexShrink: 0 }}>
              {p}
            </button>
          ))}
        </div>

        {/* Action buttons */}
        <div style={{ display: "flex", flexDirection: mobile ? "column" : "row", gap: 10, marginBottom: 20 }}>
          <button style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 10, padding: "13px 20px", borderRadius: 11, border: "none", background: "#FACC15", color: "#583926", cursor: "pointer", fontFamily: "inherit", flex: mobile ? undefined : 1 }}>
            <Printer size={15} />
            <span style={{ color: "#583926", textAlign: "center", fontFamily: "Inter,sans-serif", fontSize: 12, fontWeight: 700, lineHeight: "16px", letterSpacing: "0.6px", textTransform: "uppercase" }}>
              CLÔTURE DE CAISSE
            </span>
          </button>
          <button style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8, padding: "11px 20px", borderRadius: 11, border: `1px solid ${C.border}`, background: C.cardBg, color: C.ink, fontSize: 13, fontWeight: 600, cursor: "pointer", fontFamily: "inherit", flexShrink: 0 }}>
            <Download size={14} /> Exporter (.CSV)
          </button>
        </div>

        {/* Error banner */}
        {error && (
          <div style={{ background: C.redBg, color: C.red, padding: "12px 16px", borderRadius: 10, fontSize: 13, fontWeight: 600, marginBottom: 16 }}>
            {error}
          </div>
        )}

        {/* Loading / content */}
        {loading ? spinner : (
          <>
            {/* KPI cards */}
            <div style={{ display: "grid", gridTemplateColumns: mobile ? "1fr 1fr" : "repeat(3,1fr)", gap: 12, marginBottom: 16 }}>
              <KpiCard
                label="Chiffre d'Affaires"
                value={fmtDA(ca)}
                icon={<TrendingUp size={13} color={C.green} />}
              />
              <KpiCard
                label="Tickets Clôturés"
                value={tickets}
                icon={<Printer size={13} color={C.muted} />}
              />
              <KpiCard
                label="Panier Moyen"
                value={fmtDA(panier)}
                icon={<Download size={13} color={C.blue} />}
              />
            </div>

            {/* TVA summary row */}
            {tva > 0 && (
              <div style={{ marginBottom: 16 }}>
                <Card>
                  <div style={{ display: "flex", alignItems: "center", gap: 24, flexWrap: "wrap" }}>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase", marginBottom: 3 }}>Total HT</div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: C.ink }}>{fmtDA(rz.totalHT)}</div>
                    </div>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase", marginBottom: 3 }}>TVA Collectée</div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: C.ink }}>{fmtDA(tva)}</div>
                    </div>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase", marginBottom: 3 }}>Total TTC</div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: C.ink }}>{fmtDA(ca)}</div>
                    </div>
                    {rz.annulees && rz.annulees.count > 0 && (
                      <div>
                        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase", marginBottom: 3 }}>Annulations</div>
                        <div style={{ fontSize: 15, fontWeight: 700, color: C.red }}>
                          {rz.annulees.count} ticket{rz.annulees.count > 1 ? "s" : ""} ({fmtDA(rz.annulees.amount)})
                        </div>
                      </div>
                    )}
                  </div>
                </Card>
              </div>
            )}

            {/* Charts & tables */}
            {mobile ? (
              <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <HourlyChart isMobile={true} data={salesByHour} />
                <TopArticles data={topProducts} totalCA={ca} />
                <Canaux data={byChannel} />
                <Paiements data={paymentMethods} />
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                <div style={{ display: "grid", gridTemplateColumns: "1.55fr 1fr", gap: 16 }}>
                  <HourlyChart isMobile={false} data={salesByHour} />
                  <TopArticles data={topProducts} totalCA={ca} />
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
                  <Canaux data={byChannel} />
                  <Paiements data={paymentMethods} />
                </div>
              </div>
            )}
          </>
        )}
      </main>

      {/* Footer */}
      <footer style={{ display: "flex", alignItems: "center", padding: mobile ? "11px 14px" : "13px 32px", borderTop: `1px solid ${C.border}`, flexShrink: 0 }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 11.5, fontWeight: 600, color: C.ink }}>
          <Circle size={6} fill={C.green} color={C.green} /> Connecté
        </span>
      </footer>

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
