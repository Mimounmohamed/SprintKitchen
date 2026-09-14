import React from "react";
import { useNavigate } from "react-router-dom";
import {
  Book, Clock, BarChart2, Users,
  ArrowRight, ChevronRight, Check, AlertTriangle, Circle,
} from "lucide-react";

const C = {
  bg: "#F5F4F0", cardBg: "#FFFFFF", ink: "#1C1917", brown: "#2E2117",
  yellow: "#F2B705", muted: "#8B8378", border: "#E7E4DD", green: "#2FAE5C",
  red: "#E0533D", redBg: "#FBEAE7", yellowBg: "#FCEFCB",
  blueBg: "#EDEBFB", blue: "#6C63D6",
  ctaDark: "#583926",
};

/* ── KPI card ──────────────────────────────────────────────────────────────── */
function Kpi({ label, value, valueColor, sub, subColor }) {
  return (
    <div style={{
      background: C.cardBg, border: `1px solid ${C.border}`,
      borderRadius: 12, padding: "16px 24px", minWidth: 150,
    }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: "0.06em", color: C.muted, textTransform: "uppercase", lineHeight: 1.4 }}>
        {label}
      </div>
      <div style={{ fontSize: 26, fontWeight: 800, marginTop: 8, color: valueColor || C.ink, lineHeight: 1 }}>
        {value}
      </div>
      <div style={{ fontSize: 12, marginTop: 4, color: subColor || C.muted, fontWeight: subColor ? 700 : 400 }}>
        {sub}
      </div>
    </div>
  );
}

/* ── Checklist item ────────────────────────────────────────────────────────── */
function ChecklistItem({ warn, children }) {
  return (
    <li style={{
      display: "flex", alignItems: "flex-start", gap: 8,
      fontSize: 13.5, color: warn ? "#B23A26" : C.ink, fontWeight: warn ? 600 : 400,
    }}>
      {warn
        ? <AlertTriangle size={14} color={C.red} style={{ marginTop: 2, flexShrink: 0 }} />
        : <Check size={14} color={C.green} strokeWidth={3} style={{ marginTop: 2, flexShrink: 0 }} />
      }
      {children}
    </li>
  );
}

/* ── Pill ──────────────────────────────────────────────────────────────────── */
function Pill({ dot, dotColor, bg, color, children, small }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      fontSize: small ? 11 : 12, fontWeight: 700,
      padding: small ? "4px 10px" : "6px 13px",
      borderRadius: 999, background: bg, color, whiteSpace: "nowrap",
      letterSpacing: "0.03em",
    }}>
      {dot && <Circle size={6} fill={dotColor} color={dotColor} style={{ flexShrink: 0 }} />}
      {children}
    </span>
  );
}

/* ── Module card ───────────────────────────────────────────────────────────── */
function ModuleCard({ icon, iconBg, iconColor, pill, eyebrow, title, description, checklist, highlight, cta, ctaIcon, ctaStyle, onClick }) {
  const ctaBg    = ctaStyle === "primary" ? C.yellow  : ctaStyle === "outline" ? C.cardBg : C.ctaDark;
  const ctaColor = ctaStyle === "primary" ? C.brown   : ctaStyle === "outline" ? C.ink    : "#F5F0E6";

  return (
    <div style={{
      background: C.cardBg, borderRadius: 16,
      border: `1px solid ${C.border}`,
      borderTop: highlight ? `3px solid ${C.yellow}` : `1px solid ${C.border}`,
      padding: "28px 26px 24px",
      display: "flex", flexDirection: "column", gap: 18,
      boxShadow: highlight ? "0 6px 28px rgba(242,183,5,0.12)" : "0 1px 4px rgba(28,25,23,0.04)",
    }}>
      {/* Icon + pill */}
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8 }}>
        <div style={{
          width: 52, height: 52, borderRadius: 13,
          background: iconBg, color: iconColor,
          display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
        }}>
          {icon}
        </div>
        {pill}
      </div>

      {/* Eyebrow + title + desc */}
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: "0.07em", color: C.muted, textTransform: "uppercase" }}>
          {eyebrow}
        </span>
        <h3 style={{ margin: 0, fontSize: 22, fontWeight: 800, lineHeight: 1.2, color: C.ink }}>
          {title}
        </h3>
        <p style={{ margin: "4px 0 0", fontSize: 13.5, color: C.muted, lineHeight: 1.6 }}>
          {description}
        </p>
      </div>

      {/* Checklist */}
      <ul style={{ listStyle: "none", margin: 0, padding: 0, display: "flex", flexDirection: "column", gap: 8 }}>
        {checklist}
      </ul>

      {/* CTA */}
      <button style={{
        marginTop: "auto",
        display: "flex", alignItems: "center", justifyContent: "space-between",
        border: ctaStyle === "outline" ? `1px solid ${C.border}` : "none",
        cursor: "pointer", borderRadius: 11,
        padding: ctaStyle === "primary" ? "10px 10px 10px 18px" : "14px 18px",
        fontSize: 12.5, fontWeight: 700,
        letterSpacing: "0.04em", textTransform: "uppercase", fontFamily: "inherit",
        background: ctaBg, color: ctaColor, transition: "opacity .15s",
      }}
        onMouseEnter={e => (e.currentTarget.style.opacity = ".85")}
        onMouseLeave={e => (e.currentTarget.style.opacity = "1")}
        onClick={onClick}
      >
        {cta}
        {ctaStyle === "primary" ? (
          <span style={{
            width: 36, height: 36, borderRadius: 9,
            background: "#583926",
            display: "flex", alignItems: "center", justifyContent: "center",
            color: "#F5F0E6", flexShrink: 0,
          }}>
            {ctaIcon}
          </span>
        ) : ctaIcon}
      </button>
    </div>
  );
}

/* ── Page ──────────────────────────────────────────────────────────────────── */
export default function SprintKitchenAdminHub() {
  const navigate = useNavigate();
  return (
    <div style={{
      minHeight: "100vh", background: C.bg,
      fontFamily: "'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",
      color: C.ink, display: "flex", flexDirection: "column",
    }}>

      {/* ── Header ── */}
      <header style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "18px 40px",
        borderBottom: `1px solid ${C.border}`,
        background: C.cardBg, flexShrink: 0,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 9, background: C.brown, color: C.yellow,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <Book size={20} />
          </div>
          <span style={{ fontSize: 17, fontWeight: 800, letterSpacing: "0.02em" }}>SPRINTKITCHEN</span>
          <span style={{ background: C.brown, color: "#F5F0E6", fontSize: 10, fontWeight: 700, padding: "3px 8px", borderRadius: 5 }}>
            HUB
          </span>
          <Circle size={7} fill={C.yellow} color={C.yellow} />
        </div>

        <Pill dot dotColor={C.green} bg="#F1F0EC" color={C.ink}>
          Super Admin — Back-Office
        </Pill>
      </header>

      {/* ── Main — FULL WIDTH, no maxWidth ── */}
      <main style={{ flex: 1, padding: "48px 40px 40px" }}>

        {/* Hero row: title left + KPIs right */}
        <div style={{
          display: "flex", alignItems: "flex-start",
          justifyContent: "space-between", gap: 40, flexWrap: "wrap",
          marginBottom: 32,
        }}>

          {/* Left */}
          <div style={{ flex: "1 1 400px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
              <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: "0.05em", color: C.muted }}>
                PORTAIL OPÉRATIONNEL & DIRECTION
              </span>
              <span style={{ color: C.muted }}>·</span>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontSize: 11, fontWeight: 700, color: C.green }}>
                <Circle size={6} fill={C.green} color={C.green} />
                SPRINTKITCHEN BACK-OFFICE
              </span>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 12, flexWrap: "wrap" }}>
              <h1 style={{ margin: 0, fontSize: 34, fontWeight: 800 }}>Portail Administrateur</h1>
              <span style={{ fontSize: 13, fontWeight: 600, color: C.muted, background: "#F1F0EC", padding: "5px 14px", borderRadius: 999 }}>
                Poste Superviseur #01
              </span>
            </div>

            <p style={{ margin: 0, color: C.muted, fontSize: 14.5, maxWidth: 520, lineHeight: 1.6 }}>
              Bienvenue sur le Hub de Gestion • Vue centralisée du restaurant, contrôle des menus et indicateurs financiers.
            </p>
          </div>

          {/* KPIs — separate cards in a row */}
          <div style={{ display: "flex", gap: 12, flexShrink: 0, flexWrap: "wrap" }}>
            <Kpi
              label="Chiffre d'affaires"
              value="1 450 €"
              valueColor={C.green}
              sub="+14% vs N-1"
              subColor={C.green}
            />
            <Kpi
              label="Tickets Clôturés"
              value="142"
              sub="Aujourd'hui"
            />
            <Kpi
              label="Articles en Rupture"
              value="3"
              valueColor="#D9720C"
              sub="Ingrédients (86 list)"
            />
          </div>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: C.border, marginBottom: 28 }} />

        {/* ── 4-column card grid — fills full width ── */}
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: 18,
        }}>

          <ModuleCard
            icon={<Book size={24} />}
            iconBg={C.brown} iconColor={C.yellow}
            pill={<Pill small dot dotColor="#C98A1A" bg={C.yellowBg} color="#946200">CATALOGUE & PRIX</Pill>}
            eyebrow="Gestion du menu"
            title="Éditer le Menu / Catalog"
            description="Ajoutez de nouveaux articles, modifiez les prix, configurez les formules et mettez à jour les visuels."
            checklist={<>
              <ChecklistItem>Modification des prix en temps réel</ChecklistItem>
              <ChecklistItem>Gestion des catégories et options</ChecklistItem>
            </>}
            highlight
            cta="MODIFIER LE MENU"
            ctaIcon={<ArrowRight size={16} />}
            ctaStyle="primary"
            onClick={() => navigate("/menu")}
          />

          <ModuleCard
            icon={<Clock size={24} />}
            iconBg="#F1F0EC" iconColor={C.ink}
            pill={<Pill small bg="#F1F0EC" color={C.muted}>ARCHIVES & TICKETS</Pill>}
            eyebrow="Commandes & Reçus"
            title="Historique des Commandes"
            description="View past tickets, search receipts, track daily sales totals, reprint kitchen vouchers, and handle refunds securely."
            checklist={<>
              <ChecklistItem>Recherche de tickets & réimpression</ChecklistItem>
              <ChecklistItem>Remboursements & exports</ChecklistItem>
            </>}
            cta="CONSULTER L'HISTORIQUE"
            ctaIcon={<ChevronRight size={16} />}
            ctaStyle="secondary"
          />

          <ModuleCard
            icon={<BarChart2 size={24} />}
            iconBg={C.blueBg} iconColor={C.blue}
            pill={<Pill small bg="#F1F0EC" color={C.muted}>CLÔTURE Z & FINANCES</Pill>}
            eyebrow="Rapports & Stats"
            title="Rapports & Statistiques"
            description="Analysez les ventes journalières, visualisez les produits les plus vendus et exportez vos données comptables."
            checklist={<>
              <ChecklistItem>Chiffre d'affaires et marges</ChecklistItem>
              <ChecklistItem>Export TVA et rapports Z</ChecklistItem>
            </>}
            cta="VOIR LES STATISTIQUES"
            ctaIcon={<ChevronRight size={16} />}
            ctaStyle="secondary"
          />

          <ModuleCard
            icon={<Users size={24} />}
            iconBg="#FBF3DF" iconColor="#C98A1A"
            pill={<Pill small dot dotColor={C.red} bg={C.redBg} color="#B23A26">3 ALERTES ACTIVES</Pill>}
            eyebrow="Équipe & Stocks"
            title="Équipe & Inventaire"
            description="Gérez les accès de votre personnel, suivez les heures et contrôlez la disponibilité des ingrédients."
            checklist={<>
              <ChecklistItem warn>3 Alertes de stock critique</ChecklistItem>
              <ChecklistItem>4 Employés actuellement actifs</ChecklistItem>
            </>}
            cta="GÉRER LE RESTAURANT"
            ctaIcon={<ChevronRight size={16} />}
            ctaStyle="outline"
          />
        </div>
      </main>

      {/* ── Footer ── */}
      <footer style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "16px 40px", borderTop: `1px solid ${C.border}`, flexShrink: 0,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 7, fontSize: 13, fontWeight: 600 }}>
          <Circle size={7} fill={C.green} color={C.green} />
          Connecté
          <span style={{ color: C.muted }}>·</span>
        </div>
        <span style={{ fontSize: 12, color: C.muted }}>SprintKitchen OS Admin v2.4.0-PROD</span>
      </footer>
    </div>
  );
}
