import React from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, Search, RefreshCw, Circle, UtensilsCrossed, Plus } from "lucide-react";
import { ingredientService, ingredientFamilyService } from "../services";

const C = {
  bg: "#F5F4F0",
  cardBg: "#FFFFFF",
  ink: "#1C1917",
  brown: "#583926",
  yellow: "#FACC15",
  muted: "#6B7280",
  border: "#E5E7EB",
  borderDark: "#D1D5DB",
  green: "#059669",
  greenBg: "#E8F8EF",
  greenText: "#1A7A45",
  red: "#EF4444",
  orange: "#D9720C",
};

const FONT_TITLE = "'Bebas Neue', sans-serif";
const FONT_BODY = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";

const slugify = (s) =>
  s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
   .replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");

const isEpuise = (i) => i.availability !== "available";
const isBloque  = (i) => i.availability === "bloque";

/* ── shared modal backdrop + shell ── */
function ModalShell({ onClose, children, mobile }) {
  // Trap scroll
  React.useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, []);

  const backdropStyle = {
    position: "fixed", inset: 0, zIndex: 1000,
    background: "rgba(0,0,0,0.45)",
    display: "flex",
    alignItems: mobile ? "flex-end" : "center",
    justifyContent: "center",
  };

  const cardStyle = mobile ? {
    width: "100%", background: C.cardBg, borderRadius: "14px 14px 0 0",
    maxHeight: "92vh", overflowY: "auto", paddingBottom: 24,
  } : {
    width: 480, background: C.cardBg, borderRadius: 14,
    maxHeight: "90vh", overflowY: "auto",
    boxShadow: "0 8px 40px rgba(0,0,0,0.18)",
  };

  return (
    <div style={backdropStyle} onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div style={cardStyle}>
        {/* drag handle on mobile */}
        {mobile && (
          <div style={{ display: "flex", justifyContent: "center", padding: "10px 0 4px" }}>
            <div style={{ width: 40, height: 4, borderRadius: 2, background: C.border }} />
          </div>
        )}
        {children}
      </div>
    </div>
  );
}

/* ── ToggleBtn (desktop inline) ── */
function ToggleBtn({ ingredient, onToggle, toggling }) {
  const loading = toggling === ingredient._id;
  const epuise  = isEpuise(ingredient);
  if (epuise) return (
    <button onClick={() => onToggle(ingredient, "available")} disabled={loading}
      style={{
        display: "inline-flex", alignItems: "center", gap: 8,
        padding: "9px 18px", borderRadius: 8, border: "none", cursor: "pointer",
        background: "#1C1917", color: "#FFFFFF",
        fontSize: 11.5, fontWeight: 700, letterSpacing: "0.04em",
        fontFamily: "inherit", whiteSpace: "nowrap", minWidth: 148,
        justifyContent: "center", opacity: loading ? 0.6 : 1,
      }}>
      <Circle size={7} fill="#E03C31" color="#E03C31" style={{ flexShrink: 0 }} />
      × ÉPUISÉ
    </button>
  );
  return (
    <button onClick={() => onToggle(ingredient, "epuise")} disabled={loading}
      style={{
        display: "inline-flex", alignItems: "center", gap: 8,
        padding: "9px 18px", borderRadius: 8, border: "none", cursor: "pointer",
        background: C.greenBg, color: C.greenText,
        fontSize: 11.5, fontWeight: 700, letterSpacing: "0.04em",
        fontFamily: "inherit", whiteSpace: "nowrap", minWidth: 148,
        justifyContent: "center", opacity: loading ? 0.6 : 1,
      }}>
      <Circle size={7} fill={C.green} color={C.green} style={{ flexShrink: 0 }} />
      DISPONIBLE
    </button>
  );
}

/* ── MobileToggleBtn (full-width card button) ── */
function MobileToggleBtn({ ingredient, onToggle, toggling }) {
  const loading = toggling === ingredient._id;
  const epuise  = isEpuise(ingredient);
  if (epuise) return (
    <button onClick={() => onToggle(ingredient, "available")} disabled={loading}
      style={{
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
        width: "100%", padding: "11px 0", borderRadius: 9, border: "none",
        background: "#1C1917", color: "#FFFFFF",
        fontSize: 12.5, fontWeight: 700, letterSpacing: "0.04em",
        fontFamily: "inherit", cursor: "pointer", opacity: loading ? 0.6 : 1,
      }}>
      <Circle size={7} fill="#E03C31" color="#E03C31" style={{ flexShrink: 0 }} />
      ÉPUISÉ — CAISSE &amp; BORNES
    </button>
  );
  return (
    <button onClick={() => onToggle(ingredient, "epuise")} disabled={loading}
      style={{
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
        width: "100%", padding: "11px 0", borderRadius: 9,
        border: `1.5px solid ${C.green}`, background: C.greenBg,
        color: C.greenText,
        fontSize: 12.5, fontWeight: 700, letterSpacing: "0.04em",
        fontFamily: "inherit", cursor: "pointer", opacity: loading ? 0.6 : 1,
      }}>
      <Circle size={7} fill={C.green} color={C.green} style={{ flexShrink: 0 }} />
      DISPONIBLE
    </button>
  );
}

/* ── IngredientModal ── */
function IngredientModal({ ingredient, ingredients = [], families, defaultFamily, mobile, onClose, onSaved, onDeleted }) {
  const isEdit = !!ingredient;
  const [name,   setName]   = React.useState(ingredient?.name   || "");
  const [family, setFamily] = React.useState(ingredient?.family || defaultFamily || families[0]?.slug || "");
  const [unit,   setUnit]   = React.useState(ingredient?.unit   || "");
  const [notes,  setNotes]  = React.useState(ingredient?.notes  || "");
  const [saving,  setSaving]  = React.useState(false);
  const [deleting,setDeleting]= React.useState(false);
  const [error,  setError]  = React.useState("");

  const labelStyle = {
    display: "block", fontSize: 11.5, fontWeight: 700,
    color: C.muted, letterSpacing: "0.06em", textTransform: "uppercase", marginBottom: 5,
  };
  const inputStyle = {
    width: "100%", padding: "10px 12px", borderRadius: 8,
    border: `1px solid ${C.border}`, fontSize: 13.5, fontFamily: "inherit",
    color: C.ink, background: C.cardBg, outline: "none", boxSizing: "border-box",
  };

  const handleSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) { setError("Le nom est requis."); return; }
    if (ingredients?.some(i => i._id !== ingredient?._id && i.name?.trim().toLowerCase() === trimmed.toLowerCase())) {
      setError("Un ingrédient avec ce nom existe déjà.");
      return;
    }
    setSaving(true); setError("");
    try {
      let result;
      if (isEdit) {
        result = await ingredientService.update(ingredient._id, {
          name: trimmed, family, unit: unit.trim(), notes: notes.trim(),
        });
        onSaved(result.data.data);
      } else {
        result = await ingredientService.create({
          name: trimmed, family, unit: unit.trim(), notes: notes.trim(),
        });
        onSaved(result.data.data, true);
      }
      onClose();
    } catch(e) {
      setError(e?.response?.data?.message || "Une erreur est survenue.");
    } finally { setSaving(false); }
  };

  const handleDelete = async () => {
    if (!window.confirm(`Supprimer définitivement l'ingrédient "${ingredient.name}" ?`)) return;
    setDeleting(true);
    try {
      await ingredientService.delete(ingredient._id);
      onDeleted(ingredient._id);
      onClose();
    } catch(e) {
      setError(e?.response?.data?.message || "Erreur lors de la suppression.");
      setDeleting(false);
    }
  };

  return (
    <ModalShell onClose={onClose} mobile={mobile}>
      {/* Header */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "18px 22px 14px", borderBottom: `1px solid ${C.border}`,
      }}>
        <h2 style={{
          margin: 0, fontFamily: FONT_TITLE,
          fontSize: 24, fontWeight: 400, color: "#1A1714", letterSpacing: "0.6px",
        }}>
          {isEdit ? "MODIFIER L'INGRÉDIENT" : "NOUVEL INGRÉDIENT"}
        </h2>
        <button onClick={onClose} style={{
          background: "none", border: "none", cursor: "pointer",
          fontSize: 20, color: C.muted, lineHeight: 1, padding: "0 4px",
        }}>✕</button>
      </div>

      {/* Form */}
      <div style={{ padding: "18px 22px", display: "flex", flexDirection: "column", gap: 16 }}>
        {error && (
          <div style={{
            background: "#FDEAE8", color: C.red,
            border: `1px solid #F5C6C2`, borderRadius: 8,
            padding: "10px 14px", fontSize: 13,
          }}>{error}</div>
        )}

        {/* Nom */}
        <div>
          <label style={labelStyle}>Nom</label>
          <input
            style={inputStyle}
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="ex. Steak Haché 180g"
            autoFocus
          />
        </div>

        {/* Famille */}
        <div>
          <label style={labelStyle}>Famille</label>
          <select
            style={{ ...inputStyle, appearance: "none", cursor: "pointer" }}
            value={family}
            onChange={e => setFamily(e.target.value)}
          >
            {families.map(f => (
              <option key={f.slug} value={f.slug}>{f.emoji} {f.name}</option>
            ))}
          </select>
        </div>

        {/* Unité */}
        <div>
          <label style={labelStyle}>Unité</label>
          <input
            style={inputStyle}
            value={unit}
            onChange={e => setUnit(e.target.value)}
            placeholder="kg, L, portion, unité…"
          />
        </div>

        {/* Notes */}
        <div>
          <label style={labelStyle}>Notes</label>
          <input
            style={inputStyle}
            value={notes}
            onChange={e => setNotes(e.target.value)}
            placeholder="Rupture fournisseur, Livraison mardi…"
          />
        </div>
      </div>

      {/* Buttons */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "flex-end",
        gap: 10, padding: "0 22px 22px",
        flexWrap: "wrap",
      }}>
        {isEdit && (
          <button onClick={handleDelete} disabled={deleting} style={{
            marginRight: "auto",
            padding: "10px 18px", borderRadius: 8,
            border: `1.5px solid ${C.red}`, background: "transparent",
            color: C.red, fontSize: 13, fontWeight: 600,
            cursor: "pointer", fontFamily: "inherit", opacity: deleting ? 0.6 : 1,
          }}>
            {deleting ? "…" : "Supprimer"}
          </button>
        )}
        <button onClick={onClose} style={{
          padding: "10px 18px", borderRadius: 8,
          border: `1.5px solid ${C.border}`, background: "transparent",
          color: C.ink, fontSize: 13, fontWeight: 600,
          cursor: "pointer", fontFamily: "inherit",
        }}>Annuler</button>
        <button onClick={handleSave} disabled={saving} style={{
          padding: "10px 22px", borderRadius: 8,
          border: "none", background: C.yellow,
          color: "#1F2937", fontSize: 13, fontWeight: 700,
          cursor: "pointer", fontFamily: "inherit", opacity: saving ? 0.7 : 1,
        }}>
          {saving ? "…" : isEdit ? "Enregistrer" : "Ajouter"}
        </button>
      </div>
    </ModalShell>
  );
}

/* ── FamilyModal ── */
function FamilyModal({ family, families = [], mobile, onClose, onSaved, onDeleted }) {
  const isEdit = !!family;
  const [emoji, setEmoji] = React.useState(family?.emoji || "📦");
  const [name,  setName]  = React.useState(family?.name  || "");
  const [saving,  setSaving]  = React.useState(false);
  const [deleting,setDeleting]= React.useState(false);
  const [error,  setError]  = React.useState("");

  const labelStyle = {
    display: "block", fontSize: 11.5, fontWeight: 700,
    color: C.muted, letterSpacing: "0.06em", textTransform: "uppercase", marginBottom: 5,
  };
  const inputStyle = {
    width: "100%", padding: "10px 12px", borderRadius: 8,
    border: `1px solid ${C.border}`, fontSize: 13.5, fontFamily: "inherit",
    color: C.ink, background: C.cardBg, outline: "none", boxSizing: "border-box",
  };

  const handleSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) { setError("Le nom est requis."); return; }
    if (families?.some(f => f._id !== family?._id && f.name?.trim().toLowerCase() === trimmed.toLowerCase())) {
      setError("Une famille avec ce nom existe déjà.");
      return;
    }
    setSaving(true); setError("");
    try {
      let result;
      if (isEdit) {
        result = await ingredientFamilyService.update(family._id, { name: trimmed, emoji });
        onSaved({ ...family, ...result.data.data });
      } else {
        const slug = slugify(trimmed);
        result = await ingredientFamilyService.create({ name: trimmed, slug, emoji });
        onSaved(result.data.data, true);
      }
      onClose();
    } catch(e) {
      setError(e?.response?.data?.message || "Une erreur est survenue.");
    } finally { setSaving(false); }
  };

  const handleDelete = async () => {
    if (!window.confirm(`Supprimer la famille "${family.name}" ? Les ingrédients associés ne seront pas effacés automatiquement.`)) return;
    setDeleting(true);
    try {
      await ingredientFamilyService.delete(family._id);
      onDeleted(family._id);
      onClose();
    } catch(e) {
      setError(e?.response?.data?.message || "Erreur lors de la suppression.");
      setDeleting(false);
    }
  };

  return (
    <ModalShell onClose={onClose} mobile={mobile}>
      {/* Header */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "18px 22px 14px", borderBottom: `1px solid ${C.border}`,
      }}>
        <h2 style={{
          margin: 0, fontFamily: FONT_TITLE,
          fontSize: 24, fontWeight: 400, color: "#1A1714", letterSpacing: "0.6px",
        }}>
          {isEdit ? "MODIFIER LA FAMILLE" : "NOUVELLE FAMILLE"}
        </h2>
        <button onClick={onClose} style={{
          background: "none", border: "none", cursor: "pointer",
          fontSize: 20, color: C.muted, lineHeight: 1, padding: "0 4px",
        }}>✕</button>
      </div>

      {/* Form */}
      <div style={{ padding: "18px 22px", display: "flex", flexDirection: "column", gap: 16 }}>
        {error && (
          <div style={{
            background: "#FDEAE8", color: C.red,
            border: `1px solid #F5C6C2`, borderRadius: 8,
            padding: "10px 14px", fontSize: 13,
          }}>{error}</div>
        )}

        {/* Emoji + Nom on same row */}
        <div style={{ display: "flex", gap: 12, alignItems: "flex-end" }}>
          <div style={{ flexShrink: 0 }}>
            <label style={labelStyle}>Emoji</label>
            <input
              style={{
                ...inputStyle,
                width: 56, textAlign: "center",
                fontSize: 28, padding: "4px 6px",
              }}
              value={emoji}
              onChange={e => setEmoji(e.target.value)}
              maxLength={4}
            />
          </div>
          <div style={{ flex: 1 }}>
            <label style={labelStyle}>Nom de la famille</label>
            <input
              style={inputStyle}
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="ex. Desserts & Sucreries"
              autoFocus
            />
          </div>
        </div>
      </div>

      {/* Buttons */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "flex-end",
        gap: 10, padding: "0 22px 22px", flexWrap: "wrap",
      }}>
        {isEdit && (
          <button onClick={handleDelete} disabled={deleting} style={{
            marginRight: "auto",
            padding: "10px 18px", borderRadius: 8,
            border: `1.5px solid ${C.red}`, background: "transparent",
            color: C.red, fontSize: 13, fontWeight: 600,
            cursor: "pointer", fontFamily: "inherit", opacity: deleting ? 0.6 : 1,
          }}>
            {deleting ? "…" : "Supprimer"}
          </button>
        )}
        <button onClick={onClose} style={{
          padding: "10px 18px", borderRadius: 8,
          border: `1.5px solid ${C.border}`, background: "transparent",
          color: C.ink, fontSize: 13, fontWeight: 600,
          cursor: "pointer", fontFamily: "inherit",
        }}>Annuler</button>
        <button onClick={handleSave} disabled={saving} style={{
          padding: "10px 22px", borderRadius: 8,
          border: "none", background: C.yellow,
          color: "#1F2937", fontSize: 13, fontWeight: 700,
          cursor: "pointer", fontFamily: "inherit", opacity: saving ? 0.7 : 1,
        }}>
          {saving ? "…" : "Enregistrer"}
        </button>
      </div>
    </ModalShell>
  );
}

/* ══════════════════════════════════════════════════════ */
export default function InventairePage() {
  const navigate = useNavigate();
  const [mobile, setMobile] = React.useState(window.innerWidth < 900);
  React.useEffect(() => {
    const h = () => setMobile(window.innerWidth < 900);
    window.addEventListener("resize", h); return () => window.removeEventListener("resize", h);
  }, []);

  // ── State ──
  const [families,      setFamilies]      = React.useState([]);
  const [activeFamily,  setActiveFamily]  = React.useState(null); // stores slug
  const [familyStats,   setFamilyStats]   = React.useState([]);
  const [ingredients,   setIngredients]   = React.useState([]);
  const [loadingFams,   setLoadingFams]   = React.useState(true);
  const [loadingIngs,   setLoadingIngs]   = React.useState(false);
  const [search,        setSearch]        = React.useState("");
  const [toggling,      setToggling]      = React.useState(null); // ingredient._id being toggled
  const [hoveredFam,    setHoveredFam]    = React.useState(null);

  // Modals
  const [ingModal, setIngModal] = React.useState(null); // null | { ingredient? }
  const [famModal, setFamModal] = React.useState(null); // null | { family? }

  const [refreshKey, setRefreshKey] = React.useState(0);

  // ── Load families ──
  React.useEffect(() => {
    let cancel = false;
    setLoadingFams(true);
    ingredientFamilyService.getAll()
      .then(res => {
        if (cancel) return;
        const list = res.data?.data || [];
        const safeList = Array.isArray(list) ? list : [];
        setFamilies(safeList);
        if (safeList.length > 0) {
          setActiveFamily(prev => (safeList.some(f => f.slug === prev) ? prev : safeList[0].slug));
        }
      })
      .catch((err) => {
        console.error("Erreur chargement familles :", err);
      })
      .finally(() => { if (!cancel) setLoadingFams(false); });
    return () => { cancel = true; };
  }, [refreshKey]);

  // ── Load family stats (rupture counts) ──
  React.useEffect(() => {
    let cancel = false;
    ingredientFamilyService.getStats()
      .then(res => {
        if (!cancel) {
          const stats = res.data?.data;
          setFamilyStats(Array.isArray(stats) ? stats : []);
        }
      })
      .catch((err) => {
        console.error("Erreur chargement stats familles :", err);
      });
    return () => { cancel = true; };
  }, [refreshKey]);

  // ── Load ingredients when activeFamily changes ──
  React.useEffect(() => {
    if (!activeFamily) {
      setIngredients([]);
      return;
    }
    let cancel = false;
    setLoadingIngs(true);
    ingredientService.getAll({ family: activeFamily, limit: 100 })
      .then(res => {
        if (!cancel) {
          const list = res.data?.data;
          setIngredients(Array.isArray(list) ? list : []);
        }
      })
      .catch((err) => {
        console.error("Erreur chargement ingrédients :", err);
      })
      .finally(() => { if (!cancel) setLoadingIngs(false); });
    return () => { cancel = true; };
  }, [activeFamily, refreshKey]);

  // ── Toggle availability ──
  const handleToggle = async (ingredient, newAvail) => {
    if (toggling) return;
    setToggling(ingredient._id);
    try {
      await ingredientService.setAvailability(ingredient._id, newAvail);
      setIngredients(prev =>
        prev.map(i => i._id === ingredient._id ? { ...i, availability: newAvail } : i)
      );
      setFamilyStats(prev => prev.map(f => {
        if (f._id !== activeFamily) return f;
        const delta = newAvail === "available" ? -1 : 1;
        return { ...f, epuise: Math.max(0, f.epuise + delta) };
      }));
    } catch(e) { console.error(e); }
    finally { setToggling(null); }
  };

  // ── Modal callbacks ──
  const handleIngSaved = (saved, isNew) => {
    if (isNew) {
      if (saved.family === activeFamily) {
        setIngredients(prev => [...prev, saved]);
      }
    } else {
      setIngredients(prev => prev.map(i => i._id === saved._id ? saved : i));
    }
    setRefreshKey(k => k + 1);
  };

  const handleIngDeleted = (id) => {
    setIngredients(prev => prev.filter(i => i._id !== id));
    setRefreshKey(k => k + 1);
  };

  const handleFamSaved = (saved, isNew) => {
    if (isNew) {
      setFamilies(prev => [...prev, saved].sort((a,b) => (a.displayOrder || 0) - (b.displayOrder || 0)));
      setActiveFamily(saved.slug);
    } else {
      setFamilies(prev => prev.map(f => f._id === saved._id ? saved : f));
    }
    setRefreshKey(k => k + 1);
  };

  const handleFamDeleted = (id) => {
    setFamilies(prev => {
      const remaining = prev.filter(f => f._id !== id);
      if (remaining.length > 0) setActiveFamily(remaining[0].slug);
      else setActiveFamily(null);
      return remaining;
    });
    setRefreshKey(k => k + 1);
  };

  const safeIngredients = Array.isArray(ingredients) ? ingredients : [];
  const filtered = safeIngredients.filter(i =>
    !search ||
    (i?.name || "").toLowerCase().includes(search.toLowerCase()) ||
    (i?.notes || "").toLowerCase().includes(search.toLowerCase())
  );
  const dispoCnt  = filtered.filter(i => !isEpuise(i)).length;
  const epuiseCnt = filtered.filter(i =>  isEpuise(i)).length;
  const safeFamilies = Array.isArray(families) ? families : [];
  const activeFamilyObj = safeFamilies.find(f => f.slug === activeFamily);

  const statFor = (slug) => (Array.isArray(familyStats) ? familyStats : []).find(f => f._id === slug) || { total: 0, epuise: 0 };

  return (
    <div style={{
      minHeight: "100vh", background: C.bg,
      fontFamily: FONT_BODY,
      color: C.ink, display: "flex", flexDirection: "column",
    }}>

      {/* ── Top Header Bar (Exact Caisse / Historique) ── */}
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '10px 16px',
          background: C.cardBg,
          borderBottom: `1px solid ${C.border}`,
          flexShrink: 0,
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
              border: `1px solid ${C.borderDark}`,
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
              letterSpacing: '0.5px',
              color: '#111827',
              lineHeight: 1,
            }}
          >
            Bobo's
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
            border: `1px solid ${C.border}`,
            fontSize: 12,
            fontWeight: 600,
            color: '#1F2937',
          }}
        >
          <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#10B981' }} />
          Poste Admin (Caisse 01)
        </div>
      </header>

      {/* ── Title Bar (Exact Caisse / Historique) ── */}
      <div
        style={{
          width: '100%',
          padding: mobile ? '16px 16px' : '20px 32px 18px',
          background: C.cardBg,
          borderBottom: `1px solid ${C.border}`,
          display: 'flex',
          alignItems: mobile ? 'flex-start' : 'center',
          justifyContent: 'space-between',
          gap: 16,
          flexWrap: 'wrap',
          boxSizing: 'border-box',
        }}
      >
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 11, fontWeight: 600, letterSpacing: '0.6px', color: C.muted, marginBottom: 4 }}>
            <span>DISPONIBILITÉ DES ARTICLES</span>
            <span>•</span>
            <span style={{ color: C.green, fontWeight: 700 }}>SYNCHRONISÉ POS &amp; COMPTOIR</span>
          </div>
          <h1
            style={{
              margin: '0 0 4px',
              fontFamily: FONT_TITLE,
              fontSize: mobile ? 28 : 34,
              fontWeight: 400,
              color: '#111827',
              letterSpacing: '0.5px',
              lineHeight: 1,
            }}
          >
            DISPONIBILITÉ DES ARTICLES
          </h1>
          <p style={{ margin: 0, fontSize: 12.5, color: C.muted }}>
            Activez ou désactivez les ingrédients en stock sur la caisse POS et les bornes en temps réel.
          </p>
        </div>

        {/* Right-aligned controls */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexWrap: 'wrap',
            width: mobile ? '100%' : 'auto',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              background: '#F9FAFB',
              border: `1px solid ${C.border}`,
              borderRadius: 8,
              padding: '8px 12px',
              height: 38,
              boxSizing: 'border-box',
              flex: mobile ? 1 : undefined,
              width: mobile ? 'auto' : 260,
            }}
          >
            <Search size={15} color="#9CA3AF" style={{ flexShrink: 0 }} />
            <input
              type="text"
              placeholder="Rechercher un ingrédient…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                border: 'none',
                outline: 'none',
                fontSize: 12.5,
                fontFamily: 'inherit',
                background: 'transparent',
                color: C.ink,
                width: '100%',
              }}
            />
          </div>

          <button
            onClick={() => setRefreshKey((k) => k + 1)}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 7,
              padding: '8px 14px',
              height: 38,
              borderRadius: 8,
              border: `1px solid ${C.borderDark}`,
              background: '#F9FAFB',
              fontSize: 12,
              fontWeight: 700,
              cursor: 'pointer',
              fontFamily: 'inherit',
              color: '#374151',
              flexShrink: 0,
              boxSizing: 'border-box',
            }}
          >
            <RefreshCw size={14} /> {mobile ? '' : 'Actualiser'}
          </button>

          <button
            onClick={() => setIngModal({ ingredient: null })}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              padding: '8px 14px',
              height: 38,
              borderRadius: 8,
              border: `1px solid #EAB308`,
              background: C.yellow,
              fontSize: 12.5,
              fontWeight: 700,
              cursor: 'pointer',
              fontFamily: 'inherit',
              color: '#1F2937',
              flexShrink: 0,
              boxSizing: 'border-box',
            }}
          >
            <Plus size={16} /> {mobile ? 'Ajouter' : 'Ajouter un ingrédient'}
          </button>
        </div>
      </div>

      {/* ── Body ── */}
      <div
        style={{
          flex: 1,
          padding: mobile ? '16px 14px 32px' : '20px 32px 32px',
          display: 'flex',
          flexDirection: mobile ? 'column' : 'row',
          gap: 20,
          alignItems: 'flex-start',
          boxSizing: 'border-box',
        }}
      >
        {/* ── SIDEBAR (desktop) ── */}
        {!mobile && (
          <aside
            style={{
              width: 250,
              flexShrink: 0,
              background: C.cardBg,
              border: `1px solid ${C.border}`,
              borderRadius: 12,
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              position: 'sticky',
              top: 16,
              maxHeight: 'calc(100vh - 180px)',
            }}
          >
            <div
              style={{
                padding: '14px 16px 10px',
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: '0.6px',
                color: C.muted,
                textTransform: 'uppercase',
                borderBottom: `1px solid ${C.border}`,
              }}
            >
              Familles d'ingrédients
            </div>

            <div style={{ flex: 1, overflowY: 'auto', padding: '6px 0' }}>
              {loadingFams && families.length === 0 && (
                <div style={{ padding: '20px 16px', fontSize: 12, color: C.muted, textAlign: 'center' }}>
                  Chargement…
                </div>
              )}
              {!loadingFams && families.length === 0 && (
                <div style={{ padding: '20px 16px', fontSize: 12, color: C.muted, textAlign: 'center' }}>
                  Aucune famille
                </div>
              )}
              {families.map((fam) => {
                const active = fam.slug === activeFamily;
                const stat = statFor(fam.slug);
                return (
                  <div
                    key={fam._id}
                    style={{ position: 'relative' }}
                    onMouseEnter={() => setHoveredFam(fam._id)}
                    onMouseLeave={() => setHoveredFam(null)}
                  >
                    <button
                      onClick={() => {
                        setActiveFamily(fam.slug);
                        setSearch('');
                      }}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        width: '100%',
                        padding: '6px 10px',
                        border: 'none',
                        cursor: 'pointer',
                        fontFamily: 'inherit',
                        background: 'transparent',
                      }}
                    >
                      {active ? (
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 8,
                            background: C.brown,
                            borderRadius: 8,
                            padding: '8px 10px',
                            flex: 1,
                          }}
                        >
                          <span style={{ fontSize: 14, flexShrink: 0 }}>{fam.emoji}</span>
                          <span
                            style={{
                              fontSize: 12.5,
                              fontWeight: 700,
                              color: '#F5F0E6',
                              flex: 1,
                              textAlign: 'left',
                            }}
                          >
                            {fam.name}
                          </span>
                          {stat.epuise > 0 && (
                            <span
                              style={{
                                fontSize: 10,
                                fontWeight: 800,
                                background: C.orange,
                                color: '#fff',
                                padding: '2px 7px',
                                borderRadius: 4,
                                flexShrink: 0,
                              }}
                            >
                              {stat.epuise} épuisé
                            </span>
                          )}
                        </div>
                      ) : (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1, padding: '8px 10px' }}>
                          <span style={{ fontSize: 13, flexShrink: 0 }}>{fam.emoji}</span>
                          <span style={{ fontSize: 12.5, fontWeight: 500, color: C.ink, flex: 1, textAlign: 'left' }}>
                            {fam.name}
                          </span>
                          {stat.epuise > 0 ? (
                            <span
                              style={{
                                fontSize: 10,
                                fontWeight: 700,
                                background: '#FEF0E0',
                                color: C.orange,
                                padding: '2px 7px',
                                borderRadius: 4,
                                flexShrink: 0,
                              }}
                            >
                              {stat.epuise} épuisé
                            </span>
                          ) : stat.total > 0 ? (
                            <span style={{ fontSize: 11, color: C.muted, flexShrink: 0 }}>Tous dispo</span>
                          ) : null}
                        </div>
                      )}
                    </button>
                    {/* Pencil icon on hover for admin */}
                    {hoveredFam === fam._id && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setFamModal({ family: fam });
                        }}
                        title="Modifier la famille"
                        style={{
                          position: 'absolute',
                          right: 14,
                          top: '50%',
                          transform: 'translateY(-50%)',
                          background: C.cardBg,
                          border: `1px solid ${C.border}`,
                          borderRadius: 6,
                          width: 26,
                          height: 26,
                          display: 'inline-flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: 'pointer',
                          fontSize: 13,
                          color: C.muted,
                          lineHeight: 1,
                        }}
                      >
                        ✎
                      </button>
                    )}
                  </div>
                );
              })}
            </div>

            {/* Sidebar bottom */}
            <div style={{ padding: '8px 12px 6px', borderTop: `1px solid ${C.border}` }}>
              <button
                onClick={() => setFamModal({})}
                style={{
                  width: '100%',
                  padding: '7px 10px',
                  borderRadius: 7,
                  border: 'none',
                  background: 'transparent',
                  fontSize: 12.5,
                  fontWeight: 600,
                  cursor: 'pointer',
                  fontFamily: 'inherit',
                  color: C.muted,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 5,
                }}
              >
                <span style={{ fontSize: 15, lineHeight: 1 }}>+</span> Nouvelle famille
              </button>
            </div>
          </aside>
        )}

        {/* ── Mobile family tabs ── */}
        {mobile && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              overflowX: 'auto',
              flexWrap: 'nowrap',
              paddingBottom: 4,
              width: '100%',
              scrollbarWidth: 'none',
              msOverflowStyle: 'none',
              WebkitOverflowScrolling: 'touch',
            }}
          >
            {loadingFams && families.length === 0 && (
              <span style={{ fontSize: 12, color: C.muted, padding: '6px 12px' }}>Chargement…</span>
            )}
            {families.map((fam) => {
              const active = fam.slug === activeFamily;
              const stat = statFor(fam.slug);
              return (
                <button
                  key={fam._id}
                  onClick={() => {
                    setActiveFamily(fam.slug);
                    setSearch('');
                  }}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 5,
                    padding: '6px 12px',
                    borderRadius: 20,
                    fontSize: 12,
                    fontWeight: 700,
                    cursor: 'pointer',
                    fontFamily: 'inherit',
                    flexShrink: 0,
                    whiteSpace: 'nowrap',
                    background: active ? C.brown : C.cardBg,
                    color: active ? '#F5F0E6' : C.ink,
                    border: active ? 'none' : `1px solid ${C.border}`,
                  }}
                >
                  <span>{fam.emoji}</span>
                  {(fam.name || '').split(' ')[0]}
                  {stat.epuise > 0 && (
                    <span
                      style={{
                        fontSize: 9,
                        fontWeight: 800,
                        background: C.orange,
                        color: '#fff',
                        padding: '1px 5px',
                        borderRadius: 3,
                        flexShrink: 0,
                      }}
                    >
                      {stat.epuise}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        )}

        {/* ── RIGHT PANEL ── */}
        <div
          style={{
            flex: 1,
            minWidth: 0,
            background: C.cardBg,
            border: `1px solid ${C.border}`,
            borderRadius: 12,
            overflow: 'hidden',
          }}
        >
          {/* Panel header */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '16px 20px',
              borderBottom: `1px solid ${C.border}`,
              flexWrap: 'wrap',
              gap: 10,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 20 }}>{activeFamilyObj?.emoji || '📦'}</span>
              <h2
                style={{
                  margin: 0,
                  fontFamily: FONT_TITLE,
                  fontSize: mobile ? 20 : 24,
                  fontWeight: 400,
                  color: C.ink,
                  letterSpacing: '0.5px',
                }}
              >
                {activeFamilyObj?.name || (loadingFams ? 'Chargement…' : '—')}
              </h2>
              {!loadingIngs && filtered.length > 0 && (
                <span style={{ fontSize: 12, color: C.muted }}>
                  <span style={{ color: C.green, fontWeight: 600 }}>{dispoCnt} disponibles</span>
                  {epuiseCnt > 0 && (
                    <>
                      {' '}
                      · <span style={{ color: C.red, fontWeight: 600 }}>{epuiseCnt} épuisés</span>
                    </>
                  )}
                </span>
              )}
            </div>
            {!mobile && (
              <span style={{ fontSize: 11.5, color: C.muted }}>
                Action rapide : Touchez le toggle pour basculer
              </span>
            )}
          </div>

          {/* Loader */}
          {loadingIngs && (
            <div style={{ padding: '60px 0', textAlign: 'center' }}>
              <div
                style={{
                  display: 'inline-block',
                  width: 28,
                  height: 28,
                  borderRadius: '50%',
                  border: `3px solid ${C.border}`,
                  borderTopColor: C.brown,
                  animation: 'spin 0.7s linear infinite',
                }}
              />
            </div>
          )}

          {/* Empty */}
          {!loadingIngs && filtered.length === 0 && (
            <div style={{ padding: '50px 0', textAlign: 'center' }}>
              <div style={{ fontSize: 32, marginBottom: 10 }}>{activeFamilyObj?.emoji}</div>
              <div style={{ fontSize: 14, color: C.muted, marginBottom: 6 }}>
                {search ? `Aucun ingrédient pour "${search}"` : 'Aucun ingrédient dans cette famille'}
              </div>
              {!search && (
                <div style={{ fontSize: 12, color: C.muted }}>
                  Cliquez sur "Ajouter un ingrédient" pour commencer
                </div>
              )}
            </div>
          )}

          {/* Ingredient rows */}
          {!loadingIngs &&
            filtered.map((ingredient, i) => {
              const epuise = isEpuise(ingredient);
              const bloque = isBloque(ingredient);

              /* ── MOBILE card ── */
              if (mobile)
                return (
                  <div
                    key={ingredient._id}
                    style={{
                      padding: '14px 16px',
                      background: epuise ? '#FDF7F6' : C.cardBg,
                      borderBottom: i < filtered.length - 1 ? `1px solid ${C.border}` : 'none',
                      borderLeft: epuise ? `3px solid ${C.red}` : '3px solid transparent',
                    }}
                  >
                    {/* Row 1: name + status pill */}
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'flex-start',
                        justifyContent: 'space-between',
                        gap: 8,
                        marginBottom: 4,
                      }}
                    >
                      <div
                        style={{
                          fontSize: 14,
                          fontWeight: 700,
                          color: epuise ? C.ink : C.ink,
                          textDecoration: epuise ? 'line-through' : 'none',
                          textDecorationColor: '#B5A9A2',
                          flex: 1,
                        }}
                      >
                        {ingredient.name}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexShrink: 0 }}>
                        <span
                          style={{
                            fontSize: 9.5,
                            fontWeight: 800,
                            letterSpacing: '0.04em',
                            padding: '3px 8px',
                            borderRadius: 5,
                            background: epuise ? '#FDEAE8' : '#E8F8EF',
                            color: epuise ? C.red : C.greenText,
                          }}
                        >
                          {epuise ? '86 ACTIF' : 'En vente'}
                        </span>
                        <button
                          onClick={() => setIngModal({ ingredient })}
                          style={{
                            background: 'transparent',
                            border: 'none',
                            cursor: 'pointer',
                            fontSize: 14,
                            color: C.muted,
                            padding: '2px 4px',
                            lineHeight: 1,
                          }}
                        >
                          ✎
                        </button>
                      </div>
                    </div>

                    {/* Row 2: unit / notes */}
                    {(ingredient.unit || ingredient.notes) && (
                      <div style={{ fontSize: 12, color: C.muted, marginBottom: epuise ? 6 : 10 }}>
                        {ingredient.unit && `Unité : ${ingredient.unit}`}
                        {ingredient.unit && ingredient.notes && ' · '}
                        {ingredient.notes}
                      </div>
                    )}

                    {/* Row 3: warning (épuisé only) */}
                    {epuise && (
                      <div style={{ marginBottom: 10 }}>
                        {bloque ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                            <span style={{ fontSize: 12, fontWeight: 700, color: C.red }}>Bloqué Caisse &amp; Bne</span>
                            <span style={{ fontSize: 11, color: C.muted }}>· Ingrédient bloqué</span>
                          </div>
                        ) : (
                          <div
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 5,
                              background: '#FEF0E0',
                              borderRadius: 6,
                              padding: '4px 10px',
                            }}
                          >
                            <span style={{ fontSize: 12 }}>⚠</span>
                            <span style={{ fontSize: 11.5, color: C.orange, fontWeight: 600 }}>
                              {ingredient.notes || 'Rupture de stock'}
                            </span>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Row 4: full-width toggle button */}
                    <MobileToggleBtn ingredient={ingredient} onToggle={handleToggle} toggling={toggling} />
                  </div>
                );

              /* ── DESKTOP row ── */
              return (
                <div
                  key={ingredient._id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 14,
                    padding: '14px 20px',
                    background: epuise ? '#FDF7F6' : C.cardBg,
                    borderBottom: i < filtered.length - 1 ? `1px solid ${C.border}` : 'none',
                  }}
                >
                  <Circle
                    size={9}
                    fill={epuise ? '#D93025' : '#B5B0A8'}
                    color={epuise ? '#D93025' : '#B5B0A8'}
                    style={{ flexShrink: 0 }}
                  />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div
                      style={{
                        fontSize: 14,
                        fontWeight: 700,
                        color: epuise ? '#A8978F' : C.ink,
                        textDecoration: epuise ? 'line-through' : 'none',
                        textDecorationColor: '#B5A9A2',
                        marginBottom: 2,
                      }}
                    >
                      {ingredient.name}
                    </div>
                    {ingredient.unit && (
                      <div style={{ fontSize: 12, color: C.muted }}>
                        Unité : {ingredient.unit}
                        {ingredient.notes && ` · ${ingredient.notes}`}
                      </div>
                    )}
                  </div>
                  {epuise && (
                    <div style={{ flexShrink: 0, textAlign: 'right', minWidth: 140 }}>
                      {bloque ? (
                        <>
                          <div style={{ fontSize: 12, fontWeight: 700, color: C.red }}>Bloqué Caisse &amp; Bne</div>
                          <div style={{ fontSize: 11, color: C.muted }}>Ingrédient bloqué</div>
                        </>
                      ) : (
                        <div style={{ fontSize: 11, color: C.muted }}>{ingredient.notes || 'Rupture de stock'}</div>
                      )}
                    </div>
                  )}
                  <button
                    onClick={() => setIngModal({ ingredient })}
                    title="Modifier"
                    style={{
                      flexShrink: 0,
                      background: C.cardBg,
                      border: `1px solid ${C.border}`,
                      borderRadius: 6,
                      width: 30,
                      height: 30,
                      display: 'inline-flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      cursor: 'pointer',
                      fontSize: 14,
                      color: C.muted,
                      lineHeight: 1,
                    }}
                  >
                    ✎
                  </button>
                  <ToggleBtn ingredient={ingredient} onToggle={handleToggle} toggling={toggling} />
                </div>
              );
            })}
        </div>
      </div>

      {/* Mobile bulk button */}
      {mobile && (
        <div style={{ padding: '0 14px 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          <button
            onClick={() => setIngModal({ ingredient: null })}
            style={{
              width: '100%',
              padding: '12px',
              borderRadius: 10,
              border: 'none',
              background: C.yellow,
              fontSize: 13,
              fontWeight: 700,
              cursor: 'pointer',
              fontFamily: 'inherit',
              color: '#1F2937',
            }}
          >
            + Ajouter un ingrédient
          </button>
        </div>
      )}

      {/* FOOTER */}
      <footer
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: mobile ? '11px 14px' : '13px 28px',
          borderTop: `1px solid ${C.border}`,
          background: C.cardBg,
          flexShrink: 0,
        }}
      >
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 600, color: C.ink }}>
          <Circle size={6} fill={C.green} color={C.green} /> Connecté
        </span>
        <span style={{ fontSize: 11.5, color: C.muted }}>Bobo's OS v1.00</span>
      </footer>

      {/* ── MODALS ── */}
      {ingModal && (
        <IngredientModal
          ingredient={ingModal.ingredient || null}
          ingredients={ingredients}
          families={families}
          defaultFamily={activeFamily}
          mobile={mobile}
          onClose={() => setIngModal(null)}
          onSaved={handleIngSaved}
          onDeleted={handleIngDeleted}
        />
      )}
      {famModal && (
        <FamilyModal
          family={famModal.family || null}
          families={families}
          mobile={mobile}
          onClose={() => setFamModal(null)}
          onSaved={handleFamSaved}
          onDeleted={handleFamDeleted}
        />
      )}

      <style>{`
        @keyframes spin { to { transform: rotate(360deg); } }
        .sk-fam-tabs::-webkit-scrollbar { display: none; }
      `}</style>
    </div>
  );
}
