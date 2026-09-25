import React, { useState, useEffect, useLayoutEffect, useRef, useCallback, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  Calendar,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Search,
  Printer,
  Check,
  CheckCircle2,
  MessageSquare,
  Clock,
  User,
  X,
  Undo2,
  UtensilsCrossed,
  WifiOff,
} from 'lucide-react';
import { orderService, paymentService } from '../services';

/* ── Figma / Caisse Exact Palette ───────────────────────────────────────────────── */
const COLORS = {
  brandDark: '#583926',
  brandDarkHover: '#452B1E',
  background: '#F5F4F0',
  surface: '#FFFFFF',
  ink: '#1C1917',
  stone700: '#44403C',
  stone600: '#57534E',
  stone500: '#78716C',
  stone400: '#A8A29E',
  stone200: '#E7E5E4',
  stone100: '#F5F5F4',
  stone50: '#FAFAF9',
  border: '#E5E7EB',
  borderDark: '#D1D5DB',
  gold: '#FACC15',
  goldLight: '#FEF08A',
  rangeFill: '#FDE9A0',
  selectedRowBg: '#FEF4A8',
  success: '#059669',
  successLight: '#D1FAE5',
  danger: '#EF4444',
  dangerLight: '#FEE2E2',
};

const FONT_TITLE = "'Bebas Neue', sans-serif";
const FONT_BODY = "'Open Sans', 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

const PAYMENT_LABELS = {
  especes: 'Espèces',
  carte_bancaire: 'Carte Bancaire',
  sans_contact: 'Sans Contact',
  ticket_restaurant: 'Ticket Restaurant',
  mixte: 'Paiement Mixte',
};

const TABS = [
  { status: 'en_attente', label: 'EN ATTENTE', countLabel: 'commandes en attente' },
  { status: 'a_encaisser', label: 'À ENCAISSER', countLabel: 'commandes à encaisser' },
  { status: 'terminee', label: 'TERMINÉES', countLabel: 'commandes terminées' },
  { status: 'repas_employe', label: 'REPAS EMPL.', countLabel: 'repas employés' },
];

const MONTHS_SHORT = [
  'JANV.', 'FÉVR.', 'MARS', 'AVR.', 'MAI', 'JUIN',
  'JUIL.', 'AOÛT', 'SEPT.', 'OCT.', 'NOV.', 'DÉC.',
];

function fmtPrice(n) {
  return (n || 0).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' DA';
}

function two(n) {
  return String(n).padStart(2, '0');
}

function fmtDate(d) {
  if (!d) return '';
  const date = new Date(d);
  return `${two(date.getDate())}/${two(date.getMonth() + 1)}/${date.getFullYear()}`;
}

function fmtTime(d) {
  if (!d) return '';
  const date = new Date(d);
  return `${two(date.getHours())}:${two(date.getMinutes())}:${two(date.getSeconds())}`;
}

function fmtLongDate(d) {
  if (!d) return '';
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

function getModeStyle(type) {
  switch (type) {
    case 'a_emporter':
    case 'emporter':
      return { label: 'À emporter', bg: '#DBEAFE', fg: '#1E40AF', dot: '#2563EB' };
    case 'livraison':
      return { label: 'Livraison', bg: '#CCFBF1', fg: '#115E59', dot: '#0D9488' };
    default:
      return { label: 'Sur place', bg: '#FFE4E6', fg: '#9F1239', dot: '#E11D48' };
  }
}

function getStatusStyle(status) {
  switch (status) {
    case 'terminee':
      return { label: 'Terminée', bg: COLORS.success, fg: '#FFFFFF' };
    case 'repas_employe':
      return { label: 'Repas employé', bg: COLORS.success, fg: '#FFFFFF' };
    case 'en_attente':
      return { label: 'En attente', bg: '#F59E0B', fg: '#FFFFFF' };
    case 'a_encaisser':
      return { label: 'À encaisser', bg: '#6B7280', fg: '#FFFFFF' };
    case 'annulee':
      return { label: 'Annulée', bg: COLORS.danger, fg: '#FFFFFF' };
    default:
      return { label: status, bg: '#6B7280', fg: '#FFFFFF' };
  }
}

/* ── Print Utilities ───────────────────────────────────────────────────────────── */
function printThermalReceipt({ order, detail, payment, kitchenOnly = false }) {
  const ord = detail || order;
  const dateStr = fmtDate(ord.createdAt) + ' ' + fmtTime(ord.createdAt);
  const mode = getModeStyle(ord.orderType);
  const paymentLabel = payment ? (PAYMENT_LABELS[payment.method] || payment.method) : 'Comptant';

  const itemsHtml = (ord.items || []).map((it) => {
    const custs = (it.customizations || []).flatMap((c) => (c.selectedOptions || []).map((o) => o.label)).join(', ');
    const sans = (it.removedIngredients || []).map((r) => `Sans ${r}`).join(', ');
    const subParts = [custs, sans, it.notes].filter(Boolean).join(' • ');

    if (kitchenOnly) {
      return `
        <div style="margin-bottom:8px;padding-bottom:6px;border-bottom:1px dashed #ccc">
          <div style="display:flex;justify-content:space-between;font-weight:bold;font-size:14px">
            <span>${it.quantity}× ${it.productName}</span>
          </div>
          ${subParts ? `<div style="font-size:11px;color:#333;margin-top:2px;padding-left:8px;border-left:2px solid #000">${subParts}</div>` : ''}
        </div>
      `;
    }

    return `
      <div style="margin-bottom:6px;padding-bottom:4px;border-bottom:1px dotted #ccc">
        <div style="display:flex;justify-content:space-between;font-size:12px">
          <span>${it.quantity}× ${it.productName}</span>
          <span style="font-weight:bold">${fmtPrice(it.lineTotal)}</span>
        </div>
        ${subParts ? `<div style="font-size:10px;color:#555;padding-left:8px;border-left:2px solid #999">${subParts}</div>` : ''}
      </div>
    `;
  }).join('');

  const notesHtml = ord.notes ? `
    <div style="background:#FEF3C7;border:1px solid #F59E0B;padding:8px 10px;border-radius:6px;margin:10px 0;">
      <div style="font-size:10px;font-weight:bold;color:#B45309;letter-spacing:0.5px;text-transform:uppercase">Note Cuisine / Commentaire</div>
      <div style="font-size:12px;font-weight:bold;color:#78350F;margin-top:2px">${ord.notes}</div>
    </div>
  ` : '';

  const html = kitchenOnly ? `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8"/>
        <title>Bon Cuisine - #${ord.ticketNumber}</title>
        <style>
          @page { size: 80mm auto; margin: 0; }
          body { font-family: monospace; width: 72mm; margin: 0 auto; padding: 12px 0; font-size: 12px; line-height: 1.3; }
          .center { text-align: center; }
          .bold { font-weight: bold; }
          hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
          h2 { font-size: 20px; margin: 0; }
        </style>
      </head>
      <body>
        <div class="center">
          <h2>BON DE CUISINE</h2>
          <div style="font-size:16px;font-weight:bold;margin:4px 0">COMMANDE #${ord.ticketNumber}</div>
          <div>${dateStr}</div>
          <div style="display:inline-block;padding:3px 10px;border:1px solid #000;border-radius:12px;font-weight:bold;margin-top:4px">${mode.label.toUpperCase()}</div>
        </div>
        ${notesHtml}
        <hr/>
        <div style="margin-top:8px">${itemsHtml}</div>
        <hr/>
        <div class="center" style="font-size:11px;margin-top:6px">
          SprintKitchen KDS • ${ord.registerId?.name || 'Caisse 01'}
        </div>
      </body>
    </html>
  ` : `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8"/>
        <title>Ticket de Caisse - #${ord.ticketNumber}</title>
        <style>
          @page { size: 80mm auto; margin: 0; }
          body { font-family: monospace; width: 72mm; margin: 0 auto; padding: 12px 0; font-size: 12px; line-height: 1.3; }
          .center { text-align: center; }
          .bold { font-weight: bold; }
          hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
          h1 { font-size: 22px; margin: 0; }
          .row { display: flex; justify-content: space-between; margin: 2px 0; }
        </style>
      </head>
      <body>
        <div class="center">
          <h1>SPRINTKITCHEN</h1>
          <div style="font-size:11px;color:#444">FAST FOOD GOURMET</div>
          <div style="font-size:16px;font-weight:bold;margin:6px 0">TICKET #${ord.ticketNumber}</div>
          <div>${dateStr}</div>
          <div style="font-size:11px;margin-top:2px">Mode : ${mode.label} • ${ord.registerId?.name || 'Caisse 01'}</div>
          ${ord.clientName ? `<div style="font-size:11px">Client : ${ord.clientName}</div>` : ''}
          ${ord.buzzerNumber ? `<div style="font-size:12px;font-weight:bold">Buzzer #${ord.buzzerNumber}</div>` : ''}
        </div>
        ${notesHtml}
        <hr/>
        ${itemsHtml}
        <hr/>
        <div class="row"><span>Sous-total HT</span><span>${fmtPrice(ord.subtotalHT)}</span></div>
        <div class="row"><span>TVA (10%)</span><span>${fmtPrice(ord.tvaAmount)}</span></div>
        <hr/>
        <div class="row" style="font-size:16px;font-weight:bold;margin:6px 0">
          <span>TOTAL PAYÉ</span>
          <span>${fmtPrice(ord.totalTTC)}</span>
        </div>
        <div class="center" style="font-size:10px;color:#555">TOUTES TAXES COMPRISES</div>
        <hr/>
        <div class="row"><span>Mode de règlement</span><span class="bold">${paymentLabel}</span></div>
        ${payment?.change ? `<div class="row"><span>Rendu monnaie</span><span>${fmtPrice(payment.change)}</span></div>` : ''}
        <hr/>
        <div class="center" style="margin-top:10px;font-size:11px">
          Merci de votre visite et à très bientôt !<br/>
          SprintKitchen OS v2.4.0
        </div>
      </body>
    </html>
  `;

  const w = window.open('', '_blank', 'width=380,height=600');
  if (!w) return;
  w.document.write(html);
  w.document.close();
  w.focus();
  setTimeout(() => {
    w.print();
    w.close();
  }, 350);
}

function printSessionCloture({ summary, range }) {
  const fromStr = fmtDate(range.start);
  const toStr = fmtDate(range.end);
  const nowStr = fmtDate(new Date()) + ' à ' + fmtTime(new Date());

  const counts = summary?.counts || { en_attente: 0, a_encaisser: 0, terminee: 0, repas_employe: 0 };
  const totalRev = summary?.totalTerminee || 0;

  const html = `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8"/>
        <title>Clôture de Caisse - Rapport</title>
        <style>
          @page { size: 80mm auto; margin: 0; }
          body { font-family: monospace; width: 72mm; margin: 0 auto; padding: 12px 0; font-size: 12px; line-height: 1.35; }
          .center { text-align: center; }
          .bold { font-weight: bold; }
          hr { border: none; border-top: 1px dashed #000; margin: 8px 0; }
          h2 { font-size: 18px; margin: 0; }
          .row { display: flex; justify-content: space-between; margin: 3px 0; }
        </style>
      </head>
      <body>
        <div class="center">
          <h2>SPRINTKITCHEN</h2>
          <div style="font-weight:bold;margin:4px 0">RAPPORT DE CLÔTURE DE SESSION</div>
          <div style="font-size:11px;color:#444">Période : du ${fromStr} au ${toStr}</div>
          <div style="font-size:10px;color:#666">Édité le ${nowStr}</div>
        </div>
        <hr/>
        <div class="bold" style="margin-bottom:6px">RÉPARTITION DES COMMANDES</div>
        <div class="row"><span>Commandes terminées :</span><span class="bold">${counts.terminee || 0}</span></div>
        <div class="row"><span>Commandes en attente :</span><span>${counts.en_attente || 0}</span></div>
        <div class="row"><span>Commandes à encaisser :</span><span>${counts.a_encaisser || 0}</span></div>
        <div class="row"><span>Repas employés :</span><span>${counts.repas_employe || 0}</span></div>
        <div class="row"><span>Commandes annulées :</span><span>${counts.annulee || 0}</span></div>
        <hr/>
        <div class="row" style="font-size:15px;font-weight:bold;margin:8px 0">
          <span>TOTAL SESSION (TTC) :</span>
          <span>${fmtPrice(totalRev)}</span>
        </div>
        <hr/>
        <div class="center" style="margin-top:12px;font-size:10px;color:#555">
          Document généré par SprintKitchen OS Admin
        </div>
      </body>
    </html>
  `;

  const w = window.open('', '_blank', 'width=380,height=600');
  if (!w) return;
  w.document.write(html);
  w.document.close();
  w.focus();
  setTimeout(() => {
    w.print();
    w.close();
  }, 350);
}

/* ── Order Details Panel (Slide-in Drawer) ───────────────────────────────────────── */
function OrderDetailsPanel({ order, onClose, onMarkTerminee, onRefund }) {
  const [detail, setDetail] = useState(null);
  const [payment, setPayment] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    Promise.all([
      orderService.getById(order._id),
      paymentService.getByOrder(order._id).catch(() => ({ data: { data: null } })),
    ])
      .then(([orderRes, payRes]) => {
        if (cancelled) return;
        setDetail(orderRes.data.data);
        const payData = payRes?.data?.data;
        setPayment(Array.isArray(payData) ? payData[0] : payData);
      })
      .catch((e) => {
        console.error(e);
        if (!cancelled) setDetail(order);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [order._id, order]);

  const ord = detail || order;
  const mode = getModeStyle(ord.orderType);
  const statusStyle = getStatusStyle(ord.status);
  const client = ord.buzzerNumber ? `Buzzer #${ord.buzzerNumber}` : ord.clientName || 'Client Passant';
  const tvaPercent = ord.subtotalHT > 0 ? ((ord.tvaAmount || 0) / ord.subtotalHT) * 100 : 10;
  const paymentLabel = payment ? PAYMENT_LABELS[payment.method] || payment.method : null;

  return (
    <>
      {/* Backdrop */}
      <div
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(28,25,23,0.35)',
          zIndex: 300,
          transition: 'opacity 0.2s ease',
        }}
      />

      {/* Drawer */}
      <div
        style={{
          position: 'fixed',
          top: 0,
          right: 0,
          width: 500,
          maxWidth: '100vw',
          height: '100vh',
          background: COLORS.background,
          zIndex: 301,
          display: 'flex',
          flexDirection: 'column',
          boxShadow: '-8px 0 40px rgba(0,0,0,0.18)',
          fontFamily: FONT_BODY,
          animation: 'slideInRight 0.25s cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        {/* Drawer Header */}
        <div
          style={{
            padding: '20px 24px 16px',
            borderBottom: `1px solid ${COLORS.border}`,
            background: COLORS.surface,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <span
                style={{
                  fontSize: 24,
                  fontWeight: 400,
                  color: COLORS.brandDark,
                  fontFamily: FONT_TITLE,
                  letterSpacing: '0.6px',
                }}
              >
                COMMANDE #{ord.ticketNumber}
              </span>
              <span
                style={{
                  fontSize: 11,
                  fontWeight: 700,
                  padding: '3px 10px',
                  borderRadius: 20,
                  background: statusStyle.bg,
                  color: statusStyle.fg,
                }}
              >
                {statusStyle.label}
              </span>
            </div>

            <button
              onClick={onClose}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
                padding: '6px 12px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: 700,
                color: COLORS.stone500,
                fontFamily: FONT_BODY,
              }}
            >
              <X size={16} /> Fermer
            </button>
          </div>
          <div style={{ fontSize: 12, color: COLORS.stone500, marginTop: 4 }}>
            Historique de vente • Transaction confirmée
          </div>
        </div>

        {/* Drawer Body */}
        <div style={{ flex: 1, padding: 20, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: COLORS.stone500 }}>Chargement des détails...</div>
          ) : (
            <>
              {/* Info Card */}
              <div
                style={{
                  background: COLORS.surface,
                  borderRadius: 12,
                  border: `1px solid ${COLORS.border}`,
                  padding: 16,
                }}
              >
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px 20px' }}>
                  <div>
                    <div
                      style={{
                        fontSize: 10,
                        fontWeight: 700,
                        letterSpacing: '0.4px',
                        color: COLORS.stone400,
                        textTransform: 'uppercase',
                        marginBottom: 6,
                      }}
                    >
                      DATE &amp; HEURE
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 700, color: COLORS.ink }}>
                      <Clock size={13} color={COLORS.stone400} />
                      {fmtDate(ord.createdAt)} à {fmtTime(ord.createdAt)}
                    </div>
                  </div>

                  <div>
                    <div
                      style={{
                        fontSize: 10,
                        fontWeight: 700,
                        letterSpacing: '0.4px',
                        color: COLORS.stone400,
                        textTransform: 'uppercase',
                        marginBottom: 6,
                      }}
                    >
                      CAISSE &amp; OPÉRATEUR
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 700, color: COLORS.ink }}>
                      <span
                        style={{
                          width: 7,
                          height: 7,
                          borderRadius: '50%',
                          background: COLORS.success,
                          display: 'inline-block',
                        }}
                      />
                      {ord.registerId?.name || 'Caisse 01'} (Admin)
                    </div>
                  </div>

                  <div>
                    <div
                      style={{
                        fontSize: 10,
                        fontWeight: 700,
                        letterSpacing: '0.4px',
                        color: COLORS.stone400,
                        textTransform: 'uppercase',
                        marginBottom: 6,
                      }}
                    >
                      CLIENT / LOCALISATION
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 700, color: COLORS.ink }}>
                      <User size={13} color={COLORS.stone400} />
                      {client}
                    </div>
                  </div>

                  <div>
                    <div
                      style={{
                        fontSize: 10,
                        fontWeight: 700,
                        letterSpacing: '0.4px',
                        color: COLORS.stone400,
                        textTransform: 'uppercase',
                        marginBottom: 6,
                      }}
                    >
                      MODE DE CONSOMMATION
                    </div>
                    <span
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        fontSize: 12,
                        fontWeight: 700,
                        padding: '5px 10px',
                        borderRadius: 20,
                        background: mode.bg,
                        color: mode.fg,
                      }}
                    >
                      <span style={{ width: 6, height: 6, borderRadius: '50%', background: mode.dot }} />
                      {mode.label}
                    </span>
                  </div>
                </div>

                <div
                  style={{
                    marginTop: 14,
                    paddingTop: 12,
                    borderTop: '1px solid #F3F4F6',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                  }}
                >
                  <span style={{ fontSize: 12, color: COLORS.stone400 }}>Canal de prise de commande :</span>
                  <span style={{ fontSize: 12, fontWeight: 700, color: '#374151' }}>Caisse Tactile Comptoir</span>
                </div>
              </div>

              {/* Kitchen Notes Banner */}
              {ord.notes && ord.notes.trim() !== '' && (
                <div
                  style={{
                    background: '#FEF3C7',
                    border: '1px solid #F59E0B',
                    borderRadius: 12,
                    padding: 14,
                    display: 'flex',
                    alignItems: 'flex-start',
                    gap: 10,
                  }}
                >
                  <MessageSquare size={20} color="#B45309" style={{ flexShrink: 0, marginTop: 1 }} />
                  <div>
                    <div
                      style={{
                        fontSize: 11,
                        fontWeight: 800,
                        letterSpacing: '0.5px',
                        color: '#B45309',
                        textTransform: 'uppercase',
                        marginBottom: 4,
                      }}
                    >
                      NOTE CUISINE / COMMENTAIRE
                    </div>
                    <div style={{ fontSize: 13, fontWeight: 600, color: '#78350F', lineHeight: 1.4 }}>
                      {ord.notes}
                    </div>
                  </div>
                </div>
              )}

              {/* Items Card */}
              <div
                style={{
                  background: COLORS.surface,
                  borderRadius: 16,
                  border: `1px solid ${COLORS.stone200}`,
                  padding: 16,
                  boxShadow: '0 4px 12px rgba(0,0,0,0.06)',
                }}
              >
                <div style={{ display: 'grid', gridTemplateColumns: '40px 1fr 100px', gap: 8, paddingBottom: 10 }}>
                  <span style={{ fontSize: 11, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.5px' }}>
                    QTÉ
                  </span>
                  <span style={{ fontSize: 11, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.5px' }}>
                    ARTICLE &amp; SUPPLÉMENTS
                  </span>
                  <span style={{ fontSize: 11, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.5px', textAlign: 'right' }}>
                    PRIX
                  </span>
                </div>
                <div style={{ height: 1, background: COLORS.border, marginBottom: 10 }} />

                {(ord.items || []).map((item, i) => (
                  <div key={i} style={{ marginBottom: i < ord.items.length - 1 ? 12 : 0 }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '40px 1fr 100px', gap: 8, alignItems: 'flex-start' }}>
                      <div
                        style={{
                          background: COLORS.stone100,
                          borderRadius: 6,
                          padding: '4px 6px',
                          textAlign: 'center',
                          fontSize: 12,
                          fontWeight: 800,
                          color: COLORS.ink,
                        }}
                      >
                        {item.quantity}×
                      </div>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.ink }}>
                          {item.productName}
                        </div>
                        {((item.customizations && item.customizations.length > 0) ||
                          (item.removedIngredients && item.removedIngredients.length > 0) ||
                          item.notes) && (
                          <div
                            style={{
                              marginTop: 4,
                              paddingLeft: 10,
                              borderLeft: `3px solid ${COLORS.gold}`,
                              display: 'flex',
                              flexDirection: 'column',
                              gap: 2,
                            }}
                          >
                            {(item.customizations || []).map((c, ci) => (
                              <div key={ci} style={{ fontSize: 12, color: COLORS.stone500 }}>
                                • {(c.selectedOptions || []).map((o) => o.label).join(', ')}
                              </div>
                            ))}
                            {(item.removedIngredients || []).map((r, ri) => (
                              <div key={ri} style={{ fontSize: 12, fontWeight: 600, color: '#B45309' }}>
                                • Sans {r}
                              </div>
                            ))}
                            {item.notes && (
                              <div style={{ fontSize: 12, fontStyle: 'italic', color: COLORS.stone500 }}>
                                {item.notes}
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                      <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.ink, textAlign: 'right' }}>
                        {fmtPrice(item.lineTotal)}
                      </div>
                    </div>
                    {i < ord.items.length - 1 && (
                      <div style={{ height: 1, background: '#F3F4F6', margin: '10px 0' }} />
                    )}
                  </div>
                ))}

                <div style={{ height: 1, background: COLORS.border, margin: '14px 0' }} />

                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                  <span style={{ fontSize: 13, fontWeight: 500, color: COLORS.ink }}>Sous-total HT</span>
                  <span style={{ fontSize: 13, fontWeight: 500, color: COLORS.ink }}>{fmtPrice(ord.subtotalHT)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
                  <span style={{ fontSize: 13, fontWeight: 500, color: COLORS.ink }}>
                    TVA ({tvaPercent.toFixed(1)}%)
                  </span>
                  <span style={{ fontSize: 13, fontWeight: 500, color: COLORS.ink }}>{fmtPrice(ord.tvaAmount)}</span>
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'baseline',
                    paddingTop: 10,
                    borderTop: `1px solid ${COLORS.stone200}`,
                  }}
                >
                  <div>
                    <span style={{ fontSize: 20, fontWeight: 800, color: COLORS.brandDark }}>TOTAL PAYÉ</span>
                    <div style={{ fontSize: 10, fontWeight: 700, color: COLORS.stone400, letterSpacing: '0.4px', marginTop: 2 }}>
                      TOUTES TAXES COMPRISES
                    </div>
                  </div>
                  <span style={{ fontSize: 20, fontWeight: 800, color: COLORS.brandDark }}>
                    {fmtPrice(ord.totalTTC)}
                  </span>
                </div>
              </div>

              {/* Payment Card */}
              {payment ? (
                <div
                  style={{
                    background: '#F0FAF4',
                    border: '1px solid #C3EDD4',
                    borderRadius: 12,
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                  }}
                >
                  <CheckCircle2 size={20} color={COLORS.success} fill="#D1FAE5" style={{ flexShrink: 0 }} />
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 700, color: '#166534' }}>
                      Payé par {paymentLabel}
                    </div>
                    <div style={{ fontSize: 12, color: COLORS.stone500, marginTop: 1 }}>
                      {payment.method === 'especes'
                        ? `Rendu : ${fmtPrice(payment.change || 0)}`
                        : 'Paiement électronique'}
                      {payment._id && ` • Réf #${payment._id.slice(-6).toUpperCase()}`}
                    </div>
                  </div>
                </div>
              ) : (
                <div
                  style={{
                    background: '#F0FAF4',
                    border: '1px solid #C3EDD4',
                    borderRadius: 12,
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                  }}
                >
                  <CheckCircle2 size={20} color={COLORS.success} fill="#D1FAE5" style={{ flexShrink: 0 }} />
                  <div style={{ fontSize: 13, fontWeight: 700, color: '#166534' }}>Paiement enregistré</div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Drawer Footer */}
        <div
          style={{
            padding: 16,
            borderTop: `1px solid ${COLORS.border}`,
            background: COLORS.surface,
            display: 'flex',
            flexDirection: 'column',
            gap: 10,
          }}
        >
          {ord.status === 'en_attente' && (
            <button
              onClick={() => onMarkTerminee(ord)}
              style={{
                width: '100%',
                height: 52,
                borderRadius: 12,
                border: 'none',
                background: COLORS.success,
                color: '#FFFFFF',
                fontSize: 13,
                fontWeight: 800,
                letterSpacing: '0.5px',
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
              }}
            >
              <CheckCircle2 size={20} /> MARQUER COMME TERMINÉE (PRÊTE)
            </button>
          )}

          <button
            onClick={() => printThermalReceipt({ order: ord, detail, payment, kitchenOnly: false })}
            style={{
              width: '100%',
              height: 54,
              borderRadius: 12,
              border: `1px solid ${COLORS.goldLight}`,
              background: COLORS.gold,
              color: COLORS.brandDark,
              fontSize: 13,
              fontWeight: 800,
              cursor: 'pointer',
              fontFamily: FONT_BODY,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
            }}
          >
            <Printer size={18} /> IMPRIMER LE TICKET DE CAISSE
          </button>

          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={() => printThermalReceipt({ order: ord, detail, payment, kitchenOnly: true })}
              style={{
                flex: 1,
                padding: '12px 14px',
                borderRadius: 10,
                border: `1px solid ${COLORS.borderDark}`,
                background: COLORS.surface,
                color: '#374151',
                fontSize: 12,
                fontWeight: 700,
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 6,
              }}
            >
              <UtensilsCrossed size={16} /> Réimprimer Bon Cuisine
            </button>

            <button
              onClick={() => onRefund(ord._id)}
              style={{
                flex: 1,
                padding: '12px 14px',
                borderRadius: 10,
                border: `1px solid rgba(239, 68, 68, 0.4)`,
                background: '#FEF2F2',
                color: COLORS.danger,
                fontSize: 12,
                fontWeight: 700,
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 6,
              }}
            >
              <Undo2 size={16} /> Remboursement / Annulation
            </button>
          </div>
        </div>
      </div>
    </>
  );
}

/* ── Date Range Popover (Exact 1:1 replica of Caisse DateRangePopover) ───────────── */
const POPOVER_COLORS = {
  ink: '#1C1917',
  stone600: '#57534E',
  stone500: '#78716C',
  stone400: '#A8A29E',
  border: '#E7E5E4',
  brandDark: '#452B1E',
  gold: '#FACC15',
  rangeFill: '#FDE9A0',
};

const POPOVER_MONTHS = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const POPOVER_MONTHS_SHORT = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

const POPOVER_WEEKDAYS = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

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
  const radius = haloSize / 2; // 19

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
            position: 'absolute',
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
            position: 'absolute',
            top: 0,
            bottom: 0,
            left: '50%',
            right: 0,
            background: col === 6 || isLastInMonth ? 'transparent' : POPOVER_COLORS.rangeFill,
          }}
        />
      );
    } else if (isEnd) {
      strip = (
        <div
          style={{
            position: 'absolute',
            top: 0,
            bottom: 0,
            left: 0,
            right: '50%',
            background: col === 0 || isFirstInMonth ? 'transparent' : POPOVER_COLORS.rangeFill,
          }}
        />
      );
    }
  }

  const halo =
    !isSingleDay && isEndpoint ? (
      <div
        style={{
          position: 'absolute',
          width: haloSize,
          height: haloSize,
          borderRadius: '50%',
          background: POPOVER_COLORS.rangeFill,
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
        }}
      />
    ) : null;

  let dayContentStyle = {
    width: brownSize,
    height: brownSize,
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
    zIndex: 2,
    fontSize: 13.5,
    fontFamily: FONT_BODY,
  };

  if (isEndpoint) {
    dayContentStyle = {
      ...dayContentStyle,
      background: POPOVER_COLORS.brandDark,
      color: '#FFFFFF',
      fontWeight: 700,
    };
  } else if (isToday && !inRange) {
    dayContentStyle = {
      ...dayContentStyle,
      border: `1.4px solid ${POPOVER_COLORS.brandDark}`,
      color: POPOVER_COLORS.ink,
      fontWeight: 500,
      background: 'transparent',
    };
  } else if (inRange) {
    dayContentStyle = {
      ...dayContentStyle,
      color: POPOVER_COLORS.brandDark,
      fontWeight: 700,
      background: 'transparent',
    };
  } else {
    dayContentStyle = {
      ...dayContentStyle,
      color: disabled ? POPOVER_COLORS.stone400 : POPOVER_COLORS.ink,
      fontWeight: 500,
      background: 'transparent',
    };
  }

  return (
    <div
      onClick={disabled ? undefined : () => onDayTap(day)}
      style={{
        flex: 1,
        height: cellH,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: disabled ? 'default' : 'pointer',
        userSelect: 'none',
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
  const leading = (firstDay.getDay() + 6) % 7; // Monday = 0

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
      {/* Weekday headers */}
      <div style={{ display: 'flex', marginBottom: 8 }}>
        {POPOVER_WEEKDAYS.map((h, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              textAlign: 'center',
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

      {/* Day rows */}
      {rows.map((row, rIdx) => (
        <div
          key={rIdx}
          style={{
            display: 'flex',
            margin: '2px 0',
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
    window.addEventListener('resize', updatePosition);
    window.addEventListener('scroll', updatePosition, true);
    return () => {
      window.removeEventListener('resize', updatePosition);
      window.removeEventListener('scroll', updatePosition, true);
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
        label: 'Hier',
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
        label: '7 derniers jours',
        range: (t) => {
          const s = new Date(t);
          s.setDate(s.getDate() - 6);
          return { start: s, end: t };
        },
        valueLabel: null,
      },
      {
        label: 'Ce mois-ci',
        range: (t) => ({
          start: new Date(t.getFullYear(), t.getMonth(), 1),
          end: t,
        }),
        valueLabel: POPOVER_MONTHS[today.getMonth()],
      },
      {
        label: 'Mois dernier',
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
        valueLabel: 'Toutes dates',
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
      {/* Invisible dismiss barrier */}
      <div
        onClick={onClose}
        style={{
          position: 'fixed',
          inset: 0,
          zIndex: 499,
          background: 'transparent',
        }}
      />

      {/* Popover Card */}
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          position: 'fixed',
          top: `${popoverPos.top}px`,
          left: `${popoverPos.left}px`,
          zIndex: 500,
          width: 'min(860px, calc(100vw - 32px))',
          maxHeight: 'calc(100vh - 32px)',
          overflowY: 'auto',
          background: '#FFFFFF',
          borderRadius: 16,
          border: `1px solid ${POPOVER_COLORS.border}`,
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
          fontFamily: FONT_BODY,
        }}
      >
        {/* Header */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            padding: '20px 18px 20px 26px',
          }}
        >
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 8,
              background: POPOVER_COLORS.brandDark,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
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
                letterSpacing: '0.3px',
                color: POPOVER_COLORS.ink,
              }}
            >
              SÉLECTIONNER UNE PÉRIODE DE VENTE
            </div>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: 12.5,
                color: POPOVER_COLORS.stone500,
                marginTop: 3,
              }}
            >
              Filtrer l'historique des encaissements, tickets et statistiques
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            style={{
              padding: 6,
              borderRadius: 8,
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: POPOVER_COLORS.stone500,
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: POPOVER_COLORS.border }} />

        {/* Body */}
        <div
          style={{
            padding: '22px 26px',
            display: 'flex',
            alignItems: 'flex-start',
          }}
        >
          {/* Shortcuts column */}
          <div style={{ width: 220, flexShrink: 0 }}>
            <div
              style={{
                fontFamily: FONT_BODY,
                fontSize: 11,
                fontWeight: 700,
                letterSpacing: '0.6px',
                color: POPOVER_COLORS.stone500,
                textTransform: 'uppercase',
                marginBottom: 12,
              }}
            >
              RACCOURCIS RAPIDES
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {shortcuts.map((s, idx) => {
                const active = matchesShortcut(s);
                return (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => applyShortcut(s)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '10px 14px',
                      borderRadius: 10,
                      background: active ? POPOVER_COLORS.brandDark : 'transparent',
                      border: 'none',
                      cursor: 'pointer',
                      width: '100%',
                      textAlign: 'left',
                      fontFamily: FONT_BODY,
                    }}
                  >
                    {active && (
                      <div
                        style={{
                          width: 6,
                          height: 6,
                          borderRadius: '50%',
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
                        color: active ? '#FFFFFF' : POPOVER_COLORS.ink,
                      }}
                    >
                      {s.label}
                    </span>
                    {active ? (
                      <span
                        style={{
                          padding: '3px 8px',
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

              {/* Personnalisé row */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  padding: '10px 14px',
                  borderRadius: 10,
                  background: isCustomActive ? POPOVER_COLORS.brandDark : 'transparent',
                  fontFamily: FONT_BODY,
                }}
              >
                {isCustomActive && (
                  <div
                    style={{
                      width: 6,
                      height: 6,
                      borderRadius: '50%',
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
                    color: isCustomActive ? '#FFFFFF' : POPOVER_COLORS.ink,
                  }}
                >
                  Personnalisé
                </span>
                <ChevronRight
                  size={18}
                  color={isCustomActive ? '#FFFFFF' : POPOVER_COLORS.stone400}
                />
              </div>
            </div>
          </div>

          <div style={{ width: 32, flexShrink: 0 }} />

          {/* Calendars column */}
          <div style={{ flex: 1, minWidth: 0 }}>
            {/* Months Header Navigation */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                marginBottom: 14,
              }}
            >
              <button
                type="button"
                onClick={goPrevMonth}
                style={{
                  padding: 4,
                  borderRadius: 6,
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: POPOVER_COLORS.stone600,
                }}
              >
                <ChevronLeft size={20} />
              </button>
              <div
                style={{
                  flex: 1,
                  textAlign: 'center',
                  fontFamily: FONT_BODY,
                  fontSize: 13.5,
                  fontWeight: 800,
                  letterSpacing: '0.4px',
                  color: POPOVER_COLORS.ink,
                  textTransform: 'uppercase',
                }}
              >
                {POPOVER_MONTHS[leftMonth.getMonth()]} {leftMonth.getFullYear()}
              </div>
              <div
                style={{
                  flex: 1,
                  textAlign: 'center',
                  fontFamily: FONT_BODY,
                  fontSize: 13.5,
                  fontWeight: 800,
                  letterSpacing: '0.4px',
                  color: POPOVER_COLORS.ink,
                  textTransform: 'uppercase',
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
                  background: 'none',
                  border: 'none',
                  cursor: canGoNext ? 'pointer' : 'default',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: canGoNext ? POPOVER_COLORS.stone600 : POPOVER_COLORS.border,
                }}
              >
                <ChevronRight size={20} />
              </button>
            </div>

            {/* Side-by-side Grids */}
            <div style={{ display: 'flex', gap: 28, alignItems: 'flex-start' }}>
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

        {/* Divider */}
        <div style={{ height: 1, background: POPOVER_COLORS.border }} />

        {/* Footer */}
        <div
          style={{
            padding: '16px 26px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: 12,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <span
              style={{
                fontSize: 13,
                fontWeight: 500,
                color: POPOVER_COLORS.stone600,
                fontFamily: FONT_BODY,
              }}
            >
              Période sélectionnée :{' '}
            </span>
            <div
              style={{
                marginLeft: 6,
                padding: '8px 14px',
                background: '#F3F4F6',
                borderRadius: 8,
                border: `1px solid ${POPOVER_COLORS.border}`,
                display: 'inline-flex',
                alignItems: 'center',
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
                  : 'Choisissez une période'}
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
                  {isAllHistory ? '(Toutes dates)' : `(${days} jour${days > 1 ? 's' : ''})`}
                </span>
              )}
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '10px 16px',
                background: 'transparent',
                border: 'none',
                borderRadius: 8,
                color: POPOVER_COLORS.stone600,
                fontSize: 13.5,
                fontWeight: 600,
                cursor: 'pointer',
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
                padding: '12px 18px',
                background: POPOVER_COLORS.gold,
                color: POPOVER_COLORS.ink,
                border: 'none',
                borderRadius: 10,
                fontSize: 13.5,
                fontWeight: 800,
                cursor: hasRange ? 'pointer' : 'not-allowed',
                opacity: hasRange ? 1 : 0.5,
                display: 'inline-flex',
                alignItems: 'center',
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

/* ── Main Page Component ─────────────────────────────────────────────────────────── */
export default function HistoriquePage() {
  const navigate = useNavigate();

  // State
  const [activeTab, setActiveTab] = useState('en_attente');
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [showDatePicker, setShowDatePicker] = useState(false);
  const calendarTriggerRef = useRef(null);

  // Date Range (default: Today)
  const [range, setRange] = useState(() => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    return { start: today, end: today };
  });

  const [orders, setOrders] = useState([]);
  const [totalOrders, setTotalOrders] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Selected row in table (yellow highlight) & Drawer order
  const [selectedId, setSelectedId] = useState(null);
  const [drawerOrder, setDrawerOrder] = useState(null);

  // Search debounce
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(1);
    }, 400);
    return () => clearTimeout(handler);
  }, [search]);

  // Load summary
  const loadSummary = useCallback(async () => {
    try {
      const fromIso = range.start.getFullYear() <= 2020 ? undefined : range.start.toISOString();
      const toIso = new Date(range.end.getFullYear(), range.end.getMonth(), range.end.getDate(), 23, 59, 59, 999).toISOString();
      const res = await orderService.getSummary({ from: fromIso, to: toIso });
      setSummary(res.data.data);
    } catch (err) {
      console.error(err);
      setSummary(null);
    }
  }, [range]);

  // Load orders
  const loadOrders = useCallback(async (keepData = false) => {
    setLoading(true);
    setError(null);
    if (!keepData) setOrders([]);

    try {
      const fromIso = range.start.getFullYear() <= 2020 ? undefined : range.start.toISOString();
      const toIso = new Date(range.end.getFullYear(), range.end.getMonth(), range.end.getDate(), 23, 59, 59, 999).toISOString();

      const res = await orderService.getAll({
        status: activeTab,
        from: fromIso,
        to: toIso,
        search: debouncedSearch || undefined,
        page,
        limit: 9,
      });

      const data = res.data;
      const fetchedOrders = data.data || [];
      setOrders(fetchedOrders);
      setTotalOrders(data.total || 0);
      setTotalPages(data.totalPages || 1);

      // Default select first item if none selected or not in page
      if (fetchedOrders.length > 0) {
        setSelectedId((prev) => (fetchedOrders.some((o) => o._id === prev) ? prev : fetchedOrders[0]._id));
      } else {
        setSelectedId(null);
      }
    } catch (err) {
      setError(err?.message || 'Erreur lors du chargement des commandes');
    } finally {
      setLoading(false);
    }
  }, [activeTab, range, debouncedSearch, page]);

  useEffect(() => {
    loadSummary();
  }, [loadSummary]);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  const handleTabChange = (status) => {
    if (status === activeTab) return;
    setActiveTab(status);
    setPage(1);
  };

  const handleApplyRange = (start, end) => {
    setRange({ start, end });
    setPage(1);
  };

  const handleMarkTerminee = async (order) => {
    try {
      await orderService.updateStatus(order._id, 'terminee');
      loadSummary();
      loadOrders(true);
      if (drawerOrder?._id === order._id) {
        setDrawerOrder(null);
      }
    } catch (e) {
      alert('Erreur : ' + (e?.response?.data?.message || e.message));
    }
  };

  const handleRefund = async (orderId) => {
    if (!window.confirm('Voulez-vous vraiment rembourser ou annuler cette commande ?')) return;
    try {
      await orderService.cancel(orderId, 'Remboursement demandé');
      loadSummary();
      loadOrders(true);
      if (drawerOrder?._id === orderId) {
        setDrawerOrder(null);
      }
    } catch (e) {
      alert('Erreur : ' + (e?.response?.data?.message || e.message));
    }
  };

  // Header Title
  const headerDateTitle = useMemo(() => {
    if (range.start.getFullYear() <= 2020) {
      return 'LISTE DE TOUTES LES COMMANDES';
    }
    return `LISTE DES COMMANDES DU ${fmtLongDate(range.start)} AU ${fmtLongDate(range.end)}`;
  }, [range]);

  const currentTabObj = TABS.find((t) => t.status === activeTab) || TABS[0];
  const firstShown = totalOrders > 0 ? (page - 1) * 9 + 1 : 0;
  const lastShown = Math.min(firstShown + orders.length - 1, totalOrders);

  return (
    <div
      style={{
        minHeight: '100vh',
        background: COLORS.background,
        fontFamily: FONT_BODY,
        color: COLORS.ink,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* ── Top Header Bar (Exact Caisse) ── */}
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 16px',
          background: COLORS.surface,
          borderBottom: `1px solid ${COLORS.border}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <button
            onClick={() => navigate('/')}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              padding: '8px 12px',
              borderRadius: 8,
              border: `1px solid ${COLORS.borderDark}`,
              background: '#F9FAFB',
              color: '#374151',
              fontWeight: 700,
              fontSize: 12,
              cursor: 'pointer',
              fontFamily: FONT_BODY,
            }}
          >
            <ArrowLeft size={14} /> Retour à l'accueil
          </button>

          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              background: COLORS.brandDark,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <UtensilsCrossed size={17} color={COLORS.gold} />
          </div>

          <span
            style={{
              fontFamily: FONT_TITLE,
              fontSize: 22,
              letterSpacing: '1.2px',
              color: '#111827',
              lineHeight: 1,
            }}
          >
            SPRINTKITCHEN
          </span>
        </div>

        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 8,
            padding: '6px 12px',
            borderRadius: 20,
            background: '#F9FAFB',
            border: `1px solid ${COLORS.border}`,
            fontSize: 12,
            fontWeight: 600,
            color: '#1F2937',
          }}
        >
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#10B981' }} />
          Poste Admin (Caisse 01)
        </div>
      </header>

      {/* ── Top Section ── */}
      <section
        style={{
          width: '100%',
          padding: '24px 32px 0',
          background: COLORS.surface,
          borderBottom: `1px solid ${COLORS.border}`,
        }}
      >
        {/* Title row + Search & Print */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 16,
            flexWrap: 'wrap',
          }}
        >
          {/* Title block */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11, fontWeight: 600, letterSpacing: '0.6px', color: '#6B7280' }}>
              <span>HISTORIQUE DES VENTES</span>
              <span>•</span>
              <span style={{ color: COLORS.success, fontWeight: 700 }}>SYNCHRONISÉ KDS &amp; COMPTOIR</span>
            </div>

            <div
              ref={calendarTriggerRef}
              onClick={() => setShowDatePicker((prev) => !prev)}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 12,
                marginTop: 6,
                cursor: 'pointer',
              }}
            >
              <div
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: 8,
                  background: '#F9FAFB',
                  border: `1px solid ${COLORS.border}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#374151',
                  flexShrink: 0,
                }}
              >
                <Calendar size={16} />
              </div>

              <h1
                style={{
                  margin: 0,
                  fontFamily: FONT_TITLE,
                  fontSize: 30,
                  fontWeight: 400,
                  letterSpacing: '0.5px',
                  color: '#111827',
                  lineHeight: 1.1,
                }}
              >
                {headerDateTitle}
              </h1>

              <ChevronDown size={22} color="#6B7280" />
            </div>
          </div>

          {/* Search & Print Clôture */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
            <div
              style={{
                width: 300,
                height: 44,
                borderRadius: 10,
                border: `1px solid ${COLORS.borderDark}`,
                background: '#F9FAFB',
                display: 'flex',
                alignItems: 'center',
                padding: '0 12px',
                gap: 8,
              }}
            >
              <Search size={18} color="#9CA3AF" />
              <input
                type="text"
                placeholder="Rechercher ticket #, client..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{
                  border: 'none',
                  outline: 'none',
                  background: 'transparent',
                  fontFamily: FONT_BODY,
                  fontSize: 13,
                  width: '100%',
                  color: COLORS.ink,
                }}
              />
            </div>

            <button
              onClick={() => printSessionCloture({ summary, range })}
              style={{
                height: 44,
                padding: '0 16px',
                borderRadius: 10,
                border: `1px solid ${COLORS.borderDark}`,
                background: COLORS.surface,
                color: '#1F2937',
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <Printer size={18} /> Imprimer Clôture
            </button>
          </div>
        </div>

        {/* Divider */}
        <div style={{ height: 1, background: '#F3F4F6', marginTop: 16 }} />

        {/* Tabs & Stats */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '16px 0',
            gap: 16,
            flexWrap: 'wrap',
          }}
        >
          {/* Tab Pills */}
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            {TABS.map((tab) => {
              const isSelected = tab.status === activeTab;
              const count = summary?.counts ? summary.counts[tab.status] || 0 : 0;

              return (
                <button
                  key={tab.status}
                  onClick={() => handleTabChange(tab.status)}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    padding: '11px 20px',
                    borderRadius: 24,
                    background: isSelected ? COLORS.brandDark : '#F3F2F0',
                    border: isSelected ? '1.5px solid #D6D3D1' : '1.5px solid #E2E0DC',
                    color: isSelected ? '#FFFFFF' : COLORS.stone600,
                    fontSize: 12,
                    fontWeight: 700,
                    letterSpacing: '0.6px',
                    cursor: 'pointer',
                    fontFamily: FONT_BODY,
                    textTransform: 'uppercase',
                    gap: 8,
                  }}
                >
                  <span>{tab.label}</span>
                  {count > 0 ? (
                    <span
                      style={{
                        padding: '2px 8px',
                        borderRadius: 10,
                        background: COLORS.gold,
                        color: COLORS.ink,
                        fontSize: 11,
                        fontWeight: 700,
                        lineHeight: '16px',
                      }}
                    >
                      {count}
                    </span>
                  ) : tab.status === 'en_attente' ? (
                    <span
                      style={{
                        width: 8,
                        height: 8,
                        borderRadius: '50%',
                        background: '#A8A29E',
                        display: 'inline-block',
                      }}
                    />
                  ) : null}
                </button>
              );
            })}
          </div>

          {/* Stats */}
          <div style={{ display: 'flex', alignItems: 'center', fontSize: 13, flexWrap: 'wrap' }}>
            <span style={{ color: '#374151', fontWeight: 600 }}>Affichage :&nbsp;</span>
            <span style={{ color: '#111827', fontWeight: 800 }}>
              {totalOrders} {currentTabObj.countLabel}
            </span>

            {summary && (
              <>
                <div style={{ width: 1.5, height: 20, background: '#6B7280', margin: '0 14px' }} />
                <span style={{ color: '#111827', fontWeight: 800 }}>
                  Total session : {fmtPrice(summary.totalTerminee)}
                </span>
              </>
            )}
          </div>
        </div>
      </section>

      {/* ── Main Table Card ── */}
      <main style={{ flex: 1, padding: '24px 32px' }}>
        <div
          style={{
            background: COLORS.surface,
            borderRadius: 16,
            border: `1px solid ${COLORS.stone200}`,
            boxShadow: '0 10px 24px -2px rgba(0,0,0,0.08), 0 1px 4px 0 rgba(0,0,0,0.06)',
            overflow: 'hidden',
          }}
        >
          {loading && (
            <div
              style={{
                height: 3,
                width: '100%',
                background: `linear-gradient(90deg, ${COLORS.brandDark}, ${COLORS.gold}, ${COLORS.brandDark})`,
                backgroundSize: '200% 100%',
              }}
            />
          )}

          {error ? (
            <div style={{ padding: '60px 20px', textAlign: 'center' }}>
              <WifiOff size={40} color={COLORS.stone400} />
              <div style={{ marginTop: 12, color: COLORS.stone500, fontSize: 14 }}>
                Impossible de charger les commandes.<br />
                {error}
              </div>
              <button
                onClick={() => {
                  loadSummary();
                  loadOrders();
                }}
                style={{
                  marginTop: 16,
                  padding: '8px 18px',
                  borderRadius: 8,
                  border: 'none',
                  background: COLORS.brandDark,
                  color: '#FFFFFF',
                  fontWeight: 700,
                  fontSize: 13,
                  cursor: 'pointer',
                  fontFamily: FONT_BODY,
                }}
              >
                Réessayer
              </button>
            </div>
          ) : orders.length === 0 && !loading ? (
            <div style={{ padding: '70px 20px', textAlign: 'center', color: COLORS.stone500, fontSize: 14 }}>
              Aucune commande pour cette période.
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 980 }}>
                <thead>
                  <tr
                    style={{
                      height: 44,
                      background: COLORS.stone50,
                      borderBottom: `1px solid ${COLORS.stone200}`,
                    }}
                  >
                    <th style={{ padding: '0 20px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>DATE</th>
                    <th style={{ padding: '0 16px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>HEURE</th>
                    <th style={{ padding: '0 16px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>NUMÉRO</th>
                    <th style={{ padding: '0 24px', textAlign: 'right', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>MONTANT</th>
                    <th style={{ padding: '0 16px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>CAISSE</th>
                    <th style={{ padding: '0 20px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>CLIENT</th>
                    <th style={{ padding: '0 16px', textAlign: 'left', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>MODE</th>
                    <th style={{ padding: '0 20px', textAlign: 'center', fontSize: 12, fontWeight: 700, color: COLORS.stone600, letterSpacing: '0.6px' }}>ACTIONS</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((o, index) => {
                    const isSelected = o._id === selectedId;
                    const isNewest = page === 1 && index === 0;
                    const mode = getModeStyle(o.orderType);
                    const client = o.buzzerNumber ? `Buzzer #${o.buzzerNumber}` : o.clientName;
                    const isRowOdd = index % 2 === 1;

                    const rowBg = isSelected ? COLORS.selectedRowBg : isRowOdd ? COLORS.surface : COLORS.stone50;

                    return (
                      <tr
                        key={o._id}
                        onClick={() => setSelectedId(o._id)}
                        style={{
                          height: 57,
                          background: rowBg,
                          borderLeft: isSelected ? `3px solid ${COLORS.gold}` : '3px solid transparent',
                          borderBottom: '1px solid #F5F5F4',
                          cursor: 'pointer',
                          transition: 'background 0.15s ease',
                        }}
                      >
                        {/* DATE */}
                        <td style={{ padding: '0 20px', fontSize: 14, fontWeight: 500, color: COLORS.ink }}>
                          {fmtDate(o.createdAt)}
                        </td>

                        {/* HEURE */}
                        <td style={{ padding: '0 16px', fontSize: 14, fontWeight: 400, color: COLORS.stone600 }}>
                          {fmtTime(o.createdAt)}
                        </td>

                        {/* NUMÉRO */}
                        <td style={{ padding: '0 16px' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                            <span
                              style={{
                                background: COLORS.stone100,
                                borderRadius: 4,
                                border: `1px solid ${COLORS.stone200}`,
                                padding: '5px 8px',
                                fontSize: 12,
                                fontWeight: 700,
                                color: COLORS.brandDark,
                                letterSpacing: '0.6px',
                              }}
                            >
                              #{o.ticketNumber}
                            </span>
                            {isNewest && (
                              <span
                                style={{
                                  width: 7,
                                  height: 7,
                                  borderRadius: '50%',
                                  background: '#10B981',
                                  display: 'inline-block',
                                }}
                              />
                            )}
                          </div>
                        </td>

                        {/* MONTANT */}
                        <td
                          style={{
                            padding: '0 24px',
                            textAlign: 'right',
                            fontSize: isSelected ? 16 : 14,
                            fontWeight: 700,
                            color: COLORS.ink,
                          }}
                        >
                          {fmtPrice(o.totalTTC)}
                        </td>

                        {/* CAISSE */}
                        <td style={{ padding: '0 16px' }}>
                          {o.registerId?.name ? (
                            <span
                              style={{
                                background: COLORS.stone100,
                                borderRadius: 6,
                                padding: '4px 10px',
                                fontSize: 12,
                                fontWeight: 500,
                                color: COLORS.stone700,
                              }}
                            >
                              {o.registerId.name}
                            </span>
                          ) : (
                            <span style={{ fontSize: 14, color: COLORS.stone400 }}>—</span>
                          )}
                        </td>

                        {/* CLIENT */}
                        <td
                          style={{
                            padding: '0 20px',
                            fontSize: 14,
                            fontWeight: 400,
                            color: client ? COLORS.ink : COLORS.stone500,
                            fontStyle: client ? 'normal' : 'italic',
                            maxWidth: 180,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {client || 'Client Passant'}
                        </td>

                        {/* MODE */}
                        <td style={{ padding: '0 16px' }}>
                          <span
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 6,
                              padding: '5px 10px',
                              borderRadius: 20,
                              background: mode.bg,
                              color: mode.fg,
                              fontSize: 12,
                              fontWeight: 700,
                            }}
                          >
                            <span style={{ width: 6, height: 6, borderRadius: '50%', background: mode.dot }} />
                            {mode.label}
                          </span>
                        </td>

                        {/* ACTIONS */}
                        <td style={{ padding: '0 20px', textAlign: 'center' }}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                            {o.status === 'en_attente' && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleMarkTerminee(o);
                                }}
                                style={{
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 4,
                                  padding: '7px 10px',
                                  borderRadius: 6,
                                  border: 'none',
                                  background: COLORS.success,
                                  color: '#FFFFFF',
                                  fontSize: 12,
                                  fontWeight: 600,
                                  cursor: 'pointer',
                                  fontFamily: FONT_BODY,
                                }}
                              >
                                <Check size={14} /> Terminer
                              </button>
                            )}

                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setSelectedId(o._id);
                                setDrawerOrder(o);
                              }}
                              style={{
                                padding: '7px 12px',
                                borderRadius: 6,
                                border: isSelected ? `1px solid ${COLORS.ink}` : '1px solid #D6D3D1',
                                background: isSelected ? COLORS.ink : '#FFFFFF',
                                color: isSelected ? '#FFFFFF' : COLORS.stone600,
                                fontSize: 12,
                                fontWeight: isSelected ? 600 : 500,
                                cursor: 'pointer',
                                fontFamily: FONT_BODY,
                              }}
                            >
                              Détails
                            </button>

                            {isSelected && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  printThermalReceipt({ order: o, kitchenOnly: false });
                                }}
                                title="Imprimer le ticket"
                                style={{
                                  padding: 4,
                                  border: 'none',
                                  background: 'none',
                                  cursor: 'pointer',
                                  color: COLORS.stone600,
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                }}
                              >
                                <Printer size={18} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          {/* ── Pagination Bar (Exact Caisse) ── */}
          {totalPages > 1 && (
            <div
              style={{
                padding: '16px 24px',
                background: COLORS.stone50,
                borderTop: `1px solid ${COLORS.border}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: 12,
              }}
            >
              <div style={{ fontSize: 12, color: COLORS.stone600, fontWeight: 400 }}>
                Affichage de {firstShown} à {lastShown} sur {totalOrders} {currentTabObj.countLabel}
              </div>

              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <button
                  disabled={page <= 1}
                  onClick={() => setPage((p) => p - 1)}
                  style={{
                    height: 34,
                    padding: '0 14px',
                    borderRadius: 6,
                    border: `1px solid ${COLORS.border}`,
                    background: '#FFFFFF',
                    color: page <= 1 ? '#D6D3D1' : COLORS.ink,
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: page <= 1 ? 'not-allowed' : 'pointer',
                    fontFamily: FONT_BODY,
                  }}
                >
                  Précédent
                </button>

                {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => {
                  const pNum = i + 1;
                  const isCurrent = pNum === page;
                  return (
                    <button
                      key={pNum}
                      onClick={() => setPage(pNum)}
                      style={{
                        width: 34,
                        height: 34,
                        borderRadius: 6,
                        border: isCurrent ? `1px solid ${COLORS.brandDark}` : `1px solid ${COLORS.border}`,
                        background: isCurrent ? COLORS.brandDark : '#FFFFFF',
                        color: isCurrent ? '#FFFFFF' : COLORS.ink,
                        fontSize: 12,
                        fontWeight: isCurrent ? 700 : 600,
                        cursor: 'pointer',
                        fontFamily: FONT_BODY,
                      }}
                    >
                      {pNum}
                    </button>
                  );
                })}

                <button
                  disabled={page >= totalPages}
                  onClick={() => setPage((p) => p + 1)}
                  style={{
                    height: 34,
                    padding: '0 14px',
                    borderRadius: 6,
                    border: `1px solid ${COLORS.border}`,
                    background: '#FFFFFF',
                    color: page >= totalPages ? '#D6D3D1' : COLORS.ink,
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: page >= totalPages ? 'not-allowed' : 'pointer',
                    fontFamily: FONT_BODY,
                  }}
                >
                  Suivant
                </button>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* ── Status Bar (Exact Caisse) ── */}
      <footer
        style={{
          padding: '13px 24px',
          background: COLORS.surface,
          borderTop: `1px solid ${COLORS.border}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          fontSize: 13,
        }}
      >
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#10B981' }} />
          <span style={{ fontWeight: 600, color: '#1F2937' }}>Connecté</span>
        </div>
        <div style={{ fontSize: 12, color: '#6B7280' }}>
          SprintKitchen OS v2.4.0-PROD
        </div>
      </footer>

      {/* ── Modals & Drawers ── */}
      {showDatePicker && (
        <DateRangePopover
          anchorRef={calendarTriggerRef}
          initialRange={range}
          onClose={() => setShowDatePicker(false)}
          onApply={handleApplyRange}
        />
      )}

      {drawerOrder && (
        <OrderDetailsPanel
          order={drawerOrder}
          onClose={() => setDrawerOrder(null)}
          onMarkTerminee={handleMarkTerminee}
          onRefund={handleRefund}
        />
      )}
    </div>
  );
}
