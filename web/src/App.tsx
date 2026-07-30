import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'

// Pages
const Dashboard = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">📊 Dashboard</h1>
    <p className="mt-2 text-gray-400">Active incidents overview</p>
  </div>
)
const Incidents = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">🚨 Incidents</h1>
    <p className="mt-2 text-gray-400">Incident log and management</p>
  </div>
)
const Schedules = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">📅 On-Call Schedules</h1>
    <p className="mt-2 text-gray-400">Rotation management</p>
  </div>
)
const Policies = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">🔗 Escalation Policies</h1>
    <p className="mt-2 text-gray-400">Alert routing chains</p>
  </div>
)
const Integrations = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">🔌 Integrations</h1>
    <p className="mt-2 text-gray-400">Webhook registry</p>
  </div>
)
const Settings = () => (
  <div className="p-8 text-white">
    <h1 className="text-2xl font-bold">⚙️ Settings</h1>
    <p className="mt-2 text-gray-400">Team and account settings</p>
  </div>
)

function App() {
  return (
    <BrowserRouter>
      <div className="flex min-h-screen bg-gray-950">
        {/* Sidebar */}
        <nav className="flex w-64 flex-col gap-1 border-r border-gray-800 bg-gray-900 p-4">
          <div className="mb-4 flex items-center gap-2 px-3 py-4">
            <span className="text-2xl">🚨</span>
            <span className="text-lg font-bold text-white">AlertDam</span>
          </div>
          {[
            { path: '/dashboard', label: '📊 Dashboard' },
            { path: '/incidents', label: '🚨 Incidents' },
            { path: '/schedules', label: '📅 Schedules' },
            { path: '/policies', label: '🔗 Policies' },
            { path: '/integrations', label: '🔌 Integrations' },
            { path: '/settings', label: '⚙️ Settings' },
          ].map(({ path, label }) => (
            <a
              key={path}
              href={path}
              className="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
            >
              {label}
            </a>
          ))}
        </nav>

        {/* Main content */}
        <main className="flex-1 overflow-auto">
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/incidents" element={<Incidents />} />
            <Route path="/schedules" element={<Schedules />} />
            <Route path="/policies" element={<Policies />} />
            <Route path="/integrations" element={<Integrations />} />
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}

export default App
