import { useState } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios";

const API = import.meta.env.VITE_API_URL || "http://localhost:5000/api";

const C = {
  bg: "#F5F4F0", cardBg: "#FFFFFF", ink: "#1C1917", brown: "#2E2117",
  yellow: "#F2B705", muted: "#8B8378", border: "#E7E4DD",
  red: "#E0533D", redBg: "#FBEAE7",
};

export default function LoginPage() {
  const navigate = useNavigate();
  const [email,    setEmail]    = useState("");
  const [password, setPassword] = useState("");
  const [loading,  setLoading]  = useState(false);
  const [error,    setError]    = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await axios.post(`${API}/auth/login`, { email, password });
      const token = res.data?.token || res.data?.data?.token;
      if (!token) throw new Error("Token non reçu");
      localStorage.setItem("sk_token", token);
      navigate("/", { replace: true });
    } catch (err) {
      if (err.response?.status === 401 || err.response?.status === 400) {
        setError("Email ou mot de passe incorrect.");
      } else {
        setError("Erreur de connexion — vérifiez votre connexion internet.");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: "100vh", background: C.bg,
      display: "flex", alignItems: "center", justifyContent: "center",
      fontFamily: "'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",
      padding: "24px",
    }}>
      <div style={{
        width: "100%", maxWidth: 400,
        background: C.cardBg, borderRadius: 20,
        border: `1px solid ${C.border}`,
        boxShadow: "0 8px 40px rgba(28,25,23,0.08)",
        overflow: "hidden",
      }}>
        {/* Header band */}
        <div style={{
          background: C.brown, padding: "28px 32px 24px",
          display: "flex", flexDirection: "column", gap: 8,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10,
              background: C.yellow, display: "flex", alignItems: "center",
              justifyContent: "center",
            }}>
              <span style={{ fontSize: 18 }}>🍔</span>
            </div>
            <div>
              <div style={{ fontSize: 16, fontWeight: 800, color: "#F5F0E6", letterSpacing: "0.03em" }}>
                SPRINTKITCHEN
              </div>
              <div style={{ fontSize: 10, fontWeight: 600, color: C.yellow, letterSpacing: "0.08em" }}>
                PORTAIL ADMINISTRATEUR
              </div>
            </div>
          </div>
          <p style={{ margin: 0, fontSize: 12.5, color: "rgba(245,240,230,0.65)", marginTop: 4 }}>
            Connectez-vous pour accéder au back-office
          </p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ padding: "28px 32px 32px", display: "flex", flexDirection: "column", gap: 18 }}>
          {error && (
            <div style={{
              background: C.redBg, color: C.red,
              padding: "10px 14px", borderRadius: 9,
              fontSize: 13, fontWeight: 600,
            }}>
              {error}
            </div>
          )}

          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <label style={{ fontSize: 12, fontWeight: 700, color: C.ink, letterSpacing: "0.03em" }}>
              ADRESSE EMAIL
            </label>
            <input
              type="email" value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="admin@sprintkitchen.fr"
              required autoComplete="email"
              style={{
                padding: "12px 14px", borderRadius: 10, fontSize: 14,
                border: `1px solid ${C.border}`, outline: "none",
                fontFamily: "inherit", color: C.ink, background: "#FAFAF8",
              }}
              onFocus={e => e.target.style.borderColor = C.brown}
              onBlur={e => e.target.style.borderColor = C.border}
            />
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <label style={{ fontSize: 12, fontWeight: 700, color: C.ink, letterSpacing: "0.03em" }}>
              MOT DE PASSE
            </label>
            <input
              type="password" value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required autoComplete="current-password"
              style={{
                padding: "12px 14px", borderRadius: 10, fontSize: 14,
                border: `1px solid ${C.border}`, outline: "none",
                fontFamily: "inherit", color: C.ink, background: "#FAFAF8",
              }}
              onFocus={e => e.target.style.borderColor = C.brown}
              onBlur={e => e.target.style.borderColor = C.border}
            />
          </div>

          <button
            type="submit" disabled={loading}
            style={{
              marginTop: 4, padding: "14px", borderRadius: 11, border: "none",
              background: loading ? C.border : C.yellow,
              color: loading ? C.muted : C.brown,
              fontSize: 14, fontWeight: 800, letterSpacing: "0.05em",
              textTransform: "uppercase", cursor: loading ? "not-allowed" : "pointer",
              fontFamily: "inherit",
            }}
          >
            {loading ? "Connexion en cours…" : "SE CONNECTER"}
          </button>

          <p style={{ margin: 0, textAlign: "center", fontSize: 11.5, color: C.muted }}>
            Accès réservé au personnel autorisé
          </p>
        </form>
      </div>
    </div>
  );
}
