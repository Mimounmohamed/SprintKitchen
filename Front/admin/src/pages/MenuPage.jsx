import React, { useEffect, useState, useCallback, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, Search, Plus, Pencil, Trash2, Settings, Circle, X, ChevronDown } from "lucide-react";
import { productService, categoryService } from "../services";

const C = {
  bg: "#F5F4F0", cardBg: "#FFFFFF", ink: "#1C1917", brown: "#2E2117",
  yellow: "#F2B705", muted: "#8B8378", border: "#E7E4DD", green: "#2FAE5C",
  red: "#E0533D", redBg: "#FBEAE7", yellowBg: "#FCEFCB",
};

/* ── Toggle ─────────────────────────────────────────────────────────────────── */
function Toggle({ checked, onChange }) {
  return (
    <div onClick={onChange} style={{
      width: 44, height: 24, borderRadius: 999,
      background: checked ? C.green : "#D1D0CC",
      position: "relative", cursor: "pointer", transition: "background .2s", flexShrink: 0,
    }}>
      <div style={{
        position: "absolute", top: 3,
        left: checked ? "calc(100% - 21px)" : 3,
        width: 18, height: 18, borderRadius: "50%",
        background: "#fff", boxShadow: "0 1px 3px rgba(0,0,0,.2)",
        transition: "left .2s",
      }} />
    </div>
  );
}

/* ── Section header ─────────────────────────────────────────────────────────── */
function Section({ num, title, right }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
      <span style={{ fontSize: 12, fontWeight: 800, letterSpacing: "0.06em", color: C.ink }}>
        {num}. {title}
      </span>
      {right && <span style={{ fontSize: 12, fontWeight: 600, color: C.muted }}>{right}</span>}
    </div>
  );
}

/* ── Field wrapper ──────────────────────────────────────────────────────────── */
function Field({ label, hint, required, children }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
        <label style={{ fontSize: 12.5, fontWeight: 600, color: C.ink }}>
          {label}{required && <span style={{ color: C.red, marginLeft: 3 }}>*</span>}
        </label>
        {hint && <span style={{ fontSize: 11, color: C.muted }}>{hint}</span>}
      </div>
      {children}
    </div>
  );
}

const inputStyle = {
  width: "100%", padding: "10px 14px",
  border: `1px solid ${C.border}`, borderRadius: 8,
  fontSize: 13.5, outline: "none", fontFamily: "inherit",
  color: C.ink, background: C.cardBg,
};

/* ── Ingredient tag input ────────────────────────────────────────────────────
   Type a name then press Enter or comma → adds tag.
   Click × on a tag to remove it.
   Stored as an array of strings.
─────────────────────────────────────────────────────────────────────────────── */
function IngredientTags({ tags, onChange }) {
  const [input, setInput] = useState("");
  const inputRef = useRef();

  const add = () => {
    const val = input.trim().replace(/,$/, "").trim();
    if (val && !tags.includes(val)) onChange([...tags, val]);
    setInput("");
  };

  const handleKey = (e) => {
    if (e.key === "Enter" || e.key === ",") { e.preventDefault(); add(); }
    if (e.key === "Backspace" && input === "" && tags.length) {
      onChange(tags.slice(0, -1));
    }
  };

  const remove = (t) => onChange(tags.filter(x => x !== t));

  return (
    <div
      onClick={() => inputRef.current?.focus()}
      style={{
        minHeight: 48, padding: "6px 10px",
        border: `1px solid ${C.border}`, borderRadius: 8,
        display: "flex", flexWrap: "wrap", gap: 6, alignItems: "center",
        cursor: "text", background: C.cardBg,
      }}
    >
      {tags.map(t => (
        <span key={t} style={{
          display: "inline-flex", alignItems: "center", gap: 5,
          background: "#F1EDE7", color: "#583926",
          fontSize: 12, fontWeight: 600, padding: "4px 9px", borderRadius: 6,
        }}>
          {t}
          <button onClick={e => { e.stopPropagation(); remove(t); }} style={{
            background: "none", border: "none", cursor: "pointer",
            padding: 0, color: C.muted, display: "flex", lineHeight: 1,
          }}>
            <X size={11} />
          </button>
        </span>
      ))}
      <input
        ref={inputRef}
        value={input}
        onChange={e => setInput(e.target.value)}
        onKeyDown={handleKey}
        onBlur={add}
        placeholder={tags.length === 0 ? "Steak haché, Cheddar, Bacon… (Entrée pour valider)" : ""}
        style={{
          border: "none", outline: "none", fontSize: 13, fontFamily: "inherit",
          background: "transparent", flex: 1, minWidth: 120, color: C.ink,
        }}
      />
    </div>
  );
}

/* ── Side Drawer ─────────────────────────────────────────────────────────────── */
function ArticleDrawer({ product, categories, onClose, onSave }) {
  const isEdit = !!product;
  const [form, setForm] = useState({
    name:         product?.name         || "",
    description:  product?.description  || "",
    categoryId:   product?.categoryId?._id || product?.categoryId || "",
    basePrice:    product?.basePrice    || "",
    availability: product?.availability || "available",
    ingredients:  product?.ingredients  || [],
  });
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState("");

  const set = (key, val) => setForm(p => ({ ...p, [key]: val }));

  const handleSave = async () => {
    if (!form.name || !form.categoryId || form.basePrice === "") {
      setError("Nom, catégorie et prix sont obligatoires."); return;
    }
    setSaving(true); setError("");
    try {
      if (isEdit) await productService.update(product._id, form);
      else        await productService.create(form);
      onSave();
    } catch (e) {
      setError(e.response?.data?.message || "Erreur lors de la sauvegarde.");
    } finally { setSaving(false); }
  };

  return (
    <>
      {/* Overlay */}
      <div onClick={onClose} style={{
        position: "fixed", inset: 0, background: "rgba(28,25,23,.45)",
        zIndex: 200, cursor: "pointer",
      }} />

      {/* Drawer */}
      <div style={{
        position: "fixed", top: 0, right: 0, bottom: 0,
        width: 520, background: C.cardBg,
        boxShadow: "-8px 0 40px rgba(0,0,0,.18)",
        zIndex: 201, display: "flex", flexDirection: "column",
        overflowY: "auto",
      }}>

        {/* ── Drawer header ── */}
        <div style={{ padding: "20px 28px 16px", background: "#FAF7F5", borderBottom: `1px solid ${C.border}` }}>
          {/* Top row */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Circle size={7} fill={C.green} color={C.green} />
              <span style={{
                color: "#583926",
                fontFamily: "'Open Sans', sans-serif",
                fontSize: 12,
                fontStyle: "normal",
                fontWeight: 600,
                lineHeight: "16px",
                letterSpacing: "0.6px",
                textTransform: "uppercase",
              }}>
                {isEdit ? "MODIFIER PRODUIT" : "NOUVEAU PRODUIT"} · DIRECT
              </span>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <span style={{ fontSize: 12.5, fontWeight: 600, color: C.ink }}>
                Statut : {form.availability === "available" ? "Actif" : "Inactif"}
              </span>
              <Toggle
                checked={form.availability === "available"}
                onChange={() => set("availability", form.availability === "available" ? "epuise" : "available")}
              />
            </div>
          </div>

          {/* Title */}
          <h2 style={{
            margin: "0 0 4px", fontFamily: "'Bebas Neue', sans-serif",
            fontSize: 40, fontWeight: 400, lineHeight: "40px", color: "#583926",
          }}>
            {isEdit ? "MODIFIER L'ARTICLE" : "CRÉER UN NOUVEL ARTICLE"}
          </h2>
          <p style={{ margin: "0 0 20px", fontSize: 13, color: C.muted, lineHeight: 1.5 }}>
            Remplissez les détails pour publier ce produit sur les caisses et bornes.
          </p>

        </div>

        {/* ── Scrollable body ── */}
        <div style={{ flex: 1, padding: "22.5px 28px 0", overflowY: "auto" }}>

          {error && (
            <div style={{ background: C.redBg, color: "#B23A26", padding: "10px 14px", borderRadius: 8, fontSize: 13, marginBottom: 16 }}>
              {error}
            </div>
          )}

          {/* ── 1. INFORMATIONS GÉNÉRALES ── */}
          <div style={{ marginBottom: 24 }}>
            <Section num="1" title="INFORMATIONS GÉNÉRALES" right="Obligatoire" />

            <Field label="Nom de l'article" required>
              <input
                value={form.name}
                onChange={e => set("name", e.target.value)}
                placeholder="Burger Smoky Bacon"
                style={inputStyle}
              />
            </Field>

            <Field label="Description & Note cuisine" hint="Visible sur le KDS">
              <textarea
                value={form.description}
                onChange={e => set("description", e.target.value)}
                rows={4}
                placeholder="Steak haché pur bœuf 150g, cheddar affiné, bacon fumé croustillant…"
                style={{ ...inputStyle, resize: "vertical", lineHeight: 1.55 }}
              />
            </Field>
          </div>

          {/* ── 2. CATÉGORIE & AFFICHAGE ── */}
          <div style={{ marginBottom: 24 }}>
            <Section num="2" title="CATÉGORIE & AFFICHAGE" right="+ Gérer les catégories" />

            <Field label="Catégorie de rattachement" required>
              <div style={{ position: "relative" }}>
                <select
                  value={form.categoryId}
                  onChange={e => set("categoryId", e.target.value)}
                  style={{ ...inputStyle, appearance: "none", paddingRight: 36, cursor: "pointer" }}
                >
                  <option value="">— Choisir une catégorie —</option>
                  {categories.map(c => <option key={c._id} value={c._id}>{c.name}</option>)}
                </select>
                <ChevronDown size={14} style={{ position: "absolute", right: 12, top: "50%", transform: "translateY(-50%)", color: C.muted, pointerEvents: "none" }} />
              </div>
            </Field>

            {/* ── Ingrédients ── */}
            <Field
              label="Ingrédients"
              hint="Appuyez sur Entrée pour valider chaque ingrédient"
            >
              <IngredientTags
                tags={form.ingredients}
                onChange={val => set("ingredients", val)}
              />
              {form.ingredients.length > 0 && (
                <p style={{ margin: "6px 0 0", fontSize: 11, color: C.muted }}>
                  {form.ingredients.length} ingrédient{form.ingredients.length > 1 ? "s" : ""} ajouté{form.ingredients.length > 1 ? "s" : ""}
                </p>
              )}
            </Field>
          </div>

          {/* ── 3. PRIX & OPTIONS ── */}
          <div style={{ marginBottom: 24 }}>
            <Section num="3" title="PRIX & OPTIONS" />

            <Field label="Prix (DA)" required>
              <div style={{ position: "relative" }}>
                <input
                  type="number"
                  value={form.basePrice}
                  onChange={e => set("basePrice", e.target.value)}
                  placeholder="0"
                  style={{ ...inputStyle, paddingRight: 52 }}
                />
                <span style={{
                  position: "absolute", right: 14, top: "50%", transform: "translateY(-50%)",
                  fontSize: 12, fontWeight: 700, color: C.muted,
                }}>DA</span>
              </div>
            </Field>
          </div>

        </div>

        {/* ── Footer ── */}
        <div style={{
          padding: "16px 28px", borderTop: `1px solid ${C.border}`,
          display: "flex", gap: 12,
        }}>
          <button onClick={onClose} style={{
            flex: 1, padding: "12px", borderRadius: 10,
            border: `1px solid ${C.border}`, background: C.cardBg,
            fontSize: 13.5, fontWeight: 600, cursor: "pointer", fontFamily: "inherit",
          }}>
            Annuler
          </button>
          <button onClick={handleSave} disabled={saving} style={{
            flex: 2, padding: "12px 20px", borderRadius: 10,
            border: "none", background: saving ? "#D1D0CC" : C.yellow,
            color: C.brown, fontSize: 13.5, fontWeight: 800,
            cursor: saving ? "not-allowed" : "pointer", fontFamily: "inherit",
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
            textTransform: "uppercase", letterSpacing: "0.03em",
          }}>
            {saving ? "Sauvegarde…" : `✓ ${isEdit ? "ENREGISTRER" : "CRÉER L'ARTICLE"}`}
          </button>
        </div>
      </div>
    </>
  );
}

/* ── Category Modal ──────────────────────────────────────────────────────────── */
function CategoryModal({ category, onClose, onSave }) {
  const isEdit = !!category;
  const [form, setForm] = useState({
    name:        category?.name        || "",
    description: category?.description || "",
    showOnPOS:   category?.showOnPOS !== false,
  });
  const [catProducts, setCatProducts] = useState([]);
  const [searchProd,  setSearchProd]  = useState("");
  const [searchRes,   setSearchRes]   = useState([]);
  const [saving, setSaving] = useState(false);
  const [error,  setError]  = useState("");

  useEffect(() => {
    if (!isEdit) return;
    productService.getAll({ categoryId: category._id, limit: 50 })
      .then(r => setCatProducts(r.data.data || [])).catch(() => {});
  }, [category]);

  useEffect(() => {
    if (!searchProd.trim()) { setSearchRes([]); return; }
    productService.getAll({ search: searchProd, limit: 8 })
      .then(r => setSearchRes((r.data.data || []).filter(p =>
        (p.categoryId?._id || p.categoryId) !== category?._id)))
      .catch(() => {});
  }, [searchProd]);

  const set = (k, v) => setForm(p => ({ ...p, [k]: v }));

  const handleSave = async () => {
    if (!form.name) { setError("Le nom est obligatoire."); return; }
    setSaving(true); setError("");
    try {
      if (isEdit) await categoryService.update(category._id, form);
      else        await categoryService.create(form);
      onSave();
    } catch (e) {
      setError(e.response?.data?.message || "Erreur lors de la sauvegarde.");
    } finally { setSaving(false); }
  };

  const addProduct = async (p) => {
    await productService.update(p._id, { categoryId: category._id });
    setCatProducts(prev => [...prev, { ...p, categoryId: category._id }]);
    setSearchProd(""); setSearchRes([]);
  };

  const removeProduct = async (p) => {
    await productService.update(p._id, { categoryId: null });
    setCatProducts(prev => prev.filter(x => x._id !== p._id));
  };

  return (
    <div onClick={e => e.target === e.currentTarget && onClose()}
      style={{ position:"fixed",inset:0,background:"rgba(28,25,23,.5)",zIndex:300,display:"flex",alignItems:"center",justifyContent:"center",padding:20 }}>
      <div style={{ background:C.cardBg,borderRadius:16,width:"100%",maxWidth:520,maxHeight:"90vh",display:"flex",flexDirection:"column",boxShadow:"0 24px 80px rgba(0,0,0,.28)" }}>

        {/* top bar */}
        <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"16px 24px 0" }}>
          <button onClick={onClose} style={{ background:"none",border:"none",cursor:"pointer",fontSize:13,fontWeight:600,color:C.muted,fontFamily:"inherit",display:"flex",alignItems:"center",gap:5 }}>
            ← Retour aux catégories
          </button>
          <button onClick={onClose} style={{ background:"#F1F0EC",border:"none",cursor:"pointer",fontSize:12,fontWeight:600,color:C.muted,fontFamily:"inherit",padding:"5px 10px",borderRadius:7 }}>
            Fermer [ECHAP]
          </button>
        </div>

        {/* header */}
        <div style={{ padding:"12px 24px 16px",borderBottom:`1px solid ${C.border}` }}>
          <div style={{ display:"flex",alignItems:"center",gap:10,marginBottom:4,flexWrap:"wrap" }}>
            <Circle size={8} fill={C.yellow} color={C.yellow} />
            <h2 style={{ margin:0,fontFamily:"'Bebas Neue',sans-serif",fontSize:32,fontWeight:400,color:"#583926",lineHeight:1 }}>
              {isEdit ? "MODIFIER LA CATÉGORIE" : "CRÉER UNE CATÉGORIE"}
            </h2>
            {isEdit && catProducts.length > 0 && (
              <span style={{ fontSize:12,fontWeight:600,color:C.muted,background:"#F1F0EC",padding:"4px 10px",borderRadius:999 }}>
                {catProducts.length} articles associés
              </span>
            )}
          </div>
          <p style={{ margin:0,fontSize:13,color:C.muted }}>
            Configurez l'intitulé, le rayon d'attribution et le code couleur sur la caisse.
          </p>
        </div>

        {/* scrollable body */}
        <div style={{ flex:1,overflowY:"auto",padding:"20px 24px" }}>
          {error && <div style={{ background:C.redBg,color:"#B23A26",padding:"10px 14px",borderRadius:8,fontSize:13,marginBottom:16 }}>{error}</div>}

          {/* 1. Informations du rayon */}
          <div style={{ marginBottom:20 }}>
            <div style={{ fontSize:10.5,fontWeight:700,letterSpacing:"0.08em",color:C.muted,textTransform:"uppercase",marginBottom:14,paddingBottom:8,borderBottom:`1px solid ${C.border}` }}>
              1. Informations du rayon
            </div>
            <div style={{ marginBottom:14 }}>
              <label style={{ display:"block",fontSize:12,fontWeight:700,color:C.ink,letterSpacing:"0.04em",textTransform:"uppercase",marginBottom:6 }}>
                Nom de la catégorie <span style={{ color:C.red }}>*</span>
              </label>
              <input value={form.name} onChange={e=>set("name",e.target.value)}
                placeholder="Ex: Menus B"
                style={{ ...inputStyle,width:"100%" }} />
            </div>
            <div>
              <label style={{ display:"block",fontSize:12,fontWeight:700,color:C.ink,letterSpacing:"0.04em",textTransform:"uppercase",marginBottom:6 }}>
                Description courte & note d'affichage
              </label>
              <input value={form.description} onChange={e=>set("description",e.target.value)}
                placeholder="Rayon principal caisse…"
                style={{ ...inputStyle,width:"100%" }} />
              <p style={{ margin:"6px 0 0",fontSize:11,color:C.muted }}>
                ⓘ Apparaît sous le libellé de catégorie sur la caisse et le KDS.
              </p>
            </div>
          </div>

          {/* 2. Affichage & visibilité POS */}
          <div style={{ marginBottom:20 }}>
            <div style={{ fontSize:10.5,fontWeight:700,letterSpacing:"0.08em",color:C.muted,textTransform:"uppercase",marginBottom:14,paddingBottom:8,borderBottom:`1px solid ${C.border}` }}>
              2. Affichage & visibilité POS
            </div>
            <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",gap:16,padding:"14px 16px",background:"#F9F8F6",borderRadius:10 }}>
              <div>
                <div style={{ fontSize:14,fontWeight:700,color:C.ink,display:"flex",alignItems:"center",gap:6 }}>
                  Afficher sur la caisse (POS)
                  <Circle size={7} fill={form.showOnPOS?C.green:C.muted} color={form.showOnPOS?C.green:C.muted} />
                </div>
                <div style={{ fontSize:12,color:C.muted,marginTop:3 }}>
                  Visible par les caissiers et synchronisé instantanément avec les bornes de commande.
                </div>
              </div>
              <Toggle checked={form.showOnPOS} onChange={() => set("showOnPOS", !form.showOnPOS)} />
            </div>
          </div>

          {/* 3. Articles associés — edit only */}
          {isEdit && (
            <div>
              <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:14,paddingBottom:8,borderBottom:`1px solid ${C.border}` }}>
                <span style={{ fontSize:10.5,fontWeight:700,letterSpacing:"0.08em",color:C.muted,textTransform:"uppercase" }}>
                  3. Articles associés
                </span>
                <span style={{ fontSize:12,fontWeight:600,color:C.muted,background:"#F1F0EC",padding:"3px 9px",borderRadius:999 }}>
                  {catProducts.length} articles rattachés
                </span>
              </div>

              <div style={{ display:"flex",gap:8,marginBottom:10 }}>
                <div style={{ position:"relative",flex:1 }}>
                  <Search size={13} style={{ position:"absolute",left:10,top:"50%",transform:"translateY(-50%)",color:C.muted,pointerEvents:"none" }} />
                  <input value={searchProd} onChange={e=>setSearchProd(e.target.value)}
                    placeholder="Rechercher et ajouter un article à cette catégorie..."
                    style={{ ...inputStyle,width:"100%",paddingLeft:30,fontSize:12.5 }} />
                </div>
                <button style={{ padding:"8px 14px",background:C.yellow,color:C.brown,border:"none",borderRadius:8,fontWeight:700,fontSize:12,cursor:"pointer",fontFamily:"inherit",whiteSpace:"nowrap" }}>
                  + Ajouter
                </button>
              </div>

              {searchRes.length > 0 && (
                <div style={{ background:C.cardBg,border:`1px solid ${C.border}`,borderRadius:8,marginBottom:10,overflow:"hidden" }}>
                  {searchRes.map(p => (
                    <div key={p._id} onClick={() => addProduct(p)}
                      style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"10px 14px",cursor:"pointer",borderBottom:`1px solid ${C.border}`,fontSize:13 }}
                      onMouseEnter={e=>e.currentTarget.style.background="#F9F8F6"}
                      onMouseLeave={e=>e.currentTarget.style.background="transparent"}>
                      <span>{p.name}</span>
                      <span style={{ color:C.green,fontWeight:600,fontSize:12 }}>+ Ajouter</span>
                    </div>
                  ))}
                </div>
              )}

              {catProducts.map(p => (
                <div key={p._id} style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"11px 14px",background:"#F9F8F6",borderRadius:8,marginBottom:6,fontSize:13.5 }}>
                  <div style={{ display:"flex",alignItems:"center",gap:8 }}>
                    <Circle size={7} fill={C.green} color={C.green} />
                    <span style={{ fontWeight:500 }}>{p.name}</span>
                  </div>
                  <div style={{ display:"flex",alignItems:"center",gap:12 }}>
                    <span style={{ fontWeight:600,color:C.muted }}>{p.basePrice?.toLocaleString("fr-DZ")} DA</span>
                    <button onClick={()=>removeProduct(p)} style={{ background:"none",border:"none",cursor:"pointer",color:C.muted,padding:2 }}><X size={14} /></button>
                  </div>
                </div>
              ))}

              {catProducts.length === 0 && !searchProd && (
                <div style={{ textAlign:"center",padding:"20px 0",color:C.muted,fontSize:13 }}>Aucun article dans cette catégorie</div>
              )}
            </div>
          )}
        </div>

        {/* footer */}
        <div style={{ padding:"16px 24px",borderTop:`1px solid ${C.border}`,display:"flex",gap:10 }}>
          <button onClick={onClose} style={{ flex:1,padding:"11px",borderRadius:9,border:`1px solid ${C.border}`,background:C.cardBg,fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit" }}>
            Annuler
          </button>
          <button onClick={handleSave} disabled={saving} style={{ flex:2,padding:"11px 20px",borderRadius:9,border:"none",background:saving?"#D1D0CC":C.yellow,color:C.brown,fontSize:13,fontWeight:800,cursor:saving?"not-allowed":"pointer",fontFamily:"inherit",textTransform:"uppercase",letterSpacing:"0.03em" }}>
            {saving ? "Sauvegarde…" : `✓ ${isEdit ? "ENREGISTRER" : "CRÉER LA CATÉGORIE"}`}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ── Gérer Modal ─────────────────────────────────────────────────────────────── */
function GererModal({ categories, onClose, onEdit, onRefresh }) {
  const [deleting, setDeleting] = useState(null);

  const handleDelete = async (id) => {
    if (!confirm("Supprimer cette catégorie ?")) return;
    setDeleting(id);
    try { await categoryService.delete(id); onRefresh(); }
    catch (e) { alert(e.response?.data?.message || "Erreur."); }
    finally { setDeleting(null); }
  };

  return (
    <div onClick={e => e.target === e.currentTarget && onClose()}
      style={{ position:"fixed",inset:0,background:"rgba(28,25,23,.5)",zIndex:300,display:"flex",alignItems:"center",justifyContent:"center",padding:20 }}>
      <div style={{ background:C.cardBg,borderRadius:16,width:"100%",maxWidth:480,maxHeight:"80vh",display:"flex",flexDirection:"column",boxShadow:"0 24px 80px rgba(0,0,0,.28)" }}>
        <div style={{ padding:"20px 24px 16px",borderBottom:`1px solid ${C.border}`,display:"flex",alignItems:"center",justifyContent:"space-between" }}>
          <h2 style={{ margin:0,fontFamily:"'Bebas Neue',sans-serif",fontSize:28,fontWeight:400,color:"#583926" }}>
            GÉRER LES CATÉGORIES
          </h2>
          <button onClick={onClose} style={{ background:"#F1F0EC",border:"none",cursor:"pointer",fontSize:12,fontWeight:600,color:C.muted,fontFamily:"inherit",padding:"5px 10px",borderRadius:7 }}>
            Fermer
          </button>
        </div>
        <div style={{ flex:1,overflowY:"auto",padding:"14px 24px 20px" }}>
          {categories.length === 0 && <p style={{ color:C.muted,textAlign:"center",padding:"20px 0" }}>Aucune catégorie</p>}
          {categories.map(cat => (
            <div key={cat._id} style={{ display:"flex",alignItems:"center",justifyContent:"space-between",padding:"12px 14px",background:"#F9F8F6",borderRadius:9,marginBottom:8 }}>
              <div>
                <div style={{ fontSize:14,fontWeight:700,color:C.ink }}>{cat.name}</div>
                {cat.description && <div style={{ fontSize:12,color:C.muted,marginTop:2 }}>{cat.description}</div>}
              </div>
              <div style={{ display:"flex",gap:8 }}>
                <button onClick={() => { onClose(); onEdit(cat); }}
                  style={{ padding:"6px 13px",background:C.yellow,color:C.brown,border:"none",borderRadius:7,fontSize:12,fontWeight:700,cursor:"pointer",fontFamily:"inherit" }}>
                  Modifier
                </button>
                <button onClick={() => handleDelete(cat._id)} disabled={deleting===cat._id}
                  style={{ padding:"6px 10px",background:"none",color:C.red,border:`1px solid ${C.border}`,borderRadius:7,fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit" }}>
                  <Trash2 size={13} />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ── Page ──────────────────────────────────────────────────────────────────── */
export default function MenuPage() {
  const navigate = useNavigate();
  const [products,   setProducts]   = useState([]);
  const [categories, setCategories] = useState([]);
  const [activeCat,  setActiveCat]  = useState("");
  const [search,     setSearch]     = useState("");
  const [page,       setPage]       = useState(1);
  const [total,      setTotal]      = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [loading,    setLoading]    = useState(true);
  const [drawer,     setDrawer]     = useState(null);
  const [catModal,   setCatModal]   = useState(null); // null | "new" | category obj
  const [gererOpen,  setGererOpen]  = useState(false);

  const LIMIT = 7;

  const fetchCategories = useCallback(() => {
    categoryService.getAll().then(r => setCategories(r.data.data || [])).catch(() => {});
  }, []);

  useEffect(() => { fetchCategories(); }, [fetchCategories]);

  const fetchProducts = useCallback(async () => {
    setLoading(true);
    try {
      const res = await productService.getAll({
        categoryId: activeCat || undefined,
        search:     search    || undefined,
        page, limit: LIMIT,
      });
      setProducts(res.data.data || []);
      setTotal(res.data.total || 0);
      setTotalPages(res.data.totalPages || 1);
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, [activeCat, search, page]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const toggleAvail = async (product) => {
    const next = product.availability === "available" ? "epuise" : "available";
    await productService.setAvailability(product._id, next);
    setProducts(prev => prev.map(p => p._id === product._id ? { ...p, availability: next } : p));
  };

  const handleDelete = async (id) => {
    if (!confirm("Désactiver cet article ?")) return;
    await productService.delete(id);
    fetchProducts();
  };

  return (
    <div style={{
      minHeight: "100vh", background: C.bg,
      fontFamily: "'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",
      color: C.ink, display: "flex", flexDirection: "column",
    }}>

      {/* ── Header ── */}
      <header style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "18px 40px", borderBottom: `1px solid ${C.border}`,
        background: C.cardBg, flexShrink: 0,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 38, height: 38, borderRadius: 9, background: C.brown, color: C.yellow, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="3" y="3" width="18" height="18" rx="2"/><line x1="7" y1="8" x2="17" y2="8"/><line x1="7" y1="12" x2="17" y2="12"/><line x1="7" y1="16" x2="11" y2="16"/>
            </svg>
          </div>
          <span style={{ fontSize: 17, fontWeight: 800, letterSpacing: "0.02em" }}>SPRINTKITCHEN</span>
          <span style={{ background: C.brown, color: "#F5F0E6", fontSize: 10, fontWeight: 700, padding: "3px 8px", borderRadius: 5 }}>HUB</span>
          <Circle size={7} fill={C.yellow} color={C.yellow} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 12, fontWeight: 600, padding: "6px 13px", borderRadius: 999, background: "#F1F0EC", color: C.ink }}>
            <Circle size={6} fill={C.green} color={C.green} />
            Super Admin — Back-Office
          </span>
          <div style={{ width: 34, height: 34, borderRadius: "50%", background: C.brown, color: C.yellow, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12, fontWeight: 800 }}>
            AD
          </div>
        </div>
      </header>

      {/* ── Main ── */}
      <main style={{ flex: 1, padding: "32px 40px 40px" }}>

        <button onClick={() => navigate("/")} style={{
          display: "inline-flex", alignItems: "center", gap: 6,
          background: "none", border: "none", cursor: "pointer",
          fontSize: 13, fontWeight: 600, color: C.muted, marginBottom: 12,
          fontFamily: "inherit", padding: 0,
        }}>
          <ArrowLeft size={14} /> Retour au Hub
        </button>

        <h1 style={{
          margin: "0 0 6px", color: "#583926",
          fontFamily: "'Bebas Neue', sans-serif",
          fontSize: 48, fontWeight: 400, lineHeight: "48px",
        }}>
          GESTION DU MENU & CATALOGUE
        </h1>
        <p style={{ margin: "0 0 24px", color: C.muted, fontSize: 14 }}>
          Ajoutez, modifiez ou désactivez les articles de votre carte en temps réel.
        </p>

        {/* Search + New article */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16, marginBottom: 20 }}>
          <div style={{ position: "relative", width: 320 }}>
            <Search size={14} style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)", color: C.muted, pointerEvents: "none" }} />
            <input
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
              placeholder="Rechercher un article..."
              style={{ width: "100%", padding: "10px 12px 10px 36px", border: `1px solid ${C.border}`, borderRadius: 10, fontSize: 13, outline: "none", background: C.cardBg, fontFamily: "inherit", color: C.ink }}
            />
          </div>
          <button onClick={() => setDrawer("new")} style={{
            display: "flex", alignItems: "center", gap: 8,
            padding: "10px 20px", borderRadius: 10, border: "none",
            background: C.yellow, color: C.brown,
            fontSize: 13, fontWeight: 800, letterSpacing: "0.03em",
            textTransform: "uppercase", cursor: "pointer", fontFamily: "inherit",
          }}>
            <Plus size={15} strokeWidth={2.5} /> NOUVEL ARTICLE
          </button>
        </div>

        {/* Category tabs */}
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 20, flexWrap: "wrap" }}>
          <button onClick={() => { setActiveCat(""); setPage(1); }} style={{
            padding: "7px 14px", borderRadius: 20, fontSize: 13, fontWeight: 600, cursor: "pointer",
            fontFamily: "inherit",
            background: activeCat === "" ? C.brown : C.cardBg,
            color:      activeCat === "" ? "#F5F0E6" : C.ink,
            border:     activeCat === "" ? "none" : `1px solid ${C.border}`,
          }}>
            Tous ({total})
          </button>
          {categories.map(cat => (
            <button key={cat._id} onClick={() => { setActiveCat(cat._id); setPage(1); }} style={{
              padding: "7px 14px", borderRadius: 20, fontSize: 13, fontWeight: 600, cursor: "pointer",
              fontFamily: "inherit",
              background: activeCat === cat._id ? C.brown : C.cardBg,
              color:      activeCat === cat._id ? "#F5F0E6" : C.ink,
              border:     activeCat === cat._id ? "none" : `1px solid ${C.border}`,
            }}>
              {cat.name}
            </button>
          ))}
          <button onClick={() => setCatModal("new")} style={{ padding: "7px 14px", borderRadius: 20, fontSize: 13, fontWeight: 600, cursor: "pointer", background: C.cardBg, color: C.muted, border: `1px dashed ${C.border}`, fontFamily: "inherit" }}>
            + Nouvelle
          </button>
          <button onClick={() => setGererOpen(true)} style={{ display: "inline-flex", alignItems: "center", gap: 5, padding: "7px 14px", borderRadius: 20, fontSize: 13, fontWeight: 600, cursor: "pointer", background: "none", color: C.muted, border: `1px solid ${C.border}`, fontFamily: "inherit" }}>
            <Settings size={13} /> Gérer
          </button>
        </div>

        {/* Table */}
        <div style={{ background: C.cardBg, borderRadius: 12, border: `1px solid ${C.border}`, overflow: "hidden" }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ borderBottom: `1px solid ${C.border}` }}>
                {[["NOM DE L'ARTICLE", "left"], ["CATÉGORIE", "left"], ["PRIX", "left"], ["DISPONIBLE", "left"], ["ACTIONS", "right"]].map(([h, align]) => (
                  <th key={h} style={{ padding: "12px 20px", fontSize: 11, fontWeight: 700, color: C.muted, letterSpacing: "0.05em", textAlign: align, textTransform: "uppercase" }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr><td colSpan={5} style={{ padding: 48, textAlign: "center" }}>
                  <div style={{ width: 28, height: 28, border: `3px solid ${C.border}`, borderTopColor: C.yellow, borderRadius: "50%", animation: "spin .7s linear infinite", margin: "0 auto" }} />
                </td></tr>
              )}
              {!loading && products.length === 0 && (
                <tr><td colSpan={5} style={{ padding: 48, textAlign: "center", color: C.muted, fontSize: 14 }}>Aucun article trouvé</td></tr>
              )}
              {!loading && products.map((p, idx) => {
                const isAvail = p.availability === "available";
                const catName = p.categoryId?.name || categories.find(c => c._id === p.categoryId)?.name || "—";
                return (
                  <tr key={p._id} style={{ borderBottom: idx < products.length - 1 ? `1px solid ${C.border}` : "none", transition: "background .1s" }}
                    onMouseEnter={e => e.currentTarget.style.background = "#FAFAF8"}
                    onMouseLeave={e => e.currentTarget.style.background = "transparent"}
                  >
                    <td style={{ padding: "14px 20px", fontSize: 14, fontWeight: isAvail ? 600 : 400, color: isAvail ? C.ink : C.muted }}>{p.name}</td>
                    <td style={{ padding: "14px 20px", fontSize: 13.5, color: C.muted }}>{catName}</td>
                    <td style={{ padding: "14px 20px", fontSize: 14, fontWeight: 600 }}>{p.basePrice?.toLocaleString("fr-DZ")} DA</td>
                    <td style={{ padding: "14px 20px" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <Toggle checked={isAvail} onChange={() => toggleAvail(p)} />
                        {!isAvail && <span style={{ fontSize: 11, fontWeight: 700, padding: "3px 8px", borderRadius: 6, background: "#F1F0EC", color: C.muted }}>Épuisé</span>}
                      </div>
                    </td>
                    <td style={{ padding: "14px 20px" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 8 }}>
                        <button onClick={() => setDrawer(p)} title="Modifier" style={{ background: "none", border: "none", cursor: "pointer", color: C.muted, padding: 4, borderRadius: 6 }}
                          onMouseEnter={e => e.currentTarget.style.color = C.ink}
                          onMouseLeave={e => e.currentTarget.style.color = C.muted}
                        ><Pencil size={15} /></button>
                        <button onClick={() => handleDelete(p._id)} title="Désactiver" style={{ background: "none", border: "none", cursor: "pointer", color: C.muted, padding: 4, borderRadius: 6 }}
                          onMouseEnter={e => e.currentTarget.style.color = C.red}
                          onMouseLeave={e => e.currentTarget.style.color = C.muted}
                        ><Trash2 size={15} /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          {!loading && total > 0 && (
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "14px 20px", borderTop: `1px solid ${C.border}` }}>
              <span style={{ fontSize: 13, color: C.muted }}>
                Affichage de <b style={{ color: C.ink }}>{(page - 1) * LIMIT + 1}</b> à <b style={{ color: C.ink }}>{Math.min(page * LIMIT, total)}</b> sur <b style={{ color: C.ink }}>{total}</b> articles
              </span>
              <div style={{ display: "flex", gap: 6 }}>
                <PageBtn label="Précédent" disabled={page <= 1}      onClick={() => setPage(p => p - 1)} />
                {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map(n => (
                  <PageBtn key={n} label={n} active={page === n} onClick={() => setPage(n)} />
                ))}
                <PageBtn label="Suivant" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)} />
              </div>
            </div>
          )}
        </div>
      </main>

      {/* ── Footer ── */}
      <footer style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "16px 40px", borderTop: `1px solid ${C.border}`, flexShrink: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 7, fontSize: 13, fontWeight: 600 }}>
          <Circle size={7} fill={C.green} color={C.green} /> Connecté <span style={{ color: C.muted }}>·</span>
        </div>
        <span style={{ fontSize: 12, color: C.muted }}>SprintKitchen OS Admin v2.4.0-PROD</span>
      </footer>

      {/* ── Drawer ── */}
      {drawer && (
        <ArticleDrawer
          product={drawer === "new" ? null : drawer}
          categories={categories}
          onClose={() => setDrawer(null)}
          onSave={() => { setDrawer(null); fetchProducts(); }}
        />
      )}

      {/* ── Category Modal ── */}
      {catModal && (
        <CategoryModal
          category={catModal === "new" ? null : catModal}
          onClose={() => setCatModal(null)}
          onSave={() => { setCatModal(null); fetchCategories(); fetchProducts(); }}
        />
      )}

      {/* ── Gérer Modal ── */}
      {gererOpen && (
        <GererModal
          categories={categories}
          onClose={() => setGererOpen(false)}
          onEdit={(cat) => setCatModal(cat)}
          onRefresh={() => { fetchCategories(); fetchProducts(); }}
        />
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

function PageBtn({ label, active, disabled, onClick }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      padding: "6px 12px", borderRadius: 8, fontSize: 13, fontWeight: 600,
      cursor: disabled ? "not-allowed" : "pointer", fontFamily: "inherit",
      background: active ? C.yellow : "#fff",
      color:      active ? C.brown  : C.ink,
      border:     `1px solid ${active ? C.yellow : C.border}`,
      opacity:    disabled ? .4 : 1, transition: "all .15s",
    }}>
      {label}
    </button>
  );
}
