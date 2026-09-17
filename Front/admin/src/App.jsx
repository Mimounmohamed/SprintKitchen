import { useEffect, useState } from 'react'
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
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/"             element={<RequireAuth><DashboardPage /></RequireAuth>} />
      <Route path="/menu"         element={<RequireAuth><MenuPage /></RequireAuth>} />
      <Route path="/historique"   element={<RequireAuth><HistoriquePage /></RequireAuth>} />
      <Route path="/statistiques" element={<RequireAuth><StatistiquesPage /></RequireAuth>} />
      <Route path="/inventaire"   element={<RequireAuth><InventairePage /></RequireAuth>} />
      <Route path="*"             element={<Navigate to="/" replace />} />
    </Routes>
  )
}
