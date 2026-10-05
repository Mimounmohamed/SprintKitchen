import React, { useEffect, useState } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import DashboardPage    from './pages/DashboardPage'
import MenuPage         from './pages/MenuPage'
import HistoriquePage   from './pages/HistoriquePage'
import StatistiquesPage from './pages/StatistiquesPage'
import InventairePage   from './pages/InventairePage'
import LoginPage        from './pages/LoginPage'

function RequireAuth({ children }) {
  return localStorage.getItem('sk_token') ? children : <Navigate to="/login" replace />;
}

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("ErrorBoundary caught an error:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          minHeight: "100vh", display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center", background: "#F5F4F0",
          fontFamily: "'Inter', sans-serif", padding: 24, textAlign: "center"
        }}>
          <div style={{
            maxWidth: 480, background: "#FFFFFF", borderRadius: 16,
            padding: "32px 28px", boxShadow: "0 4px 24px rgba(0,0,0,0.08)",
            border: "1px solid #E5E7EB"
          }}>
            <div style={{ fontSize: 36, marginBottom: 12 }}>⚠️</div>
            <h2 style={{ fontSize: 20, fontWeight: 700, color: "#1C1917", margin: "0 0 8px" }}>
              Une erreur inattendue est survenue
            </h2>
            <p style={{ fontSize: 13, color: "#6B7280", margin: "0 0 20px" }}>
              {this.state.error?.message || "Erreur de chargement du composant."}
            </p>
            <div style={{ display: "flex", gap: 10, justifyContent: "center" }}>
              <button
                onClick={() => { this.setState({ hasError: false, error: null }); window.location.href = '/'; }}
                style={{
                  padding: "10px 18px", borderRadius: 8, background: "#583926",
                  color: "#FFFFFF", fontWeight: 700, fontSize: 13, border: "none", cursor: "pointer"
                }}
              >
                Retour à l'accueil
              </button>
              <button
                onClick={() => window.location.reload()}
                style={{
                  padding: "10px 18px", borderRadius: 8, background: "#FACC15",
                  color: "#1F2937", fontWeight: 700, fontSize: 13, border: "none", cursor: "pointer"
                }}
              >
                Recharger la page
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

export default function App() {
  const [ready, setReady] = useState(true);

  if (!ready) return (
    <div style={{
      minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center",
      fontFamily: "Inter, sans-serif", fontSize: 14, color: "#8B8378",
      background: "#F5F4F0",
    }}>
      Chargement…
    </div>
  );

  return (
    <ErrorBoundary>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/"             element={<RequireAuth><DashboardPage /></RequireAuth>} />
        <Route path="/menu"         element={<RequireAuth><MenuPage /></RequireAuth>} />
        <Route path="/historique"   element={<RequireAuth><HistoriquePage /></RequireAuth>} />
        <Route path="/statistiques" element={<RequireAuth><StatistiquesPage /></RequireAuth>} />
        <Route path="/inventaire"   element={<RequireAuth><InventairePage /></RequireAuth>} />
        <Route path="*"             element={<Navigate to="/" replace />} />
      </Routes>
    </ErrorBoundary>
  )
}
