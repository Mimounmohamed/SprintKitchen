import React from "react";
import { useNavigate } from "react-router-dom";
import {
  Book, Clock, BarChart2, Package,
  ArrowRight, ChevronRight, Check, AlertTriangle, Circle, User, TrendingUp, Menu as MenuIcon,
} from "lucide-react";
import { dashboardService } from "../services";

const C = {
  bg:"#F5F4F0", cardBg:"#FFFFFF", ink:"#1C1917", brown:"#2E2117",
  yellow:"#F2B705", muted:"#8B8378", border:"#E7E4DD", green:"#2FAE5C",
  red:"#E0533D", redBg:"#FBEAE7", yellowBg:"#FCEFCB",
  blueBg:"#EDEBFB", blue:"#6C63D6", ctaDark:"#583926",
};

function ChecklistItem({ warn, children }) {
  return (
    <li style={{ display:"flex", alignItems:"flex-start", gap:8, fontSize:13, color:warn?"#B23A26":C.ink, fontWeight:warn?600:400 }}>
      {warn
        ? <AlertTriangle size={13} color={C.red} style={{ marginTop:2, flexShrink:0 }}/>
        : <Check size={13} color={C.green} strokeWidth={3} style={{ marginTop:2, flexShrink:0 }}/>}
      {children}
    </li>
  );
}

function Pill({ dot, dotColor, bg, color, children, small }) {
  return (
    <span style={{ display:"inline-flex", alignItems:"center", gap:6, fontSize:small?10:12, fontWeight:700, padding:small?"3px 9px":"6px 13px", borderRadius:999, background:bg, color, whiteSpace:"nowrap", letterSpacing:"0.03em" }}>
      {dot && <Circle size={6} fill={dotColor} color={dotColor} style={{ flexShrink:0 }}/>}
      {children}
    </span>
  );
}

function ModuleCard({ icon, iconBg, iconColor, pill, eyebrow, title, description, checklist, highlight, cta, ctaIcon, ctaStyle, onClick, mobile }) {
  const ctaBg    = ctaStyle==="primary" ? C.yellow : ctaStyle==="outline" ? C.cardBg : C.ctaDark;
  const ctaColor = ctaStyle==="primary" ? C.brown  : ctaStyle==="outline" ? C.ink   : "#F5F0E6";
  return (
    <div style={{
      background:C.cardBg, borderRadius:16,
      border:`1px solid ${C.border}`,
      borderTop:highlight?`3px solid ${C.yellow}`:`1px solid ${C.border}`,
      padding:mobile?"20px 18px 18px":"28px 26px 24px",
      display:"flex", flexDirection:"column", gap:mobile?14:18,
      boxShadow:highlight?"0 6px 28px rgba(242,183,5,0.12)":"0 1px 4px rgba(28,25,23,0.04)",
    }}>
      <div style={{ display:"flex", alignItems:"flex-start", justifyContent:"space-between", gap:8 }}>
        <div style={{ width:mobile?42:52, height:mobile?42:52, borderRadius:13, background:iconBg, color:iconColor, display:"flex", alignItems:"center", justifyContent:"center", flexShrink:0 }}>
          {icon}
        </div>
        {pill}
      </div>
      <div style={{ display:"flex", flexDirection:"column", gap:4 }}>
        <span style={{ fontSize:10.5, fontWeight:700, letterSpacing:"0.07em", color:C.muted, textTransform:"uppercase" }}>{eyebrow}</span>
        <h3 style={{ margin:0, fontSize:mobile?20:22, fontWeight:800, lineHeight:1.2, color:C.ink }}>{title}</h3>
        <p style={{ margin:"3px 0 0", fontSize:mobile?13:13.5, color:C.muted, lineHeight:1.6 }}>{description}</p>
      </div>
      <ul style={{ listStyle:"none", margin:0, padding:0, display:"flex", flexDirection:"column", gap:mobile?6:8 }}>
        {checklist}
      </ul>
      <button style={{
        marginTop:"auto", width:"100%",
        display:"flex", alignItems:"center", justifyContent:"space-between",
        border:ctaStyle==="outline"?`1px solid ${C.border}`:"none",
        cursor:"pointer", borderRadius:11,
        padding:ctaStyle==="primary"?"12px 12px 12px 18px":"14px 18px",
        fontSize:mobile?12:12.5, fontWeight:700,
        letterSpacing:"0.05em", textTransform:"uppercase", fontFamily:"inherit",
        background:ctaBg, color:ctaColor, transition:"opacity .15s",
        boxSizing:"border-box",
      }}
        onMouseEnter={e=>(e.currentTarget.style.opacity=".85")}
        onMouseLeave={e=>(e.currentTarget.style.opacity="1")}
        onClick={onClick}>
        {cta}
        {ctaStyle==="primary" ? (
          <span style={{ width:34, height:34, borderRadius:9, background:"#583926", display:"flex", alignItems:"center", justifyContent:"center", color:"#F5F0E6", flexShrink:0 }}>
            {ctaIcon}
          </span>
        ) : ctaIcon}
      </button>
    </div>
  );
}

/* ── Kpi (desktop only) ── */
function Kpi({ label, value, valueColor, sub, subColor }) {
  return (
    <div style={{ background:C.cardBg, border:`1px solid ${C.border}`, borderRadius:12, padding:"16px 24px", minWidth:150 }}>
      <div style={{ fontSize:10, fontWeight:700, letterSpacing:"0.06em", color:C.muted, textTransform:"uppercase", lineHeight:1.4 }}>{label}</div>
      <div style={{ fontSize:26, fontWeight:800, marginTop:8, color:valueColor||C.ink, lineHeight:1 }}>{value}</div>
      <div style={{ fontSize:12, marginTop:4, color:subColor||C.muted, fontWeight:subColor?700:400 }}>{sub}</div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════
   PAGE
══════════════════════════════════════════════════════ */
export default function SprintKitchenAdminHub() {
  const navigate = useNavigate();
  const [mobile, setMobile] = React.useState(window.innerWidth < 900);
  React.useEffect(() => {
    const h = () => setMobile(window.innerWidth < 900);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);

  // ── Live KPIs ──────────────────────────────────────────────────────────────
  const [kpi, setKpi] = React.useState(null);
  React.useEffect(() => {
    dashboardService.getKpis()
      .then(res => setKpi(res.data.data))
      .catch(() => {}); // silently fail — shows dashes
  }, []);

  // Formatted values (show — while loading)
  const caFmt = kpi
    ? kpi.revenue.today.toLocaleString("fr-FR", { maximumFractionDigits: 0 }) + " DA"
    : "—";
  const vsPct = kpi?.revenue.vsLastYear != null
    ? (kpi.revenue.vsLastYear >= 0 ? "+" : "") + kpi.revenue.vsLastYear + "% vs N-1"
    : "vs N-1";
  const vsPctPositive = (kpi?.revenue.vsLastYear ?? 0) >= 0;
  const ticketsFmt  = kpi ? String(kpi.tickets.today)   : "—";
  const ruptureFmt  = kpi ? String(kpi.rupture.count)   : "—";
  const ruptureWarn = (kpi?.rupture.count ?? 0) > 0;

  const shell = {
    minHeight:"100vh", background:C.bg,
    fontFamily:"'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",
    color:C.ink, display:"flex", flexDirection:"column",
  };

  /* ── MOBILE ── */
  if (mobile) return (
    <div style={shell}>
      {/* Mobile header */}
      <header style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"13px 16px", borderBottom:`1px solid ${C.border}`, background:C.cardBg, flexShrink:0 }}>
        <button style={{ background:"none", border:"none", cursor:"pointer", padding:4, color:C.ink, display:"flex" }}>
          <MenuIcon size={22}/>
        </button>
        <div style={{ display:"flex", alignItems:"center", gap:7 }}>
          <div style={{ width:30, height:30, borderRadius:7, background:C.brown, color:C.yellow, display:"flex", alignItems:"center", justifyContent:"center" }}>
            <Book size={15}/>
          </div>
          <span style={{ fontSize:14, fontWeight:800, letterSpacing:"0.02em" }}>SPRINTKITCHEN</span>
          <span style={{ background:C.brown, color:"#F5F0E6", fontSize:9, fontWeight:700, padding:"2px 6px", borderRadius:4 }}>HUB</span>
          <Circle size={6} fill={C.yellow} color={C.yellow}/>
        </div>
        <div style={{ width:34, height:34, borderRadius:"50%", background:"#E8E4DF", display:"flex", alignItems:"center", justifyContent:"center", position:"relative" }}>
          <User size={15} color={C.muted}/>
          <span style={{ position:"absolute", top:1, right:1, width:8, height:8, borderRadius:"50%", background:C.green, border:"2px solid #fff" }}/>
        </div>
      </header>

      <main style={{ flex:1, padding:"18px 14px 32px", display:"flex", flexDirection:"column", gap:16 }}>

        {/* Breadcrumb + title */}
        <div>
          <div style={{ display:"flex", alignItems:"center", gap:6, marginBottom:8 }}>
            <span style={{ fontSize:9.5, fontWeight:700, letterSpacing:"0.05em", color:C.muted, textTransform:"uppercase" }}>PORTAIL BACK-OFFICE</span>
            <span style={{ color:C.muted }}>·</span>
            <span style={{ display:"inline-flex", alignItems:"center", gap:4, fontSize:9.5, fontWeight:700, color:C.green }}>
              <Circle size={5} fill={C.green} color={C.green}/> EN DIRECT
            </span>
          </div>
          <div style={{ display:"flex", alignItems:"flex-start", justifyContent:"space-between", gap:8 }}>
            <div>
              <h1 style={{ margin:"0 0 5px", fontSize:26, fontWeight:800, lineHeight:1.05, color:C.ink, fontFamily:"'Bebas Neue',sans-serif", letterSpacing:"0.02em" }}>PORTAIL ADMINISTRATEUR</h1>
              <p style={{ margin:0, fontSize:11.5, color:C.muted }}>Bienvenue sur le Hub de Gestion mobile</p>
            </div>
            <span style={{ fontSize:10.5, fontWeight:700, background:"#F1F0EC", color:C.muted, padding:"4px 9px", borderRadius:999, whiteSpace:"nowrap", flexShrink:0, marginTop:3 }}>Poste #01</span>
          </div>
        </div>

        {/* KPI strip — 3 columns */}
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr 1fr", gap:8 }}>
          {/* C.A. */}
          <div style={{ background:C.cardBg, border:`1px solid ${C.border}`, borderRadius:10, padding:"10px 10px" }}>
            <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:5 }}>
              <span style={{ fontSize:8, fontWeight:700, letterSpacing:"0.05em", color:C.muted, textTransform:"uppercase" }}>C.A. JOUR</span>
              <TrendingUp size={10} color={vsPctPositive ? C.green : C.red}/>
            </div>
            <div style={{ fontSize:19, fontWeight:800, color:C.green, lineHeight:1, fontFamily:"'Bebas Neue',sans-serif" }}>{caFmt}</div>
            <div style={{ fontSize:9.5, color:vsPctPositive ? C.green : C.red, fontWeight:700, marginTop:3 }}>{vsPct}</div>
          </div>
          {/* TICKETS */}
          <div style={{ background:C.cardBg, border:`1px solid ${C.border}`, borderRadius:10, padding:"10px 10px" }}>
            <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:5 }}>
              <span style={{ fontSize:8, fontWeight:700, letterSpacing:"0.05em", color:C.muted, textTransform:"uppercase" }}>TICKETS</span>
              <span style={{ fontSize:9 }}>🧾</span>
            </div>
            <div style={{ fontSize:19, fontWeight:800, color:C.ink, lineHeight:1, fontFamily:"'Bebas Neue',sans-serif" }}>{ticketsFmt}</div>
            <div style={{ fontSize:9.5, color:C.muted, marginTop:3 }}>Clôturés</div>
          </div>
          {/* ALERTES / RUPTURE */}
          <div style={{ background:C.cardBg, border:`1px solid ${ruptureWarn ? "#F5C6C2" : C.border}`, borderRadius:10, padding:"10px 10px" }}>
            <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", marginBottom:5 }}>
              <span style={{ fontSize:8, fontWeight:700, letterSpacing:"0.05em", color:C.muted, textTransform:"uppercase" }}>ALERTES</span>
              <Circle size={6} fill={ruptureWarn ? C.red : C.yellow} color={ruptureWarn ? C.red : C.yellow}/>
            </div>
            <div style={{ fontSize:19, fontWeight:800, color: ruptureWarn ? "#D9720C" : C.ink, lineHeight:1, fontFamily:"'Bebas Neue',sans-serif" }}>{ruptureFmt}</div>
            <div style={{ fontSize:9.5, color: ruptureWarn ? "#D9720C" : C.muted, fontWeight:700, marginTop:3 }}>86 List</div>
          </div>
        </div>

        {/* Cards */}
        <ModuleCard mobile
          icon={<Book size={20}/>} iconBg={C.brown} iconColor={C.yellow}
          pill={<Pill small bg={C.yellowBg} color="#946200">Catalogue</Pill>}
          eyebrow="Gestion du menu" title="Éditer le Menu"
          description="Ajoutez des articles et modifiez les prix en direct."
          checklist={<><ChecklistItem>Prix en direct</ChecklistItem><ChecklistItem>Formules &amp; options</ChecklistItem></>}
          highlight cta="MODIFIER LE MENU" ctaIcon={<ArrowRight size={15}/>} ctaStyle="primary"
          onClick={() => navigate("/menu")}
        />
        <ModuleCard mobile
          icon={<Clock size={20}/>} iconBg="#F1F0EC" iconColor={C.ink}
          pill={<Pill small bg="#F1F0EC" color={C.muted}>Archives</Pill>}
          eyebrow="Commandes &amp; Reçus" title="Order History"
          description="Consultez les tickets et gérez les remboursements."
          checklist={<><ChecklistItem>Réimpression tickets</ChecklistItem><ChecklistItem>Rapprochement</ChecklistItem></>}
          cta="CONSULTER L'HISTORIQUE" ctaIcon={<ChevronRight size={15}/>} ctaStyle="secondary"
          onClick={() => navigate("/historique")}
        />
        <ModuleCard mobile
          icon={<BarChart2 size={20}/>} iconBg={C.blueBg} iconColor={C.blue}
          pill={<Pill small bg="#F1F0EC" color={C.muted}>Clôture Z</Pill>}
          eyebrow="Rapports &amp; Stats" title="Rapports &amp; Statistiques"
          description="Analysez les ventes et exportez vos données."
          checklist={<><ChecklistItem>Marges &amp; TVA</ChecklistItem><ChecklistItem>Export .CSV</ChecklistItem></>}
          cta="VOIR LES STATISTIQUES" ctaIcon={<ChevronRight size={15}/>} ctaStyle="secondary"
          onClick={() => navigate("/statistiques")}
        />
        <ModuleCard mobile
          icon={<Package size={20}/>} iconBg="#FEF3E2" iconColor="#D9720C"
          pill={ruptureWarn ? <Pill small dot dotColor="#D9720C" bg="#FEF3E2" color="#D9720C">{ruptureFmt} ALERTE{(kpi?.rupture.count ?? 0) > 1 ? 'S' : ''} ACTIVES</Pill> : <Pill small bg="#F1F0EC" color={C.muted}>Stock</Pill>}
          eyebrow="Stocks &amp; Ingrédients" title="Inventaire"
          description="Suivez les niveaux de stock et contrôlez la disponibilité des ingrédients."
          checklist={<><ChecklistItem warn={ruptureWarn}>{ruptureFmt} Alerte{(kpi?.rupture.count ?? 0) > 1 ? "s" : ""} de stock critique</ChecklistItem><ChecklistItem>Niveaux en temps réel</ChecklistItem></>}
          cta="GÉRER L'INVENTAIRE" ctaIcon={<ChevronRight size={15}/>} ctaStyle="secondary"
          onClick={() => navigate("/inventaire")}
        />
      </main>

      <footer style={{ display:"flex", alignItems:"center", justifyContent:"center", padding:"12px 16px", borderTop:`1px solid ${C.border}` }}>
        <span style={{ display:"inline-flex", alignItems:"center", gap:6, fontSize:11, fontWeight:600, color:C.ink }}>
          <Circle size={6} fill={C.green} color={C.green}/> Connecté
        </span>
      </footer>
    </div>
  );

  /* ── DESKTOP ── */
  return (
    <div style={shell}>
      <header style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"18px 40px", borderBottom:`1px solid ${C.border}`, background:C.cardBg, flexShrink:0 }}>
        <div style={{ display:"flex", alignItems:"center", gap:12 }}>
          <div style={{ width:38, height:38, borderRadius:9, background:C.brown, color:C.yellow, display:"flex", alignItems:"center", justifyContent:"center" }}>
            <Book size={20}/>
          </div>
          <span style={{ fontSize:17, fontWeight:800, letterSpacing:"0.02em" }}>SPRINTKITCHEN</span>
          <span style={{ background:C.brown, color:"#F5F0E6", fontSize:10, fontWeight:700, padding:"3px 8px", borderRadius:5 }}>HUB</span>
          <Circle size={7} fill={C.yellow} color={C.yellow}/>
        </div>
        <Pill dot dotColor={C.green} bg="#F1F0EC" color={C.ink}>Super Admin — Back-Office</Pill>
      </header>

      <main style={{ flex:1, padding:"48px 40px 40px" }}>
        <div style={{ display:"flex", alignItems:"flex-start", justifyContent:"space-between", gap:40, flexWrap:"wrap", marginBottom:32 }}>
          <div style={{ flex:"1 1 400px" }}>
            <div style={{ display:"flex", alignItems:"center", gap:8, marginBottom:10 }}>
              <span style={{ fontSize:11, fontWeight:600, letterSpacing:"0.05em", color:C.muted }}>PORTAIL OPÉRATIONNEL &amp; DIRECTION</span>
              <span style={{ color:C.muted }}>·</span>
              <span style={{ display:"inline-flex", alignItems:"center", gap:5, fontSize:11, fontWeight:700, color:C.green }}>
                <Circle size={6} fill={C.green} color={C.green}/> SPRINTKITCHEN BACK-OFFICE
              </span>
            </div>
            <div style={{ display:"flex", alignItems:"center", gap:14, marginBottom:12, flexWrap:"wrap" }}>
              <h1 style={{ margin:0, fontSize:34, fontWeight:800 }}>Portail Administrateur</h1>
              <span style={{ fontSize:13, fontWeight:600, color:C.muted, background:"#F1F0EC", padding:"5px 14px", borderRadius:999 }}>Poste Superviseur #01</span>
            </div>
            <p style={{ margin:0, color:C.muted, fontSize:14.5, maxWidth:520, lineHeight:1.6 }}>
              Bienvenue sur le Hub de Gestion • Vue centralisée du restaurant, contrôle des menus et indicateurs financiers.
            </p>
          </div>
          <div style={{ display:"flex", gap:12, flexShrink:0, flexWrap:"wrap" }}>
            <Kpi label="Chiffre d'affaires" value={caFmt} valueColor={C.green} sub={vsPct} subColor={vsPctPositive ? C.green : C.red}/>
            <Kpi label="Tickets Clôturés"   value={ticketsFmt} sub="Aujourd'hui"/>
            <Kpi label="Articles en Rupture" value={ruptureFmt} valueColor={ruptureWarn ? "#D9720C" : C.ink} sub="Ingrédients (86 list)" subColor={ruptureWarn ? "#D9720C" : undefined}/>
          </div>
        </div>

        <div style={{ height:1, background:C.border, marginBottom:28 }}/>

        <div style={{ display:"grid", gridTemplateColumns:"repeat(4, 1fr)", gap:18 }}>
          <ModuleCard
            icon={<Book size={24}/>} iconBg={C.brown} iconColor={C.yellow}
            pill={<Pill small dot dotColor="#C98A1A" bg={C.yellowBg} color="#946200">CATALOGUE &amp; PRIX</Pill>}
            eyebrow="Gestion du menu" title="Éditer le Menu / Catalog"
            description="Ajoutez de nouveaux articles, modifiez les prix, configurez les formules et mettez à jour les visuels."
            checklist={<><ChecklistItem>Modification des prix en temps réel</ChecklistItem><ChecklistItem>Gestion des catégories et options</ChecklistItem></>}
            highlight cta="MODIFIER LE MENU" ctaIcon={<ArrowRight size={16}/>} ctaStyle="primary"
            onClick={() => navigate("/menu")}
          />
          <ModuleCard
            icon={<Clock size={24}/>} iconBg="#F1F0EC" iconColor={C.ink}
            pill={<Pill small bg="#F1F0EC" color={C.muted}>ARCHIVES &amp; TICKETS</Pill>}
            eyebrow="Commandes &amp; Reçus" title="Historique des Commandes"
            description="Consultez les tickets, recherchez les reçus, gérez les remboursements et exportez vos données."
            checklist={<><ChecklistItem>Recherche de tickets &amp; réimpression</ChecklistItem><ChecklistItem>Remboursements &amp; exports</ChecklistItem></>}
            cta="CONSULTER L'HISTORIQUE" ctaIcon={<ChevronRight size={16}/>} ctaStyle="secondary"
            onClick={() => navigate("/historique")}
          />
          <ModuleCard
            icon={<BarChart2 size={24}/>} iconBg={C.blueBg} iconColor={C.blue}
            pill={<Pill small bg="#F1F0EC" color={C.muted}>CLÔTURE Z &amp; FINANCES</Pill>}
            eyebrow="Rapports &amp; Stats" title="Rapports &amp; Statistiques"
            description="Analysez les ventes journalières, visualisez les produits les plus vendus et exportez vos données comptables."
            checklist={<><ChecklistItem>Chiffre d'affaires et marges</ChecklistItem><ChecklistItem>Export TVA et rapports Z</ChecklistItem></>}
            cta="VOIR LES STATISTIQUES" ctaIcon={<ChevronRight size={16}/>} ctaStyle="secondary"
            onClick={() => navigate("/statistiques")}
          />
          <ModuleCard
            icon={<Package size={24}/>} iconBg="#FEF3E2" iconColor="#D9720C"
            pill={ruptureWarn ? <Pill small dot dotColor="#D9720C" bg="#FEF3E2" color="#D9720C">{ruptureFmt} ALERTE{(kpi?.rupture.count ?? 0) > 1 ? 'S' : ''} ACTIVES</Pill> : <Pill small bg="#F1F0EC" color={C.muted}>Stock</Pill>}
            eyebrow="Stocks &amp; Ingrédients" title="Inventaire"
            description="Gérez les niveaux de stock, suivez les mouvements et contrôlez la disponibilité des ingrédients en temps réel."
            checklist={<><ChecklistItem warn={ruptureWarn}>{ruptureFmt} Alerte{(kpi?.rupture.count ?? 0) > 1 ? "s" : ""} de stock critique</ChecklistItem><ChecklistItem>Niveaux de stock en temps réel</ChecklistItem></>}
            cta="GÉRER L'INVENTAIRE" ctaIcon={<ChevronRight size={16}/>} ctaStyle="secondary"
            onClick={() => navigate("/inventaire")}
          />
        </div>
      </main>

      <footer style={{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"16px 40px", borderTop:`1px solid ${C.border}`, flexShrink:0 }}>
        <div style={{ display:"flex", alignItems:"center", gap:7, fontSize:13, fontWeight:600 }}>
          <Circle size={7} fill={C.green} color={C.green}/> Connecté <span style={{ color:C.muted }}>·</span>
        </div>
        <span style={{ fontSize:12, color:C.muted }}>SprintKitchen OS Admin v2.4.0-PROD</span>
      </footer>
    </div>
  );
}
