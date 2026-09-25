import React, { useState, useEffect, useCallback, useMemo } from 'react';
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

const FR_MONTHS_FULL = [
  'JANVIER', 'FÉVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
  'JUILLET', 'AOÛT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DÉCEMBRE',
];

const FR_DAYS_SHORT = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

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

function addDays(d, n) {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}

function startOfMonth(d) {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function endOfMonth(d) {
  return new Date(d.getFullYear(), d.getMonth() + 1, 0);
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

/* ── Date Range Modal (Exact replica of DateRangePopover) ────────────────────────── */
function MonthCalendar({ year, month, lo, hi, picking, hovered, onDayClick, onDayHover }) {
  const TODAY = new Date();
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
    <div style={{ flex: 1, minWidth: 0 }}>
      <div
        style={{
          textAlign: 'center',
          fontWeight: 800,
          fontSize: 13,
          letterSpacing: '0.07em',
          color: COLORS.ink,
          marginBottom: 12,
        }}
      >
        {FR_MONTHS_FULL[month]} {year}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 34px)', rowGap: 1, justifyContent: 'center' }}>
        {FR_DAYS_SHORT.map((d, i) => (
          <div
            key={i}
            style={{
              textAlign: 'center',
              fontSize: 11,
              fontWeight: 700,
              color: COLORS.stone500,
              height: 22,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {d}
          </div>
        ))}

        {cells.map((d, i) => {
          if (!d) return <div key={`e${i}`} style={{ height: 36 }} />;
          const isStart = realLo && isSameDay(d, realLo);
          const isEnd = realHi && isSameDay(d, realHi);
          const isBoth = isStart && isEnd;
          const inRange = realLo && realHi && d > realLo && d < realHi;
          const isToday = isSameDay(d, TODAY);
          const isSelect = isStart || isEnd;

          let cellBg = 'transparent';
          if (!isBoth) {
            if (isStart && realHi) cellBg = `linear-gradient(to right, transparent 50%, ${COLORS.rangeFill} 50%)`;
            else if (isEnd) cellBg = `linear-gradient(to left, transparent 50%, ${COLORS.rangeFill} 50%)`;
            else if (inRange) cellBg = COLORS.rangeFill;
          }

          return (
            <div
              key={i}
              onClick={() => onDayClick(d)}
              onMouseEnter={() => onDayHover(d)}
              style={{
                height: 36,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                background: cellBg,
              }}
            >
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  width: 32,
                  height: 32,
                  borderRadius: '50%',
                  fontSize: 13,
                  fontWeight: isSelect ? 700 : 400,
                  background: isSelect ? COLORS.brandDark : inRange ? COLORS.rangeFill : 'transparent',
                  color: isSelect ? '#FFF8E7' : inRange ? '#78350F' : isToday ? COLORS.brandDark : COLORS.ink,
                  boxShadow: isToday && !isSelect ? `0 0 0 2px ${COLORS.gold}` : 'none',
                }}
              >
                {d.getDate()}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function DateRangeModal({ initialRange, onClose, onApply }) {
  const TODAY = useMemo(() => new Date(), []);
  const [rangeStart, setRangeStart] = useState(initialRange.start);
  const [rangeEnd, setRangeEnd] = useState(initialRange.end);
  const [hovered, setHovered] = useState(null);
  const [picking, setPicking] = useState(false);
  const [activeKey, setActiveKey] = useState(
    initialRange.start.getFullYear() <= 2020 ? 'all' : 'today'
  );

  const [rightMonth, setRightMonth] = useState({
    year: (initialRange.end || TODAY).getFullYear(),
    month: (initialRange.end || TODAY).getMonth(),
  });

  const leftMonth =
    rightMonth.month === 0
      ? { year: rightMonth.year - 1, month: 11 }
      : { year: rightMonth.year, month: rightMonth.month - 1 };

  const applyShortcut = (fn, key) => {
    fn();
    setActiveKey(key);
    setPicking(false);
  };

  const shortcuts = [
    {
      key: 'today',
      label: "Aujourd'hui",
      fn: () => {
        const t = new Date();
        setRangeStart(t);
        setRangeEnd(t);
      },
    },
    {
      key: 'hier',
      label: 'Hier',
      fn: () => {
        const y = addDays(new Date(), -1);
        setRangeStart(y);
        setRangeEnd(y);
      },
    },
    {
      key: '7j',
      label: '7 derniers jours',
      fn: () => {
        const t = new Date();
        setRangeStart(addDays(t, -6));
        setRangeEnd(t);
      },
    },
    {
      key: 'mois',
      label: 'Ce mois-ci',
      fn: () => {
        const t = new Date();
        setRangeStart(startOfMonth(t));
        setRangeEnd(t);
      },
    },
    {
      key: 'last',
      label: 'Mois dernier',
      fn: () => {
        const t = new Date();
        const prev = new Date(t.getFullYear(), t.getMonth() - 1, 1);
        setRangeStart(prev);
        setRangeEnd(endOfMonth(prev));
      },
    },
    {
      key: 'all',
      label: "Tout l'historique",
      fn: () => {
        setRangeStart(new Date(2020, 0, 1));
        setRangeEnd(new Date());
      },
    },
  ];

  const handleDayClick = (d) => {
    setActiveKey('custom');
    if (!picking) {
      setRangeStart(d);
      setRangeEnd(null);
      setPicking(true);
    } else {
      if (d < rangeStart) {
        setRangeEnd(rangeStart);
        setRangeStart(d);
      } else {
        setRangeEnd(d);
      }
      setPicking(false);
    }
  };

  const effEnd = rangeEnd || rangeStart;
  const lo = rangeStart && effEnd ? (rangeStart <= effEnd ? rangeStart : effEnd) : rangeStart;
  const hi = rangeStart && effEnd ? (rangeStart <= effEnd ? effEnd : rangeStart) : null;
  const dayCount = lo && hi ? Math.round(Math.abs(hi - lo) / 86400000) + 1 : 1;

  return (
    <div
      onClick={(e) => e.target === e.currentTarget && onClose()}
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(28,25,23,0.5)',
        zIndex: 400,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
        fontFamily: FONT_BODY,
      }}
    >
      <div
        style={{
          background: COLORS.surface,
          borderRadius: 16,
          width: 'min(760px, 96vw)',
          boxShadow: '0 24px 80px rgba(0,0,0,0.3)',
          overflow: 'hidden',
        }}
      >
        {/* Modal Header */}
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', padding: '18px 22px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: 9,
                background: '#F1F0EC',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}
            >
              <Calendar size={17} color={COLORS.ink} />
            </div>
            <div>
              <div style={{ fontSize: 16, fontWeight: 800, color: COLORS.ink, lineHeight: 1.2 }}>
                SÉLECTIONNER UNE PÉRIODE DE VENTE
              </div>
              <div style={{ fontSize: 12, color: COLORS.stone500, marginTop: 3 }}>
                Filtrer l'historique des encaissements, tickets et statistiques
              </div>
            </div>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.stone500, padding: 4 }}>
            <X size={18} />
          </button>
        </div>

        <div style={{ height: 1, background: COLORS.border }} />

        {/* Modal Content */}
        <div style={{ display: 'flex', flexWrap: 'wrap' }}>
          {/* Shortcuts column */}
          <div style={{ width: 190, borderRight: `1px solid ${COLORS.border}`, padding: '14px 0', flexShrink: 0 }}>
            <div
              style={{
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: '0.09em',
                color: COLORS.stone500,
                textTransform: 'uppercase',
                padding: '0 14px 10px',
              }}
            >
              Raccourcis rapides
            </div>
            {shortcuts.map((s) => {
              const on = activeKey === s.key;
              return (
                <button
                  key={s.key}
                  onClick={() => applyShortcut(s.fn, s.key)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    width: on ? 'calc(100% - 12px)' : '100%',
                    margin: on ? '3px 6px' : '3px 0',
                    padding: '9px 14px',
                    background: on ? COLORS.brandDark : 'transparent',
                    border: 'none',
                    cursor: 'pointer',
                    fontFamily: FONT_BODY,
                    textAlign: 'left',
                    borderRadius: on ? 9 : 0,
                  }}
                >
                  <span style={{ fontSize: 13, fontWeight: 600, color: on ? '#FFF8E7' : COLORS.ink }}>{s.label}</span>
                  {on && (
                    <span
                      style={{
                        fontSize: 10,
                        fontWeight: 800,
                        background: COLORS.gold,
                        color: COLORS.brandDark,
                        padding: '2px 8px',
                        borderRadius: 999,
                      }}
                    >
                      Actif
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          {/* Calendars */}
          <div style={{ flex: 1, padding: '14px 12px 18px', minWidth: 320 }} onMouseLeave={() => setHovered(null)}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 6 }}>
              <button
                onClick={() =>
                  setRightMonth((p) => (p.month === 0 ? { year: p.year - 1, month: 11 } : { year: p.year, month: p.month - 1 }))
                }
                style={{
                  background: 'none',
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 8,
                  width: 30,
                  height: 30,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: COLORS.ink,
                  flexShrink: 0,
                  marginTop: 2,
                }}
              >
                <ChevronLeft size={14} />
              </button>

              <div style={{ display: 'flex', flex: 1, gap: 12 }}>
                <MonthCalendar
                  {...leftMonth}
                  lo={lo}
                  hi={hi}
                  picking={picking}
                  hovered={hovered}
                  onDayClick={handleDayClick}
                  onDayHover={setHovered}
                />
                <MonthCalendar
                  {...rightMonth}
                  lo={lo}
                  hi={hi}
                  picking={picking}
                  hovered={hovered}
                  onDayClick={handleDayClick}
                  onDayHover={setHovered}
                />
              </div>

              <button
                onClick={() =>
                  setRightMonth((p) => (p.month === 11 ? { year: p.year + 1, month: 0 } : { year: p.year, month: p.month + 1 }))
                }
                style={{
                  background: 'none',
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 8,
                  width: 30,
                  height: 30,
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: COLORS.ink,
                  flexShrink: 0,
                  marginTop: 2,
                }}
              >
                <ChevronRight size={14} />
              </button>
            </div>
          </div>
        </div>

        <div style={{ height: 1, background: COLORS.border }} />

        {/* Modal Footer */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '14px 22px',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 13, color: COLORS.ink, fontWeight: 500 }}>Période sélectionnée :</span>
            <span
              style={{
                fontSize: 12,
                fontWeight: 600,
                background: COLORS.background,
                border: `1px solid ${COLORS.border}`,
                borderRadius: 7,
                padding: '4px 10px',
                fontFamily: 'monospace',
              }}
            >
              {fmtDate(lo)} — {fmtDate(hi || lo)}
              {lo && lo.getFullYear() <= 2020 ? ' (Tout)' : ` (${dayCount} j)`}
            </span>
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={onClose}
              style={{
                padding: '9px 18px',
                borderRadius: 9,
                border: `1px solid ${COLORS.borderDark}`,
                background: COLORS.surface,
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                color: COLORS.ink,
              }}
            >
              Annuler
            </button>
            <button
              onClick={() => {
                onApply(lo, hi || lo);
                onClose();
              }}
              style={{
                padding: '9px 20px',
                borderRadius: 9,
                border: 'none',
                background: COLORS.gold,
                fontSize: 13,
                fontWeight: 800,
                cursor: 'pointer',
                fontFamily: FONT_BODY,
                color: COLORS.brandDark,
              }}
            >
              ✓ Appliquer la période
            </button>
          </div>
        </div>
      </div>
    </div>
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
              onClick={() => setShowDatePicker(true)}
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
        <DateRangeModal
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
