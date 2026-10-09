import React from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft,
  Circle,
  Download,
  Printer,
  ChevronRight,
  TrendingUp,
  TrendingDown,
  UtensilsCrossed,
  Clock,
  Zap,
  Timer,
  ShoppingBag,
  CreditCard,
  AlertTriangle,
  Receipt,
  Store,
} from "lucide-react";
import { statsService } from "../services";

const C = {
  bg: "#F5F4F0",
  cardBg: "#FFFFFF",
  ink: "#1C1917",
  brown: "#583926",
  yellow: "#FACC15",
  yellowBg: "#FEF08A",
  muted: "#6B7280",
  border: "#E5E7EB",
  borderDark: "#D1D5DB",
  green: "#059669",
  greenBg: "#E8F8EF",
  orange: "#F97316",
  orangeBg: "#FFEDD5",
  red: "#EF4444",
  redBg: "#FDEAE8",
  blue: "#2563EB",
  blueBg: "#EFF6FF",
};

const FONT_TITLE = "'Bebas Neue', sans-serif";
const FONT_BODY = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

function fmtDA(n) {
  return `${(n || 0).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DA`;
}

function fmtDuration(sec) {
  if (sec === null || sec === undefined || isNaN(sec) || sec <= 0) return "--";
  if (sec < 60) return `${sec}s`;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  if (m >= 60) {
    const h = Math.floor(m / 60);
    const remM = m % 60;
    return `${h}h ${remM.toString().padStart(2, "0")}m`;
  }
  return s > 0 ? `${m}m ${s.toString().padStart(2, "0")}s` : `${m} min`;
}

/* Period definitions — maps label to { from, to } date ranges */
const PERIODS = ["Aujourd'hui", "Hier", "7 Derniers Jours", "Ce Mois-ci"];

function getPeriodRange(period) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const eod = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);
  if (period === "Aujourd'hui") {
    return { from: today.toISOString(), to: eod(today).toISOString() };
  }
  if (period === "Hier") {
    const y = new Date(today);
    y.setDate(y.getDate() - 1);
    return { from: y.toISOString(), to: eod(y).toISOString() };
  }
  if (period === "7 Derniers Jours") {
    const s = new Date(today);
    s.setDate(s.getDate() - 6);
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
  a_emporter: "À Emporter",
  livraison: "Livraison (Coursiers)",
};

/* Payment method label map */
const PAYMENT_LABELS_MAP = {
  especes: "Espèces (Tiroir Caisse)",
  carte_bancaire: "Carte CIB / Edahabia",
  sans_contact: "Carte Sans Contact",
  ticket_restaurant: "Titres Restaurant / Chèques",
  mixte: "Paiement Mixte",
};

const CHANNEL_COLORS = [C.brown, "#B58B3A", C.yellow];
const PAYMENT_COLORS = [C.brown, C.blue, C.green, "#8B5CF6", C.yellow];

/* ── UI Components ─────────────────────────────────────────────────────────── */
function Card({ children, style = {} }) {
  return (
    <div
      style={{
        background: C.cardBg,
        border: `1px solid ${C.border}`,
        borderRadius: 14,
        padding: "18px 20px",
        boxShadow: "0 1px 3px rgba(0,0,0,0.03)",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

function SecTitle({ children, right, icon }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        {icon && <span style={{ color: C.brown, display: "flex", alignItems: "center" }}>{icon}</span>}
        <span
          style={{
            color: "#583926",
            fontFamily: FONT_TITLE,
            fontSize: 20,
            fontWeight: 400,
            lineHeight: 1.1,
            letterSpacing: "0.5px",
          }}
        >
          {children}
        </span>
      </div>
      {right && <span style={{ fontSize: 11.5, fontWeight: 700, color: C.muted }}>{right}</span>}
    </div>
  );
}

function Bar({ pct, color }) {
  return (
    <div style={{ height: 7, borderRadius: 4, background: "#EDEAE3", overflow: "hidden" }}>
      <div
        style={{
          height: "100%",
          width: `${Math.min(Math.max(pct, 0), 100)}%`,
          background: color,
          borderRadius: 4,
          transition: "width 0.4s ease",
        }}
      />
    </div>
  );
}

function KpiCard({ label, value, sub, icon, bgIcon = "#F1F0EC", badge, badgeColor = C.green }) {
  return (
    <Card style={{ minWidth: 0 }}>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 6 }}>
        <span
          style={{
            color: "#78716C",
            fontFamily: "Inter,sans-serif",
            fontSize: 10.5,
            fontWeight: 700,
            letterSpacing: "0.5px",
            textTransform: "uppercase",
          }}
        >
          {label}
        </span>
        {icon && (
          <div
            style={{
              width: 30,
              height: 30,
              borderRadius: 8,
              background: bgIcon,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            {icon}
          </div>
        )}
      </div>
      <div
        style={{
          color: "#583926",
          fontFamily: FONT_TITLE,
          fontSize: 27,
          fontWeight: 400,
          lineHeight: 1.1,
          letterSpacing: "0.6px",
          marginTop: 4,
          wordBreak: "break-word",
        }}
      >
        {value}
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 6, flexWrap: "wrap", gap: 4 }}>
        {sub && <div style={{ fontSize: 11, color: C.muted, fontWeight: 500 }}>{sub}</div>}
        {badge && (
          <span
            style={{
              fontSize: 10,
              fontWeight: 700,
              padding: "2px 6px",
              borderRadius: 4,
              background: `${badgeColor}15`,
              color: badgeColor,
            }}
          >
            {badge}
          </span>
        )}
      </div>
    </Card>
  );
}

/* ── Kitchen Performance Card ──────────────────────────────────────────────── */
function KitchenPerformanceCard({ kitchen }) {
  const k = kitchen || {};
  const avgSec = k.avgPrepTimeSeconds || 0;
  const count = k.ordersPreparedCount || 0;
  const fastest = k.fastestOrder;
  const slowest = k.slowestOrder;
  const dist = k.distribution || [];

  return (
    <Card style={{ background: "#FFFFFF", border: `1.5px solid #E5E7EB` }}>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", flexWrap: "wrap", gap: 10, marginBottom: 14 }}>
        <div>
          <SecTitle icon={<Timer size={18} color="#059669" />} right={`${count} commandes analysées`}>
            Performance &amp; Vitesse Cuisine (KDS)
          </SecTitle>
          <div style={{ fontSize: 11.5, color: C.muted, marginTop: -8 }}>
            Temps écoulé moyen entre l'envoi du ticket et la finalisation en cuisine
          </div>
        </div>

        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 6,
            background: avgSec > 0 && avgSec <= 600 ? C.greenBg : C.yellowBg,
            color: avgSec > 0 && avgSec <= 600 ? C.green : C.brown,
            padding: "5px 12px",
            borderRadius: 8,
            fontWeight: 800,
            fontSize: 12,
            border: `1px solid ${avgSec > 0 && avgSec <= 600 ? "#A7F3D0" : "#FDE047"}`,
          }}
        >
          <Clock size={13} />
          Moyenne : {fmtDuration(avgSec)}
        </div>
      </div>

      {count === 0 ? (
        <div style={{ padding: "26px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>
          Aucune commande traitée en cuisine sur cette période.
        </div>
      ) : (
        <>
          {/* 3 highlight boxes */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
              gap: 12,
              marginBottom: 16,
            }}
          >
            <div
              style={{
                background: "#F9FAFB",
                border: "1px solid #E5E7EB",
                borderRadius: 10,
                padding: "12px 14px",
              }}
            >
              <div style={{ fontSize: 10, fontWeight: 700, color: C.muted, textTransform: "uppercase", letterSpacing: "0.5px" }}>
                Temps Moyen Préparation
              </div>
              <div style={{ fontSize: 22, fontWeight: 800, color: C.green, fontFamily: FONT_TITLE, letterSpacing: "0.5px", marginTop: 4 }}>
                {fmtDuration(avgSec)}
              </div>
              <div style={{ fontSize: 10.5, color: C.muted, marginTop: 2 }}>Moyenne par commande</div>
            </div>

            <div
              style={{
                background: "#F9FAFB",
                border: "1px solid #E5E7EB",
                borderRadius: 10,
                padding: "12px 14px",
              }}
            >
              <div style={{ fontSize: 10, fontWeight: 700, color: C.muted, textTransform: "uppercase", letterSpacing: "0.5px" }}>
                Commande Express (Record)
              </div>
              <div style={{ fontSize: 22, fontWeight: 800, color: "#2563EB", fontFamily: FONT_TITLE, letterSpacing: "0.5px", marginTop: 4 }}>
                {fastest ? fmtDuration(fastest.durationSec) : "--"}
              </div>
              <div style={{ fontSize: 10.5, color: C.muted, marginTop: 2 }}>
                {fastest ? `Ticket #${fastest.ticketNumber}` : "Aucune donnée"}
              </div>
            </div>

            <div
              style={{
                background: "#F9FAFB",
                border: "1px solid #E5E7EB",
                borderRadius: 10,
                padding: "12px 14px",
              }}
            >
              <div style={{ fontSize: 10, fontWeight: 700, color: C.muted, textTransform: "uppercase", letterSpacing: "0.5px" }}>
                Commande la Plus Longue
              </div>
              <div style={{ fontSize: 22, fontWeight: 800, color: "#D97706", fontFamily: FONT_TITLE, letterSpacing: "0.5px", marginTop: 4 }}>
                {slowest ? fmtDuration(slowest.durationSec) : "--"}
              </div>
              <div style={{ fontSize: 10.5, color: C.muted, marginTop: 2 }}>
                {slowest ? `Ticket #${slowest.ticketNumber}` : "Aucune donnée"}
              </div>
            </div>
          </div>

          {/* Speed Distribution Bars */}
          <div style={{ borderTop: `1px solid ${C.border}`, paddingTop: 14 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: C.muted, textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: 10 }}>
              Répartition des temps de service en cuisine :
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: 12 }}>
              {dist.map((item, idx) => (
                <div key={idx} style={{ background: "#FDFDFD", border: `1px solid ${C.border}`, borderRadius: 8, padding: "10px 12px" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                      <span style={{ width: 8, height: 8, borderRadius: 2, background: item.color }} />
                      <span style={{ fontSize: 11.5, fontWeight: 700, color: C.ink }}>{item.label}</span>
                    </div>
                    <span style={{ fontSize: 11, fontWeight: 800, color: C.ink }}>
                      {item.count} cmd <span style={{ color: C.muted, fontWeight: 500 }}>({item.percent}%)</span>
                    </span>
                  </div>
                  <Bar pct={item.percent} color={item.color} />
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </Card>
  );
}

/* ── HourlyChart ───────────────────────────────────────────────────────────── */
function HourlyChart({ isMobile, data }) {
  const hourly = data || [];
  const bars = hourly.filter((h) => h.revenue > 0 || (h.hour >= 11 && h.hour <= 22));
  const display = bars.length > 0 ? bars : hourly.slice(11, 23);
  const maxV = Math.max(...display.map((h) => h.revenue), 1);
  const peak = display.reduce((best, h) => (h.revenue > best.revenue ? h : best), display[0] || { revenue: 0, hour: 0, orderCount: 0 });
  const peakLabel = peak && peak.revenue > 0 ? `${peak.hour}h-${peak.hour + 1}h (${fmtDA(peak.revenue)} · ${peak.orderCount} tickets)` : "";

  return (
    <Card>
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8, marginBottom: 12, flexWrap: "wrap" }}>
        <div>
          <SecTitle right={`${display.length} heures actives`}>Évolution des Ventes par Heure</SecTitle>
          <div style={{ fontSize: 11.5, color: C.muted, marginTop: -8 }}>Distribution du chiffre d'affaires et pics d'affluence</div>
        </div>
        {peakLabel && (
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              background: C.yellowBg,
              color: C.brown,
              padding: "4px 10px",
              borderRadius: 6,
              whiteSpace: "nowrap",
              flexShrink: 0,
            }}
          >
            🔥 Pic de service : {peakLabel}
          </span>
        )}
      </div>

      {display.length === 0 || maxV <= 1 ? (
        <div style={{ padding: "40px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>
          Aucune vente enregistrée pour cette plage horaire.
        </div>
      ) : (
        <>
          <div style={{ textAlign: "right", fontSize: 10, color: C.muted, marginBottom: 4 }}>
            Plafond : {Math.round(maxV).toLocaleString("fr-FR")} DA
          </div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: isMobile ? 3 : 6, height: 130 }}>
            {display.map((bar, i) => {
              const pct = bar.revenue / maxV;
              const isPeak = peak && bar.hour === peak.hour && bar.revenue > 0;
              const hasRev = bar.revenue > 0;
              return (
                <div
                  key={i}
                  title={`${bar.hour}h:00 - ${fmtDA(bar.revenue)} (${bar.orderCount} tickets)`}
                  style={{
                    flex: 1,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "flex-end",
                    height: "100%",
                    gap: 3,
                  }}
                >
                  {isPeak && (
                    <span
                      style={{
                        fontSize: 8.5,
                        fontWeight: 800,
                        background: C.yellow,
                        color: C.brown,
                        padding: "1px 4px",
                        borderRadius: 3,
                        whiteSpace: "nowrap",
                      }}
                    >
                      MAX
                    </span>
                  )}
                  <div
                    style={{
                      width: "100%",
                      borderRadius: "4px 4px 0 0",
                      height: `${Math.max(pct * 100, hasRev ? 5 : 2)}%`,
                      background: isPeak ? C.brown : hasRev ? C.yellow : "#E5E7EB",
                      transition: "height 0.3s ease",
                    }}
                  />
                </div>
              );
            })}
          </div>
          <div style={{ display: "flex", gap: isMobile ? 3 : 6, marginTop: 6, borderTop: `1px solid ${C.border}`, paddingTop: 4 }}>
            {display.map((bar, i) => (
              <div
                key={i}
                style={{
                  flex: 1,
                  textAlign: "center",
                  fontSize: 9,
                  color: bar.revenue > 0 ? C.ink : C.muted,
                  fontWeight: bar.revenue > 0 ? 700 : 400,
                }}
              >
                {bar.hour}h
              </div>
            ))}
          </div>
        </>
      )}
    </Card>
  );
}

/* ── TopArticles ───────────────────────────────────────────────────────────── */
function TopArticles({ data, totalCA }) {
  const navigate = useNavigate();
  const items = (data || []).slice(0, 6).map((a, i) => ({
    ...a,
    rank: i + 1,
    name: a.productName || a.name || "Article",
  }));
  const total = items.reduce((s, a) => s + (a.revenue || 0), 0);
  const pctOfCA = totalCA > 0 ? ((total / totalCA) * 100).toFixed(1) : "0.0";

  return (
    <Card>
      <SecTitle right={`Top ${items.length}`}>Articles les Plus Vendus</SecTitle>
      <div style={{ fontSize: 11.5, color: C.muted, marginTop: -8, marginBottom: 12 }}>
        Classement par quantité et chiffre d'affaires généré
      </div>

      {items.length === 0 ? (
        <div style={{ padding: "30px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>
          Aucune vente d'article sur cette période.
        </div>
      ) : (
        items.map((a, i) => (
          <div
            key={i}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              padding: "9px 0",
              borderBottom: i < items.length - 1 ? `1px solid ${C.border}` : "none",
            }}
          >
            <div
              style={{
                width: 26,
                height: 26,
                borderRadius: "50%",
                background: a.rank === 1 ? C.brown : a.rank === 2 ? "#6B7280" : a.rank === 3 ? "#B58B3A" : "#F3F4F6",
                color: a.rank <= 3 ? "#FFFFFF" : "#4B5563",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 11,
                fontWeight: 800,
                flexShrink: 0,
              }}
            >
              {a.rank}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div
                style={{
                  fontSize: 13,
                  fontWeight: 700,
                  color: C.ink,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                }}
              >
                {a.name}
              </div>
              <div style={{ fontSize: 11, color: C.muted }}>{a.qty} unités vendues</div>
            </div>
            <div style={{ textAlign: "right", flexShrink: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{fmtDA(a.revenue)}</div>
              {a.percent != null && <div style={{ fontSize: 10.5, color: C.muted }}>{a.percent}% du volume</div>}
            </div>
          </div>
        ))
      )}

      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          marginTop: 12,
          paddingTop: 12,
          borderTop: `1px solid ${C.border}`,
        }}
      >
        <span style={{ fontSize: 11.5, color: C.muted, fontWeight: 600 }}>Total Top : {pctOfCA}% du CA total</span>
        <span
          onClick={() => navigate("/menu")}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 4,
            fontSize: 11.5,
            fontWeight: 700,
            color: C.blue,
            cursor: "pointer",
          }}
        >
          Voir le menu complet <ChevronRight size={13} />
        </span>
      </div>
    </Card>
  );
}

/* ── Canaux ────────────────────────────────────────────────────────────────── */
function Canaux({ data }) {
  const items = (data || []).map((c, i) => ({
    label: CHANNEL_LABELS[c.channel] || c.channel || "Sur Place",
    tickets: c.orderCount || 0,
    pct: c.percent || 0,
    revenue: c.revenue || 0,
    color: CHANNEL_COLORS[i % CHANNEL_COLORS.length],
  }));

  return (
    <Card>
      <SecTitle right="Tickets">Canaux de Restauration</SecTitle>
      <div style={{ fontSize: 11.5, color: C.muted, marginTop: -8, marginBottom: 14 }}>
        Répartition des commandes par mode de consommation
      </div>

      {items.length === 0 ? (
        <div style={{ padding: "30px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>
          Aucune donnée de commande sur cette période.
        </div>
      ) : (
        items.map((canal, i) => (
          <div key={i} style={{ marginBottom: i < items.length - 1 ? 14 : 0 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                <span style={{ width: 9, height: 9, borderRadius: 2, background: canal.color, display: "inline-block", flexShrink: 0 }} />
                <span style={{ fontSize: 12.5, fontWeight: 600, color: C.ink }}>{canal.label}</span>
              </div>
              <div style={{ textAlign: "right" }}>
                <span style={{ fontSize: 12.5, fontWeight: 700, color: C.ink }}>
                  {canal.tickets} tickets{" "}
                  <span style={{ fontWeight: 400, color: C.muted }}>({canal.pct}%)</span>
                </span>
                <span style={{ fontSize: 11, color: C.muted, display: "block" }}>{fmtDA(canal.revenue)}</span>
              </div>
            </div>
            <Bar pct={canal.pct} color={canal.color} />
          </div>
        ))
      )}
    </Card>
  );
}

/* ── Paiements ─────────────────────────────────────────────────────────────── */
function Paiements({ data }) {
  const items = (data || []).map((p, i) => ({
    label: PAYMENT_LABELS_MAP[p.method] || p.method || "Espèces",
    amount: p.total || 0,
    count: p.count || 0,
    pct: p.percent || 0,
    color: PAYMENT_COLORS[i % PAYMENT_COLORS.length],
  }));

  return (
    <Card>
      <SecTitle right="Montant encaissé">Moyens de Paiement</SecTitle>
      <div style={{ fontSize: 11.5, color: C.muted, marginTop: -8, marginBottom: 14 }}>
        Répartition par mode de règlement en caisse
      </div>

      {items.length === 0 ? (
        <div style={{ padding: "30px 0", textAlign: "center", color: C.muted, fontSize: 13 }}>
          Aucun encaissement sur cette période.
        </div>
      ) : (
        items.map((p, i) => (
          <div key={i} style={{ marginBottom: i < items.length - 1 ? 14 : 0 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                <span style={{ width: 9, height: 9, borderRadius: 2, background: p.color, display: "inline-block", flexShrink: 0 }} />
                <span style={{ fontSize: 12.5, fontWeight: 600, color: C.ink }}>{p.label}</span>
              </div>
              <div style={{ textAlign: "right" }}>
                <span style={{ fontSize: 12.5, fontWeight: 700, color: C.ink }}>
                  {fmtDA(p.amount)}{" "}
                  <span style={{ fontWeight: 400, color: C.muted }}>({p.pct}%)</span>
                </span>
                <span style={{ fontSize: 11, color: C.muted, display: "block" }}>{p.count} transaction{p.count > 1 ? "s" : ""}</span>
              </div>
            </div>
            <Bar pct={p.pct} color={p.color} />
          </div>
        ))
      )}
    </Card>
  );
}

/* ── Page Principale ───────────────────────────────────────────────────────── */
export default function StatistiquesPage() {
  const navigate = useNavigate();
  const [period, setPeriod] = React.useState("Aujourd'hui");
  const [mobile, setMobile] = React.useState(window.innerWidth < 960);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState(null);
  const [summary, setSummary] = React.useState(null);

  React.useEffect(() => {
    const h = () => setMobile(window.innerWidth < 960);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);

  React.useEffect(() => {
    const range = getPeriodRange(period);
    setLoading(true);
    setError(null);
    statsService
      .getSummary({ from: range.from, to: range.to })
      .then((res) => {
        setSummary(res.data.data);
      })
      .catch((e) => {
        console.error("StatistiquesPage: failed to load summary", e);
        setError("Erreur de chargement des statistiques.");
      })
      .finally(() => setLoading(false));
  }, [period]);

  /* Derived data */
  const rz = summary?.rapportZ || {};
  const ca = rz.totalTTC || 0;
  const caHT = rz.totalHT || 0;
  const tickets = rz.ticketCount || 0;
  const panier = rz.avgBasket || 0;
  const kitchen = summary?.kitchen || {};

  const salesByHour = summary?.salesByHour || [];
  const topProducts = summary?.topProducts || [];
  const byChannel = summary?.byChannel || [];
  const paymentMethods = summary?.paymentMethods || [];

  // ── Rapport Z Modal state ──
  const [showRZ, setShowRZ] = React.useState(false);
  const [rzData, setRzData] = React.useState(null);
  const [rzLoading, setRzLoading] = React.useState(false);

  const openRapportZ = () => {
    setShowRZ(true);
    setRzLoading(true);
    const range = getPeriodRange(period);
    statsService
      .getRapportZ({ from: range.from, to: range.to })
      .then((res) => setRzData(res.data.data))
      .catch(() => setRzData(null))
      .finally(() => setRzLoading(false));
  };

  // ── PDF Export ──
  const exportPDF = () => {
    if (!summary) return;
    const fmt = (n) => (n || 0).toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const date = new Date().toLocaleString("fr-FR");

    const topRows = topProducts
      .map(
        (p) =>
          `<tr><td>${p.productName || p.name}</td><td>${p.qty}</td><td>${fmt(p.revenue)} DA</td><td>${ca ? ((p.revenue / ca) * 100).toFixed(1) : 0}%</td></tr>`
      )
      .join("");

    const channelRows = byChannel
      .map((c) => `<tr><td>${CHANNEL_LABELS[c.channel] || c.channel || "Sur place"}</td><td>${c.orderCount}</td><td>${fmt(c.revenue)} DA</td></tr>`)
      .join("");

    const payRows = paymentMethods
      .map((p) => `<tr><td>${PAYMENT_LABELS_MAP[p.method] || p.method || "Espèces"}</td><td>${p.count}</td><td>${fmt(p.total)} DA</td></tr>`)
      .join("");

    const kitchenRows = (kitchen.distribution || [])
      .map((d) => `<tr><td>${d.label}</td><td>${d.count} tickets</td><td>${d.percent}%</td></tr>`)
      .join("");

    const html = `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"/>
    <title>Rapport d'Activité Bobo's — ${period}</title>
    <style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 12px; color: #1C1917; padding: 32px; }
      .header { background: #2E2117; color: #F5F0E6; padding: 20px 24px; border-radius: 10px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }
      .header h1 { font-size: 24px; letter-spacing: 1px; font-weight: 800; }
      .header .sub { font-size: 10px; color: #F2B705; font-weight: 700; letter-spacing: 2px; margin-bottom: 4px; }
      .header .meta { font-size: 11px; color: rgba(245,240,230,0.7); margin-top: 6px; }
      .kpis { display: grid; grid-template-columns: repeat(5, 1fr); gap: 12px; margin-bottom: 24px; }
      .kpi { background: #F5F4F0; border-radius: 8px; padding: 14px 16px; border: 1px solid #E5E7EB; }
      .kpi .label { font-size: 9.5px; font-weight: 700; color: #8B8378; letter-spacing: 0.05em; text-transform: uppercase; margin-bottom: 6px; }
      .kpi .value { font-size: 17px; font-weight: 800; color: #1C1917; }
      .kpi .value.green { color: #059669; }
      .kpi .value.warn { color: #E0533D; }
      .section { margin-bottom: 22px; }
      .section-title { font-size: 11px; font-weight: 700; letter-spacing: 0.08em; color: #583926; text-transform: uppercase; margin-bottom: 10px; padding-bottom: 6px; border-bottom: 2px solid #F2B705; }
      table { width: 100%; border-collapse: collapse; margin-top: 6px; }
      th { text-align: left; font-size: 10px; font-weight: 700; color: #8B8378; text-transform: uppercase; letter-spacing: 0.05em; padding: 8px 10px; border-bottom: 1px solid #E7E4DD; }
      td { padding: 9px 10px; border-bottom: 1px solid #F0EDE8; font-size: 12px; }
      tr:last-child td { border-bottom: none; }
      .footer { margin-top: 32px; padding-top: 12px; border-top: 1px solid #E7E4DD; font-size: 10px; color: #8B8378; display: flex; justify-content: space-between; }
      @media print { body { padding: 20px; } }
    </style></head><body>
      <div class="header">
        <div>
          <div class="sub">RAPPORT DE GESTION &amp; STATISTIQUES</div>
          <h1>BOBO'S RESTAURATION</h1>
          <div class="meta">Période : ${period} &nbsp;·&nbsp; Exporté le ${date}</div>
        </div>
        <div style="text-align:right; color:#F2B705; font-weight:800; font-size:16px;">
          ${fmt(ca)} DA<br/><span style="font-size:11px;color:rgba(245,240,230,0.7);font-weight:400;">${tickets} tickets clôturés</span>
        </div>
      </div>

      <div class="kpis">
        <div class="kpi"><div class="label">Chiffre d'Affaires</div><div class="value">${fmt(ca)} DA</div></div>
        <div class="kpi"><div class="label">Tickets Clôturés</div><div class="value">${tickets}</div></div>
        <div class="kpi"><div class="label">Panier Moyen</div><div class="value">${fmt(panier)} DA</div></div>
        <div class="kpi"><div class="label">Temps Moyen Cuisine</div><div class="value green">${fmtDuration(kitchen.avgPrepTimeSeconds)}</div></div>
        <div class="kpi"><div class="label">Commandes Cuisine</div><div class="value">${kitchen.ordersPreparedCount || 0}</div></div>
      </div>

      <div class="section">
        <div class="section-title">Performance &amp; Délais Cuisine (KDS)</div>
        <p style="font-size:11.5px;color:#555;margin-bottom:8px;">
          Temps moyen de préparation : <b>${fmtDuration(kitchen.avgPrepTimeSeconds)}</b> sur <b>${kitchen.ordersPreparedCount || 0} commandes</b> traitées.
          ${kitchen.fastestOrder ? `<br/>Record express : Ticket #${kitchen.fastestOrder.ticketNumber} en ${fmtDuration(kitchen.fastestOrder.durationSec)}` : ""}
        </p>
        <table><thead><tr><th>Tranche de temps</th><th>Volume</th><th>Pourcentage</th></tr></thead>
        <tbody>${kitchenRows}</tbody></table>
      </div>

      ${topProducts.length ? `
      <div class="section">
        <div class="section-title">Top Produits Vendus</div>
        <table><thead><tr><th>Produit</th><th>Quantité</th><th>Chiffre d'Affaires</th><th>% du CA</th></tr></thead>
        <tbody>${topRows}</tbody></table>
      </div>` : ""}

      ${byChannel.length ? `
      <div class="section">
        <div class="section-title">Canaux de Vente</div>
        <table><thead><tr><th>Canal</th><th>Commandes</th><th>Chiffre d'Affaires</th></tr></thead>
        <tbody>${channelRows}</tbody></table>
      </div>` : ""}

      ${paymentMethods.length ? `
      <div class="section">
        <div class="section-title">Moyens de Paiement</div>
        <table><thead><tr><th>Mode de Règlement</th><th>Transactions</th><th>Montant Total</th></tr></thead>
        <tbody>${payRows}</tbody></table>
      </div>` : ""}

      <div class="footer">
        <span>Bobo's POS · Version 1.00 — Rapport d'exploitation officiel</span>
        <span>${date}</span>
      </div>
    </body></html>`;

    const w = window.open("", "_blank", "width=920,height=720");
    w.document.write(html);
    w.document.close();
    w.focus();
    setTimeout(() => w.print(), 500);
  };

  const spinner = (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", padding: "80px 0" }}>
      <div
        style={{
          width: 38,
          height: 38,
          border: `3px solid ${C.border}`,
          borderTopColor: C.yellow,
          borderRadius: "50%",
          animation: "spin .7s linear infinite",
        }}
      />
    </div>
  );

  return (
    <div style={{ minHeight: "100vh", background: C.bg, fontFamily: FONT_BODY, color: C.ink, display: "flex", flexDirection: "column" }}>
      {/* ── Top Header Bar ── */}
      <header
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "10px 20px",
          background: C.cardBg,
          borderBottom: `1px solid ${C.border}`,
          flexShrink: 0,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <button
            onClick={() => navigate("/")}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              padding: "8px 12px",
              borderRadius: 8,
              border: `1px solid ${C.borderDark}`,
              background: "#F9FAFB",
              color: "#374151",
              fontWeight: 700,
              fontSize: 12,
              cursor: "pointer",
              fontFamily: FONT_BODY,
            }}
          >
            <ArrowLeft size={14} /> Retour à l'accueil
          </button>

          <img
            src="/bobo_portrait.jpg"
            alt="Bobo's"
            style={{
              width: 38,
              height: 38,
              borderRadius: "50%",
              objectFit: "cover",
              border: `2px solid ${C.yellow}`,
            }}
          />

          <span
            style={{
              fontFamily: "'Pacifico', cursive",
              fontSize: 22,
              letterSpacing: "0.5px",
              color: "#111827",
              lineHeight: 1,
            }}
          >
            Bobo's
          </span>
        </div>

        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "6px 12px",
            borderRadius: 20,
            background: "#F9FAFB",
            border: `1px solid ${C.border}`,
            fontSize: 12,
            fontWeight: 600,
            color: "#1F2937",
          }}
        >
          <span style={{ width: 7, height: 7, borderRadius: "50%", background: "#10B981" }} />
          Poste Admin (Caisse 01)
        </div>
      </header>

      {/* ── Title Bar ── */}
      <div
        style={{
          width: "100%",
          padding: mobile ? "16px 16px" : "18px 28px 16px",
          background: C.cardBg,
          borderBottom: `1px solid ${C.border}`,
          display: "flex",
          alignItems: mobile ? "flex-start" : "center",
          justifyContent: "space-between",
          gap: 16,
          flexWrap: "wrap",
          boxSizing: "border-box",
        }}
      >
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 11, fontWeight: 700, letterSpacing: "0.6px", color: C.muted, marginBottom: 4 }}>
            <span>PORTAIL OPÉRATIONNEL &amp; DIRECTION</span>
            <span>•</span>
            <span style={{ color: C.green, fontWeight: 800 }}>SYNCHRONISÉ KDS &amp; CAISSE</span>
          </div>
          <h1
            style={{
              margin: "0 0 4px",
              fontFamily: FONT_TITLE,
              fontSize: mobile ? 28 : 34,
              fontWeight: 400,
              color: "#111827",
              letterSpacing: "0.5px",
              lineHeight: 1,
            }}
          >
            RAPPORTS &amp; STATISTIQUES
          </h1>
          <p style={{ margin: 0, fontSize: 12.5, color: C.muted }}>
            Performances financières, vitesse de préparation cuisine et clôtures de caisse en temps réel.
          </p>
        </div>

        {/* Right-aligned controls: Period pills + Action buttons */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
            flexWrap: "wrap",
            width: mobile ? "100%" : "auto",
          }}
        >
          {/* Period selector pills */}
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 4,
              background: "#F9FAFB",
              border: `1px solid ${C.border}`,
              padding: "3px 4px",
              borderRadius: 8,
              overflowX: "auto",
              maxWidth: "100%",
            }}
          >
            {PERIODS.map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                style={{
                  padding: "6px 12px",
                  borderRadius: 6,
                  border: "none",
                  background: period === p ? C.brown : "transparent",
                  color: period === p ? "#F5F0E6" : "#374151",
                  fontSize: 12,
                  fontWeight: period === p ? 700 : 500,
                  cursor: "pointer",
                  fontFamily: "inherit",
                  whiteSpace: "nowrap",
                  flexShrink: 0,
                  transition: "background .15s",
                }}
              >
                {p}
              </button>
            ))}
          </div>

          <button
            onClick={openRapportZ}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 7,
              padding: "8px 16px",
              height: 38,
              borderRadius: 8,
              border: "1px solid #EAB308",
              background: C.yellow,
              color: "#1F2937",
              fontSize: 12.5,
              fontWeight: 700,
              cursor: "pointer",
              fontFamily: "inherit",
              flexShrink: 0,
              boxSizing: "border-box",
            }}
          >
            <Printer size={15} /> Clôture Z
          </button>

          <button
            onClick={exportPDF}
            disabled={!summary || loading}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 7,
              padding: "8px 14px",
              height: 38,
              borderRadius: 8,
              border: `1px solid ${C.borderDark}`,
              background: "#FFFFFF",
              color: !summary || loading ? C.muted : "#374151",
              fontSize: 12,
              fontWeight: 600,
              cursor: !summary || loading ? "not-allowed" : "pointer",
              fontFamily: "inherit",
              flexShrink: 0,
              boxSizing: "border-box",
            }}
          >
            <Download size={14} /> Exporter (.PDF)
          </button>
        </div>
      </div>

      {/* ── Main Fluid Stretch Content ── */}
      <main
        style={{
          flex: 1,
          padding: mobile ? "16px 14px 32px" : "20px 28px 36px",
          width: "100%",
          boxSizing: "border-box",
        }}
      >
        {/* Error banner */}
        {error && (
          <div
            style={{
              background: C.redBg,
              color: C.red,
              padding: "12px 16px",
              borderRadius: 10,
              fontSize: 13,
              fontWeight: 600,
              marginBottom: 16,
              display: "flex",
              alignItems: "center",
              gap: 8,
            }}
          >
            <AlertTriangle size={16} /> {error}
          </div>
        )}

        {/* Loading / content */}
        {loading ? (
          spinner
        ) : (
          <>
            {/* Top 5 KPI Cards Row (Fluid Responsive Grid) */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: mobile ? "repeat(2, 1fr)" : "repeat(auto-fit, minmax(210px, 1fr))",
                gap: 14,
                marginBottom: 18,
              }}
            >
              <KpiCard
                label="Chiffre d'Affaires"
                value={fmtDA(ca)}
                sub={`Total HT : ${fmtDA(caHT)}`}
                icon={<TrendingUp size={15} color={C.green} />}
                bgIcon={C.greenBg}
                badge={`${tickets} tickets`}
                badgeColor={C.green}
              />
              <KpiCard
                label="Tickets Clôturés"
                value={tickets}
                sub={`Panier moyen : ${fmtDA(panier)}`}
                icon={<Printer size={15} color={C.brown} />}
                bgIcon="#F5F0E6"
              />
              <KpiCard
                label="Temps Moyen Cuisine"
                value={fmtDuration(kitchen.avgPrepTimeSeconds)}
                sub="Sortie de cuisine"
                icon={<Timer size={15} color={C.green} />}
                bgIcon={C.greenBg}
                badge="Vitesse KDS"
                badgeColor={C.green}
              />
              <KpiCard
                label="Commandes Préparées"
                value={kitchen.ordersPreparedCount || 0}
                sub="Finalisées en cuisine"
                icon={<UtensilsCrossed size={15} color={C.brown} />}
                bgIcon="#FEF08A"
              />
              <KpiCard
                label="Panier Moyen"
                value={fmtDA(panier)}
                sub="Par commande payée"
                icon={<Download size={15} color={C.blue} />}
                bgIcon={C.blueBg}
              />
            </div>

            {/* Annulations row if any */}
            {rz.annulees && rz.annulees.count > 0 && (
              <div style={{ marginBottom: 16 }}>
                <Card style={{ borderLeft: `4px solid ${C.red}` }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 12 }}>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase", marginBottom: 3 }}>
                        Commandes Annulées / Remboursées
                      </div>
                      <div style={{ fontSize: 16, fontWeight: 800, color: C.red }}>
                        {rz.annulees.count} ticket{rz.annulees.count > 1 ? "s" : ""} annulé{rz.annulees.count > 1 ? "s" : ""} ({fmtDA(rz.annulees.amount)})
                      </div>
                    </div>
                    <span style={{ fontSize: 11, fontWeight: 700, color: C.red, background: C.redBg, padding: "4px 10px", borderRadius: 6 }}>
                      Impact négatif sur le CA
                    </span>
                  </div>
                </Card>
              </div>
            )}

            {/* Full-width Kitchen Performance Section */}
            <div style={{ marginBottom: 18 }}>
              <KitchenPerformanceCard kitchen={kitchen} />
            </div>

            {/* Main Charts & Analytics Grid */}
            <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
              {/* Row 1: Hourly Sales Chart + Top Articles */}
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: mobile ? "1fr" : "1.6fr 1fr",
                  gap: 18,
                }}
              >
                <HourlyChart isMobile={mobile} data={salesByHour} />
                <TopArticles data={topProducts} totalCA={ca} />
              </div>

              {/* Row 2: Canaux de Vente + Moyens de Paiement */}
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: mobile ? "1fr" : "1fr 1fr",
                  gap: 18,
                }}
              >
                <Canaux data={byChannel} />
                <Paiements data={paymentMethods} />
              </div>
            </div>
          </>
        )}
      </main>

      {/* ── Footer ── */}
      <footer
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: mobile ? "12px 16px" : "14px 28px",
          borderTop: `1px solid ${C.border}`,
          background: C.cardBg,
          flexShrink: 0,
        }}
      >
        <span style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 12, fontWeight: 600, color: C.ink }}>
          <Circle size={7} fill={C.green} color={C.green} /> Connecté au serveur Bobo's
        </span>
        <span style={{ fontSize: 12, fontWeight: 600, color: C.muted }}>
          Bobo's POS · v1.00
        </span>
      </footer>

      {/* ── Rapport Z Modal ── */}
      {showRZ && (
        <div
          onClick={() => setShowRZ(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(28,25,23,0.6)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 999,
            padding: 16,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              background: "#fff",
              borderRadius: 16,
              width: "100%",
              maxWidth: 520,
              maxHeight: "90vh",
              overflowY: "auto",
              boxShadow: "0 20px 60px rgba(28,25,23,0.22)",
            }}
          >
            <div
              style={{
                background: "#2E2117",
                padding: "20px 24px",
                borderRadius: "16px 16px 0 0",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              <div>
                <div style={{ fontSize: 11, fontWeight: 700, color: "#F2B705", letterSpacing: "0.08em", marginBottom: 4 }}>
                  CLÔTURE OFFICIELLE DE CAISSE
                </div>
                <div style={{ fontSize: 20, fontWeight: 800, color: "#F5F0E6", fontFamily: FONT_TITLE, letterSpacing: "0.03em" }}>
                  RAPPORT Z — {period}
                </div>
              </div>
              <button
                onClick={() => setShowRZ(false)}
                style={{
                  background: "rgba(255,255,255,0.1)",
                  border: "none",
                  borderRadius: 8,
                  cursor: "pointer",
                  color: "#F5F0E6",
                  padding: "6px 10px",
                  fontSize: 16,
                }}
              >
                ✕
              </button>
            </div>

            <div style={{ padding: "20px 24px", fontFamily: "'Inter',sans-serif" }}>
              {rzLoading ? (
                <div style={{ textAlign: "center", padding: "40px 0", color: "#8B8378" }}>Chargement du rapport…</div>
              ) : !rzData ? (
                <div style={{ textAlign: "center", padding: "40px 0", color: "#E0533D", fontWeight: 600 }}>
                  Aucune donnée disponible pour cette période.
                </div>
              ) : (
                <>
                  {[
                    ["Chiffre d'affaires brut (TTC)", fmtDA(rzData.totalTTC), false],
                    ["Chiffre d'affaires net (HT)", fmtDA(rzData.totalHT), false],
                    ["Tickets clôturés", rzData.ticketCount || 0, false],
                    ["Panier moyen", fmtDA(rzData.avgBasket), false],
                    ["Temps moyen cuisine (KDS)", fmtDuration(rzData.kitchen?.avgPrepTimeSeconds), false],
                    ["Commandes préparées cuisine", rzData.kitchen?.ordersPreparedCount || 0, false],
                    ["Commandes annulées", rzData.annulees?.count || 0, (rzData.annulees?.count || 0) > 0],
                    ["Montant annulé", fmtDA(rzData.annulees?.amount), (rzData.annulees?.count || 0) > 0],
                  ].map(([label, value, warn]) => (
                    <div
                      key={label}
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        padding: "10px 0",
                        borderBottom: "1px solid #F0EDE8",
                      }}
                    >
                      <span style={{ fontSize: 13, color: "#8B8378" }}>{label}</span>
                      <span style={{ fontSize: 14, fontWeight: 700, color: warn ? "#E0533D" : "#1C1917" }}>{String(value)}</span>
                    </div>
                  ))}

                  {rzData.paymentBreakdown?.length > 0 && (
                    <>
                      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.06em", color: "#8B8378", marginTop: 16, marginBottom: 8 }}>
                        RÉCAPITULATIF DES ENCAISSEMENTS
                      </div>
                      {rzData.paymentBreakdown.map((p) => (
                        <div key={p.method} style={{ display: "flex", justifyContent: "space-between", padding: "8px 0", borderBottom: "1px solid #F0EDE8" }}>
                          <span style={{ fontSize: 13, color: "#1C1917", fontWeight: 600 }}>
                            {PAYMENT_LABELS_MAP[p.method] || p.method}
                          </span>
                          <span style={{ fontSize: 13, color: "#8B8378" }}>
                            {p.count} ticket{p.count > 1 ? "s" : ""} · <b style={{ color: "#1C1917" }}>{fmtDA(p.total)}</b>
                          </span>
                        </div>
                      ))}
                    </>
                  )}

                  <button
                    onClick={() => window.print()}
                    style={{
                      marginTop: 20,
                      width: "100%",
                      padding: "13px",
                      borderRadius: 10,
                      border: "none",
                      background: "#F2B705",
                      color: "#2E2117",
                      fontSize: 13,
                      fontWeight: 800,
                      letterSpacing: "0.05em",
                      textTransform: "uppercase",
                      cursor: "pointer",
                      fontFamily: "inherit",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: 8,
                    }}
                  >
                    <Printer size={15} /> Imprimer le Rapport Z
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
