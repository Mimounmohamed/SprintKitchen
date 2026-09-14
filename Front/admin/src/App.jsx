import { useEffect, useState } from 'react'
import { Routes, Route } from 'react-router-dom'
import { silentLogin } from './lib/api'
import DashboardPage from './pages/DashboardPage'
import MenuPage from './pages/MenuPage'

export default function App() {
  const [ready, setReady] = useState(!!localStorage.getItem('sk_token'));

  useEffect(() => {
    if (localStorage.getItem('sk_token')) { setReady(true); return; }
    silentLogin().finally(() => setReady(true));
  }, []);

  if (!ready) return (
    <div style={{
      minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center",
      fontFamily: "Inter, sans-serif", fontSize: 14, color: "#8B8378",
      background: "#F5F4F0",
    }}>
      Connexion en cours…
    </div>
  );

  return (
    <Routes>
      <Route path="/"     element={<DashboardPage />} />
      <Route path="/menu" element={<MenuPage />} />
    </Routes>
  )
}
