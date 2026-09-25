import React from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft, ChevronDown, ChevronLeft, ChevronRight as ChevronRightIcon,
  Search, Printer, Circle, Calendar, Smile, X, CheckCircle2, RotateCcw, Ban,
} from "lucide-react";
import { orderService, paymentService } from "../services";

const COLORS = {
  bg: "#F5F4F0", cardBg: "#FFFFFF", ink: "#1C1917", brown: "#2E2117",
  yellow: "#F2B705", muted: "#8B8378", border: "#E7E4DD", green: "#2FAE5C",
  red: "#C0392B", redBg: "#FBEAE7", blue: "#2E5BD9", blueBg: "#EAF0FE",
  rowHover: "#FAF9F6",
};

const PAYMENT_LABELS = {
  especes: "Espèces",
  carte_bancaire: "Carte Bancaire",
  sans_contact: "Sans Contact",
  ticket_restaurant: "Ticket Restaurant",
  mixte: "Paiement Mixte",
};

const TAB_STATUS = {
  "terminées": "terminee",
  attente: "en_attente",
  encaisser: "a_encaisser",
  repas: "repas_employe",
};

function fmtPrice(n) {
  return `${(n || 0).toFixed(2).replace(".", ",")} DA`;
}

function addDays(d, n) { const r = new Date(d); r.setDate(r.getDate() + n); return r; }
function startOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1); }
function endOfMonth(d) { return new Date(d.getFullYear(), d.getMonth() + 1, 0); }
function formatDate(d) {
  if (!d) return "";
  return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()}`;
}
function isSameDay(a, b) {
  return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

const FR_MONTHS = ["JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN", "JUILLET", "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"];
const FR_DAYS_SHORT = ["L", "M", "M", "J", "V", "S", "D"];
const RANGE_BG = "#FDE9A0";

/* ── Order Detail Drawer ───────────────────────────────────────────────────────────────────── */
function OrderDetailDrawer({ order, onClose, onRefund }) {
  const [detail, setDetail] = React.useState(null);
  const [payment, setPayment] = React.useState(null);
  const [drawerLoading, setDrawerLoading] = React.useState(true);

  React.useEffect(() => {
    let cancelled = false;
    setDrawerLoading(true);
    Promise.all([
      orderService.getById(order._id),
      paymentService.getByOrder(order._id),
    ])
      .then(([orderRes, payRes]) => {
        if (cancelled) return;
        setDetail(orderRes.data.data);
        const payData = payRes.data.data;
        setPayment(Array.isArray(payData) ? payData[0] : payData);
      })
      .catch(console.error)
      .finally(() => { if (!cancelled) setDrawerLoading(false); });
    return () => { cancelled = true; };
  }, [order._id]);

  const isSurPlace = order.mode === "sur-place";
  const paymentLabel = payment ? (PAYMENT_LABELS[payment.method] || payment.method) : null;
  const paymentRef = payment ? (payment.cardReference || (payment._id?.slice(-6).toUpperCase())) : null;
  const paymentSub = payment
    ? (payment.method === "especes" ? "Rendu : " + fmtPrice(payment.change || 0) : "Paiement électronique")
    : null;

  const handleRefundClick = async () => {
    try {
      await orderService.cancel(order._id, "Remboursement demandé");
      onRefund(order._id);
    } catch (e) {
      console.error(e);
    }
  };

  const printReceipt = (kitchenOnly = false) => {
    const d = detail;
    const date = new Date(d?.createdAt || order.date).toLocaleString("fr-FR");
    const items = (d?.items || []).map(i =>
      `<tr><td>${i.quantity}x ${i.productName}</td><td style="text-align:right">${(i.lineTotal||0).toLocaleString("fr-FR",{minimumFractionDigits:2})} DA</td></tr>`
    ).join("");
    const html = kitchenOnly ? `
      <html><head><title>Bon Cuisine</title><style>
        body{font-family:monospace;font-size:14px;width:280px;margin:0 auto;padding:10px}
        h2{text-align:center;margin:0 0 8px} hr{border:1px dashed #000}
        table{width:100%} td{padding:3px 0}
      </style></head><body>
        <h2>BON DE CUISINE</h2>
        <p style="text-align:center;margin:0">Commande ${order.num} — ${date}</p>
        <hr/><table>${items}</table><hr/>
        ${d?.notes ? `<div style="background:#fef3c7;border:1px solid #f59e0b;padding:8px;margin:8px 0;border-radius:4px;font-weight:bold;font-size:13px;color:#92400e">NOTE CUISINE : ${d.notes}</div>` : ""}
        <p style="text-align:center">MODE: ${order.mode?.toUpperCase()}</p>
      </body></html>
    ` : `
      <html><head><title>Ticket ${order.num}</title><style>
        body{font-family:monospace;font-size:13px;width:300px;margin:0 auto;padding:12px}
        h2{text-align:center;margin:4px 0} .center{text-align:center} hr{border:1px dashed #999}
        table{width:100%} td{padding:3px 0} .right{text-align:right} .bold{font-weight:bold}
        .total td{font-size:15px;font-weight:bold;border-top:1px solid #000;padding-top:6px}
      </style></head><body>
        <h2>SPRINTKITCHEN</h2>
        <p class="center" style="margin:0;font-size:11px">Votre restaurant fast-food</p>
        <hr/>
        <p class="center" style="margin:4px 0">Commande ${order.num}</p>
        <p class="center" style="margin:0;font-size:11px">${date}</p>
        <p class="center" style="margin:4px 0;font-size:11px">Mode: ${order.mode || ""} · ${paymentLabel || ""}</p>
        ${d?.notes ? `<p style="margin:6px 0;font-size:12px;font-weight:bold;color:#333">NOTE CUISINE : ${d.notes}</p>` : ""}
        <hr/>
        <table>${items}</table>
        <hr/>
        <table>
          <tr><td>Sous-total HT</td><td class="right">${((d?.totalHT||0)).toLocaleString("fr-FR",{minimumFractionDigits:2})} DA</td></tr>
          <tr><td>TVA (10%)</td><td class="right">${((d?.totalTVA||0)).toLocaleString("fr-FR",{minimumFractionDigits:2})} DA</td></tr>
          <tr class="total"><td>TOTAL TTC</td><td class="right">${((d?.totalTTC||0)).toLocaleString("fr-FR",{minimumFractionDigits:2})} DA</td></tr>
        </table>
        ${payment?.method === "especes" ? `<p class="center" style="font-size:11px">Espèces reçues · Rendu : ${(payment.change||0).toLocaleString("fr-FR",{minimumFractionDigits:2})} DA</p>` : ""}
        <hr/>
        <p class="center" style="font-size:12px;margin:8px 0">Merci de votre visite !</p>
        <p class="center" style="font-size:10px;color:#666">SprintKitchen — Bon appétit</p>
      </body></html>
    `;
    const w = window.open("", "_blank", "width=350,height=600");
    w.document.write(html);
    w.document.close();
    w.focus();
    setTimeout(() => { w.print(); w.close(); }, 400);
  };

  return (
    <>
      <div onClick={onClose}
        style={{ position:"fixed",inset:0,background:"rgba(28,25,23,.35)",zIndex:300 }} />
      <div style={{
        position:"fixed",top:0,right:0,height:"100vh",width:500,
        background:COLORS.bg,zIndex:301,display:"flex",flexDirection:"column",
        boxShadow:"-8px 0 40px rgba(0,0,0,.18)",overflowY:"auto",
      }}>
        {/* Header */}
        <div style={{ padding:"20px 24px 16px",borderBottom:`1px solid ${COLORS.border}`,background:COLORS.cardBg }}>
          <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:8 }}>
            <div style={{ display:"flex",alignItems:"center",gap:12 }}>
              <div style={{ width:40,height:40,borderRadius:10,background:COLORS.brown,color:COLORS.yellow,display:"flex",alignItems:"center",justifyContent:"center",fontWeight:800,fontSize:13,flexShrink:0 }}>
                SK
              </div>
              <div>
                <div style={{ display:"flex",alignItems:"center",gap:10 }}>
                  <span style={{ fontSize:18,fontWeight:800,color:COLORS.ink,fontFamily:"'Bebas Neue',sans-serif",letterSpacing:"0.03em" }}>
                    COMMANDE {order.num}
                  </span>
                  <span style={{
                    fontSize:11, fontWeight:700, padding:"3px 10px", borderRadius:999,
                    background: order.status === "annulee" ? "#FDEAE8" : order.status === "en_attente" ? "#FEF3CD" : "#E6F9EE",
                    color:      order.status === "annulee" ? COLORS.red  : order.status === "en_attente" ? "#946200" : COLORS.green,
                  }}>
                    {order.status === "annulee" ? "✕ Annulée" : order.status === "en_attente" ? "⏳ En attente" : "● Terminée"}
                  </span>
                </div>
                <div style={{ fontSize:12,color:COLORS.muted,marginTop:2 }}>
                  Historique de vente • Transaction confirmée
                </div>
              </div>
            </div>
            <button onClick={onClose}
              style={{ display:"inline-flex",alignItems:"center",gap:6,padding:"7px 12px",border:`1px solid ${COLORS.border}`,borderRadius:8,background:COLORS.cardBg,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit",color:COLORS.ink }}>
              <X size={14} /> Fermer
            </button>
          </div>
        </div>

        {/* Body */}
        <div style={{ flex:1,padding:"16px 20px",display:"flex",flexDirection:"column",gap:12 }}>
          {drawerLoading ? (
            <div style={{ padding:40,textAlign:"center",color:COLORS.muted }}>Chargement...</div>
          ) : (
            <>
              {/* Info card */}
              <div style={{ background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,padding:"16px 20px" }}>
                <div style={{ display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px 24px" }}>
                  <div>
                    <div style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5 }}>Date &amp; Heure</div>
                    <div style={{ fontSize:13.5,fontWeight:500,color:COLORS.ink,display:"flex",alignItems:"center",gap:6 }}>
                      <Calendar size={13} color={COLORS.muted} />
                      {order.date} à {order.time}
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5 }}>Caisse &amp; Opérateur</div>
                    <div style={{ fontSize:13.5,fontWeight:500,color:COLORS.ink,display:"flex",alignItems:"center",gap:6 }}>
                      <Circle size={7} fill={COLORS.green} color={COLORS.green} />
                      {order.caisse} (Admin)
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5 }}>Client / Localisation</div>
                    <div style={{ fontSize:13.5,fontWeight:600,color:COLORS.ink }}>{order.client}</div>
                  </div>
                  <div>
                    <div style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5 }}>Mode de consommation</div>
                    <span style={{ display:"inline-flex",alignItems:"center",gap:5,fontSize:12,fontWeight:700,padding:"3px 10px",borderRadius:999,background:isSurPlace?COLORS.redBg:COLORS.blueBg,color:isSurPlace?COLORS.red:COLORS.blue }}>
                      ● {isSurPlace?"Sur place":"À emporter"}
                    </span>
                  </div>
                </div>
                <div style={{ marginTop:12,paddingTop:12,borderTop:`1px solid ${COLORS.border}`,display:"flex",alignItems:"center",justifyContent:"space-between" }}>
                  <span style={{ fontSize:12.5,color:COLORS.muted }}>Canal de prise de commande :</span>
                  <span style={{ fontSize:12.5,fontWeight:600,color:COLORS.ink }}>
                    {detail?.registerId?.name || order.caisse}
                  </span>
                </div>
              </div>

              {/* Note cuisine */}
              {detail?.notes && (
                <div style={{ background:"#FEF3C7",border:"1px solid #F59E0B",borderRadius:12,padding:"12px 16px",display:"flex",alignItems:"flex-start",gap:10 }}>
                  <span style={{ fontSize:16,lineHeight:1 }}>📝</span>
                  <div>
                    <div style={{ fontSize:11,fontWeight:700,letterSpacing:"0.07em",color:"#B45309",textTransform:"uppercase",marginBottom:4 }}>
                      Note Cuisine / Commentaire
                    </div>
                    <div style={{ fontSize:13.5,fontWeight:600,color:"#78350F" }}>
                      {detail.notes}
                    </div>
                  </div>
                </div>
              )}

              {/* Items card */}
              <div style={{ background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,overflow:"hidden" }}>
                <div style={{ display:"grid",gridTemplateColumns:"40px 1fr auto",padding:"10px 16px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8" }}>
                  <span style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted }}>QTÉ</span>
                  <span style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted }}>ARTICLE &amp; SUPPLÉMENTS</span>
                  <span style={{ fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textAlign:"right" }}>PRIX</span>
                </div>
                {(detail?.items || []).map((item, i) => (
                  <div key={i} style={{ display:"grid",gridTemplateColumns:"40px 1fr auto",padding:"14px 16px",borderBottom:i<(detail.items.length-1)?`1px solid ${COLORS.border}`:"none",gap:"0 8px" }}>
                    <div style={{ fontSize:13,fontWeight:700,color:COLORS.muted,paddingTop:2 }}>{item.quantity}×</div>
                    <div>
                      <div style={{ fontWeight:700,fontSize:14,color:COLORS.ink }}>{item.productName}</div>
                      {(item.customizations || []).map((cust, ci) => (
                        <div key={ci} style={{ fontSize:12,color:COLORS.muted,marginTop:2 }}>
                          • {cust.groupName}: {(cust.selectedOptions || []).map(o => o.label).join(", ")}
                        </div>
                      ))}
                      {(item.removedIngredients || []).map((ing, ri) => (
                        <div key={ri} style={{ fontSize:12,color:"#B07A00",fontWeight:600,marginTop:2 }}>• Sans {ing}</div>
                      ))}
                      {item.notes && (
                        <div style={{ fontSize:12,color:COLORS.muted,fontStyle:"italic",marginTop:3 }}> {item.notes}</div>
                      )}
                    </div>
                    <div style={{ fontSize:13.5,fontWeight:700,color:COLORS.ink,textAlign:"right",paddingTop:2 }}>
                      {fmtPrice(item.lineTotal)}
                    </div>
                  </div>
                ))}
                {(!detail?.items || detail.items.length === 0) && (
                  <div style={{ padding:"20px 16px",color:COLORS.muted,fontSize:13,textAlign:"center" }}>Aucun article</div>
                )}
              </div>

              {/* Totals */}
              <div style={{ background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,padding:"14px 20px" }}>
                <div style={{ display:"flex",justifyContent:"space-between",marginBottom:6 }}>
                  <span style={{ fontSize:12.5,color:COLORS.muted }}>Sous-total HT</span>
                  <span style={{ fontSize:12.5,fontWeight:600,color:COLORS.ink }}>{fmtPrice(detail?.subtotalHT)}</span>
                </div>
                <div style={{ display:"flex",justifyContent:"space-between",marginBottom:10 }}>
                  <span style={{ fontSize:12.5,color:COLORS.muted }}>TVA</span>
                  <span style={{ fontSize:12.5,fontWeight:600,color:COLORS.ink }}>{fmtPrice(detail?.tvaAmount)}</span>
                </div>
                <div style={{ display:"flex",justifyContent:"space-between",alignItems:"center",paddingTop:10,borderTop:`1px solid ${COLORS.border}` }}>
                  <div>
                    <div style={{ fontSize:11,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase" }}>Total Payé</div>
                    <div style={{ fontSize:10,color:COLORS.muted,marginTop:1 }}>Toutes taxes comprises</div>
                  </div>
                  <span style={{ fontSize:26,fontWeight:800,color:COLORS.ink }}>{fmtPrice(detail?.totalTTC)}</span>
                </div>
              </div>

              {/* Payment */}
              {payment ? (
                <div style={{ background:"#F0FAF4",border:"1px solid #C3EDD4",borderRadius:12,padding:"12px 16px",display:"flex",alignItems:"center",gap:12 }}>
                  <CheckCircle2 size={20} color={COLORS.green} fill="#D4F5E2" strokeWidth={2} style={{ flexShrink:0 }} />
                  <div>
                    <div style={{ fontSize:13,fontWeight:700,color:"#1A7A42" }}>Payé par {paymentLabel}</div>
                    <div style={{ fontSize:12,color:COLORS.muted,marginTop:1 }}>
                      {paymentSub} • Réf #{paymentRef}
                    </div>
                  </div>
                </div>
              ) : (
                <div style={{ background:"#F0FAF4",border:"1px solid #C3EDD4",borderRadius:12,padding:"12px 16px",display:"flex",alignItems:"center",gap:12 }}>
                  <CheckCircle2 size={20} color={COLORS.green} fill="#D4F5E2" strokeWidth={2} style={{ flexShrink:0 }} />
                  <div>
                    <div style={{ fontSize:13,fontWeight:700,color:"#1A7A42" }}>Paiement enregistré</div>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div style={{ padding:"14px 20px",borderTop:`1px solid ${COLORS.border}`,background:COLORS.cardBg,display:"flex",flexDirection:"column",gap:10 }}>
          <button onClick={() => printReceipt(false)} style={{ width:"100%",padding:"13px",borderRadius:11,border:"none",background:COLORS.yellow,color:COLORS.brown,fontSize:14,fontWeight:800,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:10 }}>
            <Printer size={16} /> IMPRIMER LE TICKET DE CAISSE
          </button>
          <div style={{ display:"flex",gap:10 }}>
            <button onClick={() => printReceipt(true)} style={{ flex:1,padding:"11px",borderRadius:10,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,color:COLORS.ink,fontSize:12.5,fontWeight:600,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:7 }}>
              <RotateCcw size={14} /> Réimprimer Bon Cuisine
            </button>
            <button onClick={handleRefundClick} style={{ flex:1,padding:"11px",borderRadius:10,border:`1px solid ${COLORS.redBg}`,background:COLORS.redBg,color:COLORS.red,fontSize:12.5,fontWeight:600,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:7 }}>
              <Ban size={14} /> Remboursement / Annulation
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

/* ── Shared helpers ─────────────────────────────────────────────────────────────────────────────── */
function ModePill({ mode }) {
  const isSurPlace = mode === "sur-place";
  return (
    <span style={{ display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,padding:"4px 10px",borderRadius:999,background:isSurPlace?COLORS.redBg:COLORS.blueBg,color:isSurPlace?COLORS.red:COLORS.blue }}>
      <Circle size={6} fill={isSurPlace?COLORS.red:COLORS.blue} color={isSurPlace?COLORS.red:COLORS.blue} />
      {isSurPlace ? "Sur place" : "À emporter"}
    </span>
  );
}

function Tab({ children, active, waiting, badge, onClick }) {
  return (
    <button onClick={onClick} style={{ display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:700,padding:"10px 16px",borderRadius:10,background:active?COLORS.brown:COLORS.cardBg,border:`1px solid ${active?COLORS.brown:COLORS.border}`,color:active?"#F5F0E6":COLORS.muted,cursor:"pointer",fontFamily:"inherit" }}>
      {waiting && <Circle size={6} fill={COLORS.yellow} color={COLORS.yellow} />}
      {children}
      {badge != null && <span style={{ background:active?COLORS.yellow:"#EFECE4",color:active?COLORS.brown:COLORS.ink,fontSize:11,fontWeight:800,padding:"1px 7px",borderRadius:999 }}>{badge}</span>}
    </button>
  );
}

function PageBtn({ children, active, disabled, onClick }) {
  return (
    <button disabled={disabled} onClick={onClick} style={{ minWidth:34,height:34,padding:"0 10px",borderRadius:8,border:`1px solid ${active?COLORS.brown:COLORS.border}`,background:active?COLORS.brown:COLORS.cardBg,color:disabled?"#C7C0B4":active?"#F5F0E6":COLORS.ink,fontSize:13,fontWeight:600,cursor:disabled?"default":"pointer",fontFamily:"inherit" }}>
      {children}
    </button>
  );
}

function cellStyle(i, total) {
  return { padding:"14px 20px",fontSize:13.5,borderBottom:i===total-1?"none":`1px solid ${COLORS.border}`,color:COLORS.ink,verticalAlign:"middle" };
}

/* ── Date Range Modal ────────────────────────────────────────────────────────────────────── */
function MonthGrid({ year, month, lo, hi, picking, hovered, onDayClick, onDayHover }) {
  const TODAY_REF = new Date();
  let startDow = new Date(year, month, 1).getDay();
  startDow = startDow === 0 ? 6 : startDow - 1;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < startDow; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));
  const effHi = hi || (picking && hovered ? hovered : null);
  const realLo = lo && effHi ? (lo <= effHi ? lo : effHi) : lo;
  const realHi = lo && effHi ? (lo <= effHi ? effHi : lo) : null;

  return (
    <div style={{ flex:1, minWidth:0 }}>
      <div style={{ textAlign:"center",fontWeight:800,fontSize:12.5,letterSpacing:"0.07em",color:COLORS.ink,marginBottom:12 }}>
        {FR_MONTHS[month]} {year}
      </div>
      <div style={{ display:"grid",gridTemplateColumns:"repeat(7,34px)",rowGap:1,justifyContent:"center" }}>
        {FR_DAYS_SHORT.map((d, i) => (
          <div key={i} style={{ textAlign:"center",fontSize:11,fontWeight:700,color:COLORS.muted,paddingBottom:6,height:22,display:"flex",alignItems:"center",justifyContent:"center" }}>{d}</div>
        ))}
        {cells.map((d, i) => {
          if (!d) return <div key={`e${i}`} style={{ height:36 }} />;
          const isStart = realLo && isSameDay(d, realLo);
          const isEnd = realHi && isSameDay(d, realHi);
          const isBoth = isStart && isEnd;
          const inRange = realLo && realHi && d > realLo && d < realHi;
          const isToday = isSameDay(d, TODAY_REF);
          const isSelect = isStart || isEnd;
          let cellBg = "transparent";
          if (!isBoth) {
            if (isStart && realHi) cellBg = `linear-gradient(to right, transparent 50%, ${RANGE_BG} 50%)`;
            else if (isEnd) cellBg = `linear-gradient(to left, transparent 50%, ${RANGE_BG} 50%)`;
            else if (inRange) cellBg = RANGE_BG;
          }
          return (
            <div key={i}
              onClick={() => onDayClick(d)}
              onMouseEnter={() => onDayHover(d)}
              style={{ height:36,display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",background:cellBg }}
            >
              <span style={{
                display:"inline-flex",alignItems:"center",justifyContent:"center",
                width:32,height:32,borderRadius:"50%",fontSize:13,
                fontWeight: isSelect ? 700 : 400,
                background: isSelect ? COLORS.brown : inRange ? RANGE_BG : "transparent",
                color: isSelect ? "#FFF8E7" : inRange ? "#7A5C00" : isToday ? COLORS.brown : COLORS.ink,
                boxShadow: isToday && isEnd && !isBoth
                  ? `0 0 0 2px ${COLORS.brown}, 0 0 0 4.5px ${COLORS.yellow}`
                  : isToday && !isSelect ? `0 0 0 2px ${COLORS.yellow}` : "none",
              }}>
                {d.getDate()}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function DateRangeModal({ onClose, onApply }) {
  const TODAY = new Date();
  const [rangeStart, setRangeStart] = React.useState(addDays(TODAY, -6));
  const [rangeEnd, setRangeEnd] = React.useState(new Date(TODAY));
  const [hovered, setHovered] = React.useState(null);
  const [picking, setPicking] = React.useState(false);
  const [activeKey, setActiveKey] = React.useState("7j");
  const [rightMonth, setRightMonth] = React.useState({ year: TODAY.getFullYear(), month: TODAY.getMonth() });
  const leftMonth = rightMonth.month === 0
    ? { year: rightMonth.year - 1, month: 11 }
    : { year: rightMonth.year, month: rightMonth.month - 1 };

  const apply = (fn, key) => { fn(); setActiveKey(key); setPicking(false); };

  const shortcuts = [
    { key:"today", label:"Aujourd’hui", sub:null, fn:() => { const t=new Date(); setRangeStart(t); setRangeEnd(new Date(t)); } },
    { key:"hier",  label:"Hier",             sub:null, fn:() => { const y=addDays(new Date(),-1); setRangeStart(y); setRangeEnd(new Date(y)); } },
    { key:"7j",    label:"7 derniers jours", sub:null, fn:() => { const t=new Date(); setRangeStart(addDays(t,-6)); setRangeEnd(t); } },
    { key:"mois",  label:"Ce mois-ci",       sub:null, fn:() => { const t=new Date(); setRangeStart(startOfMonth(t)); setRangeEnd(t); } },
    { key:"last",  label:"Mois dernier",     sub:null, fn:() => { const t=new Date(); const lm=new Date(t.getFullYear(),t.getMonth()-1,1); setRangeStart(lm); setRangeEnd(endOfMonth(lm)); } },
    { key:"custom",label:"Personnalisé", chevron:true, fn:() => {} },
  ];

  const handleDayClick = (d) => {
    setActiveKey("custom");
    if (!picking) { setRangeStart(d); setRangeEnd(null); setPicking(true); }
    else {
      if (d < rangeStart) { setRangeEnd(rangeStart); setRangeStart(d); }
      else { setRangeEnd(d); }
      setPicking(false);
    }
  };

  const effEnd = rangeEnd || rangeStart;
  const lo = rangeStart && effEnd ? (rangeStart <= effEnd ? rangeStart : effEnd) : rangeStart;
  const hi = rangeStart && effEnd ? (rangeStart <= effEnd ? effEnd : rangeStart) : null;
  const dayCount = lo && hi ? Math.round(Math.abs(hi - lo) / 86400000) + 1 : 1;

  const navBtn = (onClick, icon) => (
    <button onClick={onClick} style={{ background:"none",border:`1px solid ${COLORS.border}`,borderRadius:8,width:30,height:30,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",color:COLORS.ink,flexShrink:0 }}>
      {icon}
    </button>
  );

  return (
    <div onClick={e => e.target === e.currentTarget && onClose()}
      style={{ position:"fixed",inset:0,background:"rgba(28,25,23,.5)",zIndex:400,display:"flex",alignItems:"center",justifyContent:"center",padding:20 }}>
      <div style={{ background:COLORS.cardBg,borderRadius:16,width:"min(760px,96vw)",boxShadow:"0 24px 80px rgba(0,0,0,.3)",overflow:"hidden" }}>
        <div style={{ display:"flex",alignItems:"flex-start",justifyContent:"space-between",padding:"18px 22px 16px" }}>
          <div style={{ display:"flex",alignItems:"center",gap:12 }}>
            <div style={{ width:38,height:38,borderRadius:9,background:"#F1F0EC",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}>
              <Calendar size={17} color={COLORS.ink} />
            </div>
            <div>
              <div style={{ fontSize:15.5,fontWeight:800,color:COLORS.ink,lineHeight:1.2 }}>
                SÉLECTIONNER UNE PÉRIODE DE VENTE
              </div>
              <div style={{ fontSize:12,color:COLORS.muted,marginTop:3 }}>
                Filtrer l’historique des encaissements, tickets et statistiques
              </div>
            </div>
          </div>
          <button onClick={onClose} style={{ background:"none",border:"none",cursor:"pointer",color:COLORS.muted,padding:4,flexShrink:0 }}>
            <X size={16} />
          </button>
        </div>
        <div style={{ height:1,background:COLORS.border }} />
        <div style={{ display:"flex" }}>
          <div style={{ width:185,borderRight:`1px solid ${COLORS.border}`,padding:"14px 0",flexShrink:0 }}>
            <div style={{ fontSize:10,fontWeight:700,letterSpacing:"0.09em",color:COLORS.muted,textTransform:"uppercase",padding:"0 14px 10px" }}>
              Raccourcis rapides
            </div>
            {shortcuts.map(s => {
              const on = activeKey === s.key;
              return (
                <button key={s.key} onClick={() => apply(s.fn, s.key)}
                  style={{ display:"flex",alignItems:"center",justifyContent:"space-between",width:on?"calc(100% - 12px)":"100%",margin:on?"3px 6px":"3px 0",padding:"9px 14px",background:on?COLORS.brown:"transparent",border:"none",cursor:"pointer",fontFamily:"inherit",textAlign:"left",borderRadius:on?9:0 }}>
                  <span style={{ fontSize:13,fontWeight:600,color:on?"#FFF8E7":COLORS.ink }}>{s.label}</span>
                  <span style={{ display:"flex",alignItems:"center",gap:5,flexShrink:0 }}>
                    {on && <span style={{ fontSize:10,fontWeight:800,background:COLORS.yellow,color:COLORS.brown,padding:"2px 8px",borderRadius:999,whiteSpace:"nowrap" }}>Actif</span>}
                    {s.chevron && <ChevronRightIcon size={12} color={COLORS.muted} />}
                  </span>
                </button>
              );
            })}
          </div>
          <div style={{ flex:1,padding:"14px 8px 18px" }} onMouseLeave={() => setHovered(null)}>
            <div style={{ display:"flex",alignItems:"flex-start",gap:6 }}>
              <div style={{ paddingTop:2,flexShrink:0 }}>
                {navBtn(() => setRightMonth(p => p.month===0?{year:p.year-1,month:11}:{year:p.year,month:p.month-1}), <ChevronLeft size={13}/>)}
              </div>
              <div style={{ display:"flex",flex:1,gap:8,minWidth:0 }}>
                <MonthGrid {...leftMonth} lo={lo} hi={hi} picking={picking} hovered={hovered} onDayClick={handleDayClick} onDayHover={setHovered} />
                <MonthGrid {...rightMonth} lo={lo} hi={hi} picking={picking} hovered={hovered} onDayClick={handleDayClick} onDayHover={setHovered} />
              </div>
              <div style={{ paddingTop:2,flexShrink:0 }}>
                {navBtn(() => setRightMonth(p => p.month===11?{year:p.year+1,month:0}:{year:p.year,month:p.month+1}), <ChevronRightIcon size={13}/>)}
              </div>
            </div>
          </div>
        </div>
        <div style={{ height:1,background:COLORS.border }} />
        <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"14px 22px",gap:12,flexWrap:"wrap" }}>
          <div style={{ display:"flex",alignItems:"center",gap:8 }}>
            <span style={{ fontSize:13,color:COLORS.ink,fontWeight:500 }}>Période sélectionnée :</span>
            <span style={{ fontSize:12,fontWeight:600,background:"#F5F4F0",border:`1px solid ${COLORS.border}`,borderRadius:7,padding:"4px 10px",fontFamily:"monospace",whiteSpace:"nowrap" }}>
              {formatDate(lo)} — {formatDate(hi || lo)}
              {dayCount > 0 && <span style={{ color:COLORS.muted,marginLeft:5 }}>({dayCount} jour{dayCount>1?"s":""})</span>}
            </span>
          </div>
          <div style={{ display:"flex",gap:10,flexShrink:0 }}>
            <button onClick={onClose} style={{ padding:"9px 18px",borderRadius:9,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit",color:COLORS.ink }}>
              Annuler
            </button>
            <button onClick={() => { onApply(lo, hi || lo); onClose(); }}
              style={{ padding:"9px 20px",borderRadius:9,border:"none",background:COLORS.yellow,fontSize:13,fontWeight:800,cursor:"pointer",fontFamily:"inherit",color:COLORS.brown,display:"flex",alignItems:"center",gap:6 }}>
              ✓ Appliquer la période
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ── Page ────────────────────────────────────────────────────────────────────────────────────────────────────── */
export default function HistoriquePage() {
  const navigate = useNavigate();
  const [activeTab,      setActiveTab]      = React.useState("terminées");
  const [page,           setPage]           = React.useState(1);
  const [search,         setSearch]         = React.useState("");
  const [showDatePicker, setShowDatePicker] = React.useState(false);
  const [appliedRange,   setAppliedRange]   = React.useState({
    start: addDays(new Date(), -6),
    end:   new Date(),
  });
  const [selectedOrder,  setSelectedOrder]  = React.useState(null);
  const [orders,         setOrders]         = React.useState([]);
  const [loading,        setLoading]        = React.useState(true);
  const [totalOrders,    setTotalOrders]    = React.useState(0);
  const [totalPages,     setTotalPages]     = React.useState(1);

  const fetchOrders = React.useCallback(async () => {
    setLoading(true);
    try {
      const res = await orderService.getAll({
        status: TAB_STATUS[activeTab],
        search: search || undefined,
        page,
        limit: 10,
        from: appliedRange.start.toISOString(),
        to: new Date(
          appliedRange.end.getFullYear(),
          appliedRange.end.getMonth(),
          appliedRange.end.getDate(),
          23, 59, 59
        ).toISOString(),
      });
      setOrders(res.data.data || []);
      setTotalOrders(res.data.total || 0);
      setTotalPages(res.data.totalPages || 1);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }, [activeTab, search, page, appliedRange]);

  React.useEffect(() => { fetchOrders(); }, [fetchOrders]);

  const handleTabChange = (tab) => { setActiveTab(tab); setPage(1); };
  const handleSearchChange = (val) => { setSearch(val); setPage(1); };
  const handleRangeApply = (start, end) => { setAppliedRange({ start, end }); setPage(1); };
  const handleRefund = (id) => {
    setOrders(prev => prev.map(o => o._id === id ? { ...o, status: "annulee" } : o));
    setSelectedOrder(null);
  };

  return (
    <div style={{ minHeight:"100vh",background:COLORS.bg,fontFamily:"'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",color:COLORS.ink,display:"flex",flexDirection:"column" }}>

      {/* Header */}
      <header style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"14px 32px",borderBottom:`1px solid ${COLORS.border}`,background:COLORS.cardBg }}>
        <div style={{ display:"flex",alignItems:"center",gap:18 }}>
          <button onClick={() => navigate("/")} style={{ display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:600,color:COLORS.ink,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:8,padding:"8px 14px",cursor:"pointer",fontFamily:"inherit" }}>
            <ArrowLeft size={15} /> Retour à l’accueil
          </button>
          <div style={{ display:"flex",alignItems:"center",gap:10 }}>
            <div style={{ width:30,height:30,borderRadius:"50%",background:COLORS.brown,color:COLORS.yellow,display:"flex",alignItems:"center",justifyContent:"center" }}>
              <Smile size={16} />
            </div>
            <span style={{ fontSize:15,fontWeight:800,letterSpacing:"0.02em" }}>SPRINTKITCHEN</span>
          </div>
        </div>
        <span style={{ display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,padding:"6px 12px",borderRadius:999,background:"#F1F0EC",color:COLORS.ink }}>
          <Circle size={6} fill={COLORS.green} color={COLORS.green} /> Caisse 01
        </span>
      </header>

      {/* Main */}
      <main style={{ flex:1,padding:"24px 32px 32px",maxWidth:1280,margin:"0 auto",width:"100%" }}>

        {/* Toolbar */}
        <div style={{ display:"flex",alignItems:"flex-start",justifyContent:"space-between",gap:24,flexWrap:"wrap" }}>
          <div>
            <span style={{ fontSize:11,fontWeight:600,letterSpacing:"0.05em",color:COLORS.muted }}>
              HISTORIQUE DES VENTES &nbsp;·&nbsp; <span style={{ color:COLORS.green }}>SYNCHRONISÉ KDS &amp; COMPTOIR</span>
            </span>
            <div style={{ display:"flex",alignItems:"center",gap:10,marginTop:6 }}>
              <div style={{ width:30,height:30,borderRadius:8,background:"#F1F0EC",display:"flex",alignItems:"center",justifyContent:"center",color:COLORS.ink,flexShrink:0 }}>
                <Calendar size={16} />
              </div>
              <h1 style={{ margin:0,fontSize:21,fontWeight:800,letterSpacing:"0.01em",textTransform:"uppercase" }}>
                Liste des commandes du {formatDate(appliedRange.start)} au {formatDate(appliedRange.end)}
              </h1>
              <ChevronDown size={16} color={COLORS.muted} style={{ cursor:"pointer" }} onClick={() => setShowDatePicker(true)} />
            </div>
          </div>
          <div style={{ display:"flex",alignItems:"center",gap:10,flexShrink:0 }}>
            <div style={{ display:"flex",alignItems:"center",gap:8,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:10,padding:"10px 14px",minWidth:260,color:COLORS.muted }}>
              <Search size={15} />
              <input type="text" placeholder="Rechercher ticket #, client..." value={search}
                onChange={e => handleSearchChange(e.target.value)}
                style={{ border:"none",outline:"none",fontSize:13,fontFamily:"inherit",flex:1,background:"transparent",color:COLORS.ink }} />
            </div>
            <button onClick={() => setShowDatePicker(true)} style={{ display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:700,color:COLORS.ink,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:10,padding:"10px 16px",cursor:"pointer",fontFamily:"inherit",whiteSpace:"nowrap" }}>
              <Printer size={15} /> Imprimer Clôture
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",gap:20,marginTop:22,flexWrap:"wrap" }}>
          <div style={{ display:"flex",gap:8 }}>
            <Tab waiting onClick={() => handleTabChange("attente")}    active={activeTab === "attente"}>En attente</Tab>
            <Tab          onClick={() => handleTabChange("encaisser")} active={activeTab === "encaisser"}>À encaisser</Tab>
            <Tab active={activeTab === "terminées"} badge={totalOrders} onClick={() => handleTabChange("terminées")}>Terminées</Tab>
            <Tab          onClick={() => handleTabChange("repas")}     active={activeTab === "repas"}>Repas Empl.</Tab>
          </div>
          <span style={{ fontSize:12.5,color:COLORS.muted,whiteSpace:"nowrap" }}>
            Affichage : <b style={{ color:COLORS.ink,fontWeight:700 }}>{totalOrders} commande{totalOrders !== 1 ? "s" : ""}</b>
          </span>
        </div>

        {/* Table */}
        <div style={{ marginTop:20,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:14,overflow:"hidden" }}>
          <div style={{ overflowX:"auto" }}>
            <table style={{ width:"100%",borderCollapse:"collapse",minWidth:800 }}>
              <thead>
                <tr>
                  {["DATE","HEURE","NUMÉRO","MONTANT","CAISSE","CLIENT","MODE"].map(h => (
                    <th key={h} style={{ textAlign:"left",fontSize:10.5,fontWeight:700,letterSpacing:"0.06em",color:COLORS.muted,padding:"14px 20px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8" }}>{h}</th>
                  ))}
                  <th style={{ textAlign:"right",fontSize:10.5,fontWeight:700,letterSpacing:"0.06em",color:COLORS.muted,padding:"14px 20px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8" }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {loading && (
                  <tr><td colSpan={8} style={{ padding:40,textAlign:"center",color:COLORS.muted }}>Chargement des commandes...</td></tr>
                )}
                {!loading && orders.length === 0 && (
                  <tr><td colSpan={8} style={{ padding:40,textAlign:"center",color:COLORS.muted,fontSize:14 }}>Aucune commande trouvée</td></tr>
                )}
                {!loading && orders.map((o, i) => {
                  const date       = new Date(o.createdAt).toLocaleDateString("fr-FR");
                  const time       = new Date(o.createdAt).toLocaleTimeString("fr-FR");
                  const num        = `#${o.ticketNumber}`;
                  const amount     = fmtPrice(o.totalTTC || 0);
                  const caisse     = o.registerId?.name || "Caisse 01";
                  const client     = o.buzzerNumber
                    ? `Buzzer #${o.buzzerNumber}`
                    : (o.clientName || "Client Passant");
                  const clientMuted = !o.clientName && !o.buzzerNumber;
                  const mode       = o.orderType === "sur_place" ? "sur-place" : "emporter";
                  const isRefunded = o.status === "annulee";
                  const highlight  = i === 0 && o.status === "terminee";
                  const isNew      = highlight;
                  const rowObj     = { _id:o._id, num, date, time, amount, caisse, client, clientMuted, mode, highlight, isNew, isRefunded };

                  return (
                    <tr key={o._id} style={{
                      boxShadow: isRefunded
                        ? `inset 3px 0 0 ${COLORS.red}`
                        : highlight ? `inset 3px 0 0 ${COLORS.yellow}` : "none",
                      opacity: isRefunded ? 0.7 : 1,
                    }}
                      onMouseEnter={e => { if (!highlight && !isRefunded) Array.from(e.currentTarget.cells).forEach(c => c.style.background = COLORS.rowHover); }}
                      onMouseLeave={e => { if (!highlight && !isRefunded) Array.from(e.currentTarget.cells).forEach(c => c.style.background = "transparent"); }}>
                      <td style={cellStyle(i, orders.length)}>{date}</td>
                      <td style={cellStyle(i, orders.length)}>{time}</td>
                      <td style={cellStyle(i, orders.length)}>
                        <div style={{ display:"flex",alignItems:"center",gap:7,flexWrap:"wrap" }}>
                          <span style={{ display:"inline-flex",alignItems:"center",gap:6,background:isRefunded?"#FBEAE7":"#F1F0EC",borderRadius:6,padding:"3px 9px",fontSize:12.5,fontWeight:700,fontFamily:"monospace",textDecoration:isRefunded?"line-through":"none",color:isRefunded?COLORS.red:COLORS.ink }}>
                            {isNew && !isRefunded && <Circle size={6} fill={COLORS.green} color={COLORS.green} />}
                            {isRefunded && <Circle size={6} fill={COLORS.red} color={COLORS.red} />}
                            {num}
                          </span>
                          {isRefunded && (
                            <span style={{ fontSize:10,fontWeight:800,background:COLORS.redBg,color:COLORS.red,padding:"2px 8px",borderRadius:999,letterSpacing:"0.04em",textTransform:"uppercase" }}>
                              Annulée
                            </span>
                          )}
                        </div>
                      </td>
                      <td style={{ ...cellStyle(i, orders.length), fontWeight:700, textDecoration:isRefunded?"line-through":"none", color:isRefunded?COLORS.muted:COLORS.ink }}>{amount}</td>
                      <td style={cellStyle(i, orders.length)}>
                        <span style={{ background:"#F1F0EC",color:COLORS.muted,fontSize:12,fontWeight:600,padding:"3px 10px",borderRadius:6 }}>{caisse}</span>
                      </td>
                      <td style={{ ...cellStyle(i, orders.length), color:clientMuted?COLORS.muted:COLORS.ink, fontStyle:clientMuted?"italic":"normal" }}>{client}</td>
                      <td style={cellStyle(i, orders.length)}><ModePill mode={mode} /></td>
                      <td style={{ ...cellStyle(i, orders.length), textAlign:"right", whiteSpace:"nowrap" }}>
                        <button onClick={() => setSelectedOrder(rowObj)}
                          style={{ fontSize:12.5,fontWeight:700,padding:"8px 16px",borderRadius:8,border:`1px solid ${highlight&&!isRefunded?COLORS.brown:COLORS.border}`,background:highlight&&!isRefunded?COLORS.brown:COLORS.cardBg,color:highlight&&!isRefunded?"#F5F0E6":COLORS.ink,cursor:"pointer",fontFamily:"inherit" }}>
                          Détails
                        </button>
                        {highlight && !isRefunded && (
                          <button aria-label="Imprimer" style={{ width:32,height:32,borderRadius:8,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,color:COLORS.muted,display:"inline-flex",alignItems:"center",justifyContent:"center",cursor:"pointer",marginLeft:8 }}>
                            <Printer size={14} />
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"16px 20px",flexWrap:"wrap",gap:12 }}>
            <span style={{ fontSize:12.5,color:COLORS.muted }}>
              Affichage de {orders.length > 0 ? (page - 1) * 10 + 1 : 0} à {(page - 1) * 10 + orders.length} sur {totalOrders} commande{totalOrders !== 1 ? "s" : ""}
            </span>
            <div style={{ display:"flex",alignItems:"center",gap:6 }}>
              <PageBtn disabled={page <= 1} onClick={() => setPage(p => p - 1)}>Précédent</PageBtn>
              {Array.from({ length: Math.min(totalPages, 5) }, (_, idx) => idx + 1).map(n => (
                <PageBtn key={n} active={page === n} onClick={() => setPage(n)}>{n}</PageBtn>
              ))}
              {totalPages > 5 && page < totalPages && (
                <PageBtn onClick={() => setPage(totalPages)}>{totalPages}</PageBtn>
              )}
              <PageBtn disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>Suivant</PageBtn>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"16px 32px",borderTop:`1px solid ${COLORS.border}` }}>
        <span style={{ display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,color:COLORS.ink }}>
          <Circle size={6} fill={COLORS.green} color={COLORS.green} /> Connecté
        </span>
        <span style={{ fontSize:12,color:COLORS.muted }}>SprintKitchen OS v2.4.0-PROD</span>
      </footer>

      {showDatePicker && (
        <DateRangeModal
          onClose={() => setShowDatePicker(false)}
          onApply={(start, end) => handleRangeApply(start, end)}
        />
      )}

      {selectedOrder && (
        <OrderDetailDrawer
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
          onRefund={handleRefund}
        />
      )}
    </div>
  );
}
