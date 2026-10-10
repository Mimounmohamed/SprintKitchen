import React, { useState, useEffect, useLayoutEffect, useRef, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft,
  Calendar,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Check,
  X,
  Circle,
  Download,
  Printer,
  TrendingUp,
  UtensilsCrossed,
  Clock,
  Timer,
  AlertTriangle,
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
const FONT_BODY = "'Open Sans', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

const MONTHS_SHORT = [
  "JANV.", "FÉVR.", "MARS", "AVR.", "MAI", "JUIN",
  "JUIL.", "AOÛT", "SEPT.", "OCT.", "NOV.", "DÉC.",
];

function two(n) {
  return String(n).padStart(2, "0");
}

function fmtLongDate(d) {
  if (!d) return "";
  const date = new Date(d);
  return `${date.getDate()} ${MONTHS_SHORT[date.getMonth()]} ${date.getFullYear()}`;
}

function isSameDay(a, b) {
  return (
    a &&
    b &&
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

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

/* ── Date Range Popover (Exact 1:1 replica of HistoriquePage / Caisse) ─────── */
const POPOVER_COLORS = {
  ink: "#1C1917",
  stone600: "#57534E",
  stone500: "#78716C",
  stone400: "#A8A29E",
  border: "#E7E5E4",
  brandDark: "#452B1E",
  gold: "#FACC15",
  rangeFill: "#FDE9A0",
};

const POPOVER_MONTHS = [
  "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
  "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre",
];

const POPOVER_MONTHS_SHORT = [
  "janv.", "févr.", "mars", "avr.", "mai", "juin",
  "juil.", "août", "sept.", "oct.", "nov.", "déc.",
];

const POPOVER_WEEKDAYS = ["L", "M", "M", "J", "V", "S", "D"];

const fmtShortVal = (d) => `${d.getDate()} ${POPOVER_MONTHS_SHORT[d.getMonth()]}`;
const fmtSlashVal = (d) => `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()}`;

function PopoverDayCell({
  day,
  col,
  start,
  end,
  today,
  daysInMonth,
  onDayTap,
}) {
  const cellH = 38;
  const brownSize = 32;
  const haloSize = 38;
  const radius = haloSize / 2;

  if (!day) return <div style={{ flex: 1, height: cellH }} />;

  const isAllHistory = start && start.getFullYear() <= 2020;
  const isStart = start && !isAllHistory && isSameDay(day, start);
  const isEnd = end && !isAllHistory && isSameDay(day, end);
  const isSingleDay = isStart && isEnd;
  const isEndpoint = isStart || isEnd;
  const inRange = !isAllHistory && start && end && day > start && day < end;
  const isToday = isSameDay(day, today);
  const disabled = day > today;

  const isFirstInMonth = day.getDate() === 1;
  const isLastInMonth = day.getDate() === daysInMonth;

  let strip = null;
  if (!isSingleDay && start && end && !isAllHistory) {
    if (inRange) {
      const roundLeft = col === 0 || isFirstInMonth;
      const roundRight = col === 6 || isLastInMonth;
      strip = (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: POPOVER_COLORS.rangeFill,
            borderTopLeftRadius: roundLeft ? radius : 0,
            borderBottomLeftRadius: roundLeft ? radius : 0,
            borderTopRightRadius: roundRight ? radius : 0,
            borderBottomRightRadius: roundRight ? radius : 0,
          }}
        />
      );
    } else if (isStart) {
      strip = (
        <div
          style={{
            position: "absolute",
            top: 0,
            bottom: 0,
            left: "50%",
            right: 0,
            background: col === 6 || isLastInMonth ? "transparent" : POPOVER_COLORS.rangeFill,
          }}
        />
      );
    } else if (isEnd) {
      strip = (
        <div
          style={{
            position: "absolute",
            top: 0,
            bottom: 0,
            left: 0,
            right: "50%",
            background: col === 0 || isFirstInMonth ? "transparent" : POPOVER_COLORS.rangeFill,
          }}
        />
      );
    }
  }

  const halo =
    !isSingleDay && isEndpoint ? (
      <div
        style={{
          position: "absolute",
          width: haloSize,
          height: haloSize,
          borderRadius: "50%",
          background: POPOVER_COLORS.rangeFill,
          top: "50%",
          left: "50%",
          transform: "translate(-50%, -50%)",
        }}
      />
    ) : null;

  let dayContentStyle = {
    width: brownSize,
    height: brownSize,
    borderRadius: "50%",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
    zIndex: 2,
    fontSize: 13.5,
    fontFamily: FONT_BODY,
  };

  if (isEndpoint) {
    dayContentStyle = {
      ...dayContentStyle,
      background: POPOVER_COLORS.brandDark,
      color: "#FFFFFF",
      fontWeight: 700,
    };
  } else if (isToday && !inRange) {
    dayContentStyle = {
      ...dayContentStyle,
      border: `1.4px solid ${POPOVER_COLORS.brandDark}`,
      color: POPOVER_COLORS.ink,
      fontWeight: 500,
      background: "transparent",
    };
  } else if (inRange) {
    dayContentStyle = {
      ...dayContentStyle,
      color: POPOVER_COLORS.brandDark,
      fontWeight: 700,
      background: "transparent",
    };
  } else {
    dayContentStyle = {
      ...dayContentStyle,
      color: disabled ? POPOVER_COLORS.stone400 : POPOVER_COLORS.ink,
      fontWeight: 500,
      background: "transparent",
    };
  }

  return (
    <div
      onClick={disabled ? undefined : () => onDayTap(day)}
      style={{
        flex: 1,
        height: cellH,
        position: "relative",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        cursor: disabled ? "default" : "pointer",
        userSelect: "none",
      }}
    >
      {strip}
      {halo}
      <div style={dayContentStyle}>{day.getDate()}</div>
    </div>
  );
}

function PopoverMonthGrid({ month, start, end, today, onDayTap }) {
  const year = month.getFullYear();
  const m = month.getMonth();
  const firstDay = new Date(year, m, 1);
  const daysInMonth = new Date(year, m + 1, 0).getDate();
  const leading = (firstDay.getDay() + 6) % 7;

  const cells = [];
  for (let i = 0; i < leading; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, m, d));
  while (cells.length % 7 !== 0) cells.push(null);

  const rows = [];
  for (let i = 0; i < cells.length; i += 7) {
    rows.push(cells.slice(i, i + 7));
  }

  return (
    <div style={{ flex: 1 }}>
      <div style={{ display: "flex", marginBottom: 8 }}>
        {POPOVER_WEEKDAYS.map((h, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              textAlign: "center",
              fontSize: 12,
              fontWeight: 700,
              color: POPOVER_COLORS.stone500,
              fontFamily: FONT_BODY,
            }}
          >
            {h}
          </div>
        ))}
      </div>

      {rows.map((row, rIdx) => (
        <div
          key={rIdx}
          style={{
            display: "flex",
            margin: "2px 0",
          }}
        >
          {row.map((day, cIdx) => (
            <PopoverDayCell
              key={cIdx}
              day={day}
              col={cIdx}
              start={start}
              end={end}
              today={today}
              daysInMonth={daysInMonth}
              onDayTap={onDayTap}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

function DateRangePopover({ anchorRef, initialRange, onClose, onApply }) {
  const today = useMemo(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }, []);

  const [start, setStart] = useState(() => initialRange?.start || today);
  const [end, setEnd] = useState(() => initialRange?.end || today);

  const [rightMonth, setRightMonth] = useState(() => {
    const anchor = initialRange?.end || today;
    return new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  });

  const [popoverPos, setPopoverPos] = useState({ top: 0, left: 0 });

  useLayoutEffect(() => {
    const updatePosition = () => {
      if (!anchorRef?.current) return;
      const rect = anchorRef.current.getBoundingClientRect();
      const popoverWidth = 860;
      let left = rect.left - 4;
      if (left + popoverWidth > window.innerWidth - 16) {
        left = Math.max(16, window.innerWidth - popoverWidth - 16);
      }
      if (left < 16) left = 16;
      let top = rect.bottom + 10;
      if (top + 480 > window.innerHeight && rect.top > 480) {
        top = Math.max(16, rect.top - 480 - 10);
      }
      setPopoverPos({ top, left });
    };

    updatePosition();
    window.addEventListener("resize", updatePosition);
    window.addEventListener("scroll", updatePosition, true);
    return () => {
      window.removeEventListener("resize", updatePosition);
      window.removeEventListener("scroll", updatePosition, true);
    };
  }, [anchorRef]);

  const leftMonth = useMemo(() => {
    return new Date(rightMonth.getFullYear(), rightMonth.getMonth() - 1, 1);
  }, [rightMonth]);

  const canGoNext = useMemo(() => {
    const next = new Date(rightMonth.getFullYear(), rightMonth.getMonth() + 1, 1);
    return next <= new Date(today.getFullYear(), today.getMonth(), 1);
  }, [rightMonth, today]);

  const goPrevMonth = () => {
    setRightMonth(new Date(rightMonth.getFullYear(), rightMonth.getMonth() - 1, 1));
  };

  const goNextMonth = () => {
    if (!canGoNext) return;
    setRightMonth(new Date(rightMonth.getFullYear(), rightMonth.getMonth() + 1, 1));
  };

  const shortcuts = useMemo(
    () => [
      {
        label: "Aujourd'hui",
        range: (t) => ({ start: t, end: t }),
        valueLabel: fmtShortVal(today),
      },
      {
        label: "Hier",
        range: (t) => {
          const y = new Date(t);
          y.setDate(y.getDate() - 1);
          return { start: y, end: y };
        },
        valueLabel: (() => {
          const y = new Date(today);
          y.setDate(y.getDate() - 1);
          return fmtShortVal(y);
        })(),
      },
      {
        label: "7 derniers jours",
        range: (t) => {
          const s = new Date(t);
          s.setDate(s.getDate() - 6);
          return { start: s, end: t };
        },
        valueLabel: null,
      },
      {
        label: "Ce mois-ci",
        range: (t) => ({
          start: new Date(t.getFullYear(), t.getMonth(), 1),
          end: t,
        }),
        valueLabel: POPOVER_MONTHS[today.getMonth()],
      },
      {
        label: "Mois dernier",
        range: (t) => {
          const lastMonthEnd = new Date(t.getFullYear(), t.getMonth(), 0);
          const lastMonthStart = new Date(lastMonthEnd.getFullYear(), lastMonthEnd.getMonth(), 1);
          return { start: lastMonthStart, end: lastMonthEnd };
        },
        valueLabel: (() => {
          const prev = new Date(today.getFullYear(), today.getMonth() - 1, 1);
          return POPOVER_MONTHS[prev.getMonth()];
        })(),
      },
      {
        label: "Tout l'historique",
        range: (t) => ({
          start: new Date(2020, 0, 1),
          end: t,
        }),
        valueLabel: "Toutes dates",
      },
    ],
    [today]
  );

  const matchesShortcut = (s) => {
    if (!start || !end) return false;
    if (s.label === "Tout l'historique") {
      return start.getFullYear() <= 2020 && isSameDay(end, today);
    }
    const r = s.range(today);
    return isSameDay(start, r.start) && isSameDay(end, r.end);
  };

  const applyShortcut = (s) => {
    const r = s.range(today);
    setStart(r.start);
    setEnd(r.end);
    setRightMonth(new Date(r.end.getFullYear(), r.end.getMonth(), 1));
  };

  const handleDayTap = (day) => {
    if (!start || (start && end)) {
      setStart(day);
      setEnd(null);
    } else if (day < start) {
      setEnd(start);
      setStart(day);
    } else {
      setEnd(day);
    }
  };

  const isCustomActive = shortcuts.every((s) => !matchesShortcut(s));
  const hasRange = start != null && end != null;
  const isAllHistory = start && start.getFullYear() <= 2020;
  const days = hasRange ? Math.round(Math.abs(end - start) / 86400000) + 1 : 0;

  return (
    <>
      <div
        onClick={onClose}
        style={{
          position: "fixed",
          inset: 0,
          zIndex: 499,
          background: "transparent",
        }}
      />

      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          position: "fixed",
          top: `${popoverPos.top}px`,
          left: `${popoverPos.left}px`,
          zIndex: 500,
          width: "min(860px, calc(100vw - 32px))",
          maxHeight: "calc(100vh - 32px)",
          overflowY: "auto",
          background: "#FFFFFF",
          borderRadius: 16,
          border: `1px solid ${POPOVER_COLORS.border}`,
          boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
          fontFamily: FONT_BODY,
        }}
      >
        {/* Header */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            padding: "20px 18px 20px 26px",
          }}
        >
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 8,
              background: POPOVER_COLORS.brandDark,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <Calendar size={17} color={POPOVER_COLORS.gold} />
          </div>

          <div style={{ marginLeft: 14, flex: 1 }}>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: 14,
                fontWeight: 800,
                letterSpacing: "0.3px",
                color: POPOVER_COLORS.ink,
              }}
            >
              SÉLECTIONNER UNE PÉRIODE D'ANALYSE
            </div>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: 12.5,
                color: POPOVER_COLORS.stone500,
                marginTop: 3,
              }}
            >
              Filtrer les rapports financiers, statistiques et performances cuisine
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            style={{
              padding: 6,
              borderRadius: 8,
              background: "none",
              border: "none",
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: POPOVER_COLORS.stone500,
            }}
          >
            <X size={20} />
          </button>
        </div>

        <div style={{ height: 1, background: POPOVER_COLORS.border }} />

        {/* Body */}
        <div
          style={{
            padding: "22px 26px",
            display: "flex",
            alignItems: "flex-start",
          }}
        >
          {/* Shortcuts column */}
          <div style={{ width: 220, flexShrink: 0 }}>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: 11,
                fontWeight: 700,
                letterSpacing: "0.6px",
                color: POPOVER_COLORS.stone500,
                textTransform: "uppercase",
                marginBottom: 12,
              }}
            >
              RACCOURCIS RAPIDES
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
              {shortcuts.map((s, idx) => {
                const active = matchesShortcut(s);
                return (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => applyShortcut(s)}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      padding: "10px 14px",
                      borderRadius: 10,
                      background: active ? POPOVER_COLORS.brandDark : "transparent",
                      border: "none",
                      cursor: "pointer",
                      width: "100%",
                      textAlign: "left",
                      fontFamily: FONT_BODY,
                    }}
                  >
                    {active && (
                      <div
                        style={{
                          width: 6,
                          height: 6,
                          borderRadius: "50%",
                          background: POPOVER_COLORS.gold,
                          marginRight: 8,
                          flexShrink: 0,
                        }}
                      />
                    )}
                    <span
                      style={{
                        flex: 1,
                        fontSize: 13,
                        fontWeight: active ? 700 : 600,
                        color: active ? "#FFFFFF" : POPOVER_COLORS.ink,
                      }}
                    >
                      {s.label}
                    </span>
                    {active ? (
                      <span
                        style={{
                          padding: "3px 8px",
                          background: POPOVER_COLORS.gold,
                          borderRadius: 6,
                          fontSize: 10.5,
                          fontWeight: 800,
                          color: POPOVER_COLORS.ink,
                          lineHeight: 1.2,
                        }}
                      >
                        Actif
                      </span>
                    ) : s.valueLabel ? (
                      <span
                        style={{
                          fontSize: 12,
                          color: POPOVER_COLORS.stone500,
                          fontWeight: 400,
                        }}
                      >
                        {s.valueLabel}
                      </span>
                    ) : null}
                  </button>
                );
              })}

              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  padding: "10px 14px",
                  borderRadius: 10,
                  background: isCustomActive ? POPOVER_COLORS.brandDark : "transparent",
                  fontFamily: FONT_BODY,
                }}
              >
                {isCustomActive && (
                  <div
                    style={{
                      width: 6,
                      height: 6,
                      borderRadius: "50%",
                      background: POPOVER_COLORS.gold,
                      marginRight: 8,
                      flexShrink: 0,
                    }}
                  />
                )}
                <span
                  style={{
                    flex: 1,
                    fontSize: 13,
                    fontWeight: isCustomActive ? 700 : 600,
                    color: isCustomActive ? "#FFFFFF" : POPOVER_COLORS.ink,
                  }}
                >
                  Personnalisé
                </span>
                <ChevronRight
                  size={18}
                  color={isCustomActive ? "#FFFFFF" : POPOVER_COLORS.stone400}
                />
              </div>
            </div>
          </div>

          <div style={{ width: 32, flexShrink: 0 }} />

          {/* Calendars column */}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                marginBottom: 14,
              }}
            >
              <button
                type="button"
                onClick={goPrevMonth}
                style={{
                  padding: 4,
                  borderRadius: 6,
                  background: "none",
                  border: "none",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: POPOVER_COLORS.stone600,
                }}
              >
                <ChevronLeft size={20} />
              </button>
              <div
                style={{
                  flex: 1,
                  textAlign: "center",
                  fontFamily: FONT_BODY,
                  fontSize: 13.5,
                  fontWeight: 800,
                  letterSpacing: "0.4px",
                  color: POPOVER_COLORS.ink,
                  textTransform: "uppercase",
                }}
              >
                {POPOVER_MONTHS[leftMonth.getMonth()]} {leftMonth.getFullYear()}
              </div>
              <div
                style={{
                  flex: 1,
                  textAlign: "center",
                  fontFamily: FONT_BODY,
                  fontSize: 13.5,
                  fontWeight: 800,
                  letterSpacing: "0.4px",
                  color: POPOVER_COLORS.ink,
                  textTransform: "uppercase",
                }}
              >
                {POPOVER_MONTHS[rightMonth.getMonth()]} {rightMonth.getFullYear()}
              </div>
              <button
                type="button"
                onClick={canGoNext ? goNextMonth : undefined}
                disabled={!canGoNext}
                style={{
                  padding: 4,
                  borderRadius: 6,
                  background: "none",
                  border: "none",
                  cursor: canGoNext ? "pointer" : "default",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: canGoNext ? POPOVER_COLORS.stone600 : POPOVER_COLORS.border,
                }}
              >
                <ChevronRight size={20} />
              </button>
            </div>

            <div style={{ display: "flex", gap: 28, alignItems: "flex-start" }}>
              <PopoverMonthGrid
                month={leftMonth}
                start={start}
                end={end}
                today={today}
                onDayTap={handleDayTap}
              />
              <PopoverMonthGrid
                month={rightMonth}
                start={start}
                end={end}
                today={today}
                onDayTap={handleDayTap}
              />
            </div>
          </div>
        </div>

        <div style={{ height: 1, background: POPOVER_COLORS.border }} />

        {/* Footer */}
        <div
          style={{
            padding: "16px 26px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            flexWrap: "wrap",
            gap: 12,
          }}
        >
          <div style={{ display: "flex", alignItems: "center" }}>
            <span
              style={{
                fontSize: 13,
                fontWeight: 500,
                color: POPOVER_COLORS.stone600,
                fontFamily: FONT_BODY,
              }}
            >
              Période sélectionnée :{" "}
            </span>
            <div
              style={{
                marginLeft: 6,
                padding: "8px 14px",
                background: "#F3F4F6",
                borderRadius: 8,
                border: `1px solid ${POPOVER_COLORS.border}`,
                display: "inline-flex",
                alignItems: "center",
              }}
            >
              <span
                style={{
                  fontSize: 13,
                  fontWeight: 700,
                  color: POPOVER_COLORS.ink,
                  fontFamily: FONT_BODY,
                }}
              >
                {hasRange
                  ? isAllHistory
                    ? "Tout l'historique"
                    : `${fmtSlashVal(start)} — ${fmtSlashVal(end)}`
                  : "Choisissez une période"}
              </span>
              {hasRange && (
                <span
                  style={{
                    fontSize: 12.5,
                    fontWeight: 500,
                    color: POPOVER_COLORS.stone500,
                    marginLeft: 8,
                    fontFamily: FONT_BODY,
                  }}
                >
                  {isAllHistory ? "(Toutes dates)" : `(${days} jour${days > 1 ? "s" : ""})`}
                </span>
              )}
            </div>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: "10px 16px",
                background: "transparent",
                border: "none",
                borderRadius: 8,
                color: POPOVER_COLORS.stone600,
                fontSize: 13.5,
                fontWeight: 600,
                cursor: "pointer",
                fontFamily: FONT_BODY,
              }}
            >
              Annuler
            </button>

            <button
              type="button"
              disabled={!hasRange}
              onClick={() => {
                if (hasRange) {
                  onApply(start, end);
                  onClose();
                }
              }}
              style={{
                padding: "12px 18px",
                background: POPOVER_COLORS.gold,
                color: POPOVER_COLORS.ink,
                border: "none",
                borderRadius: 10,
                fontSize: 13.5,
                fontWeight: 800,
                cursor: hasRange ? "pointer" : "not-allowed",
                opacity: hasRange ? 1 : 0.5,
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                fontFamily: FONT_BODY,
              }}
            >
              <Check size={16} color={POPOVER_COLORS.ink} />
              <span>Appliquer la période</span>
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

/* ── Page Principale ───────────────────────────────────────────────────────── */
export default function StatistiquesPage() {
  const navigate = useNavigate();
  const [mobile, setMobile] = useState(window.innerWidth < 960);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [summary, setSummary] = useState(null);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const calendarTriggerRef = useRef(null);

  // Date Range (default: Today)
  const [range, setRange] = useState(() => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    return { start: today, end: today };
  });

  useEffect(() => {
    const h = () => setMobile(window.innerWidth < 960);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);

  useEffect(() => {
    const fromIso = range.start.getFullYear() <= 2020 ? new Date(2020, 0, 1).toISOString() : range.start.toISOString();
    const toIso = new Date(range.end.getFullYear(), range.end.getMonth(), range.end.getDate(), 23, 59, 59, 999).toISOString();
    setLoading(true);
    setError(null);
    statsService
      .getSummary({ from: fromIso, to: toIso })
      .then((res) => {
        setSummary(res.data.data);
      })
      .catch((e) => {
        console.error("StatistiquesPage: failed to load summary", e);
        setError("Erreur de chargement des statistiques.");
      })
      .finally(() => setLoading(false));
  }, [range]);

  const headerDateTitle = useMemo(() => {
    if (range.start.getFullYear() <= 2020) {
      return "STATISTIQUES DE TOUT L'HISTORIQUE";
    }
    return `STATISTIQUES DU ${fmtLongDate(range.start)} AU ${fmtLongDate(range.end)}`;
  }, [range]);

  const periodLabel = useMemo(() => {
    if (range.start.getFullYear() <= 2020) {
      return "Tout l'historique";
    }
    return `Du ${fmtLongDate(range.start)} au ${fmtLongDate(range.end)}`;
  }, [range]);

  /* Derived data */
  const rz = summary?.rapportZ || {};
  const ca = rz.totalTTC || 0;
  const caHT = rz.totalHT || 0;
  const tickets = rz.ticketCount || 0;
  const kitchen = summary?.kitchen || {};

  const salesByHour = summary?.salesByHour || [];
  const topProducts = summary?.topProducts || [];
  const byChannel = summary?.byChannel || [];
  const paymentMethods = summary?.paymentMethods || [];

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
    <title>Rapport d'Activité Bobo's — ${periodLabel}</title>
    <style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body { font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 12px; color: #1C1917; padding: 32px; }
      .header { background: #2E2117; color: #F5F0E6; padding: 20px 24px; border-radius: 10px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }
      .header h1 { font-size: 24px; letter-spacing: 1px; font-weight: 800; }
      .header .sub { font-size: 10px; color: #F2B705; font-weight: 700; letter-spacing: 2px; margin-bottom: 4px; }
      .header .meta { font-size: 11px; color: rgba(245,240,230,0.7); margin-top: 6px; }
      .kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 24px; }
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
          <div class="meta">Période : ${periodLabel} &nbsp;·&nbsp; Exporté le ${date}</div>
        </div>
        <div style="text-align:right; color:#F2B705; font-weight:800; font-size:16px;">
          ${fmt(ca)} DA<br/><span style="font-size:11px;color:rgba(245,240,230,0.7);font-weight:400;">${tickets} tickets clôturés</span>
        </div>
      </div>

      <div class="kpis">
        <div class="kpi"><div class="label">Chiffre d'Affaires</div><div class="value">${fmt(ca)} DA</div></div>
        <div class="kpi"><div class="label">Tickets Clôturés</div><div class="value">${tickets}</div></div>
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

      {/* ── Title Bar (With Order Historic Date Range Filter) ── */}
      <div
        style={{
          width: "100%",
          padding: mobile ? "16px 16px" : "24px 32px 20px",
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
          <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 11, fontWeight: 600, letterSpacing: "0.6px", color: "#6B7280" }}>
            <span>RAPPORTS &amp; STATISTIQUES</span>
            <span>•</span>
            <span style={{ color: C.green, fontWeight: 700 }}>SYNCHRONISÉ KDS &amp; COMPTOIR</span>
          </div>

          <div
            ref={calendarTriggerRef}
            onClick={() => setShowDatePicker((prev) => !prev)}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 12,
              marginTop: 6,
              cursor: "pointer",
            }}
          >
            <div
              style={{
                width: 34,
                height: 34,
                borderRadius: 8,
                background: "#F9FAFB",
                border: `1px solid ${C.border}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: "#374151",
                flexShrink: 0,
              }}
            >
              <Calendar size={16} />
            </div>

            <h1
              style={{
                margin: 0,
                fontFamily: FONT_TITLE,
                fontSize: mobile ? 24 : 30,
                fontWeight: 400,
                letterSpacing: "0.5px",
                color: "#111827",
                lineHeight: 1.1,
              }}
            >
              {headerDateTitle}
            </h1>

            <ChevronDown size={22} color="#6B7280" />
          </div>
        </div>

        {/* Right-aligned Action button */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 10,
            flexWrap: "wrap",
          }}
        >
          <button
            onClick={exportPDF}
            disabled={!summary || loading}
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 7,
              padding: "10px 16px",
              height: 42,
              borderRadius: 10,
              border: `1px solid ${C.borderDark}`,
              background: "#FFFFFF",
              color: !summary || loading ? C.muted : "#374151",
              fontSize: 13,
              fontWeight: 700,
              cursor: !summary || loading ? "not-allowed" : "pointer",
              fontFamily: FONT_BODY,
              flexShrink: 0,
              boxSizing: "border-box",
            }}
          >
            <Download size={16} /> Exporter (.PDF)
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
            {/* Top 4 KPI Cards Row (Fluid Responsive Grid) */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: mobile ? "repeat(2, 1fr)" : "repeat(4, 1fr)",
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
                sub="Commandes encaissées"
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

      {/* ── Date Range Popover ── */}
      {showDatePicker && (
        <DateRangePopover
          anchorRef={calendarTriggerRef}
          initialRange={range}
          onClose={() => setShowDatePicker(false)}
          onApply={(start, end) => setRange({ start, end })}
        />
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
