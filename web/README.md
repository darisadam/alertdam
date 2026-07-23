# Web Dashboard — PagerDam

React 19 + Vite + Tailwind CSS web dashboard for PagerDam.

## Requirements

- Node.js 20+
- npm 10+

## Directory Structure

```
src/
├── assets/          # Static assets (icons, images)
├── components/      # Reusable UI components
│   ├── ui/          # Base components (Button, Badge, Card, Modal)
│   ├── incidents/   # Incident-specific components
│   ├── schedule/    # Schedule calendar components
│   └── layout/      # Layout components (Sidebar, Header, Shell)
├── pages/           # Route-level pages
│   ├── Dashboard.tsx
│   ├── Incidents.tsx
│   ├── Schedules.tsx
│   ├── Policies.tsx
│   ├── Integrations.tsx
│   └── Settings.tsx
├── hooks/           # Custom React hooks
│   ├── useIncidents.ts
│   └── useSchedule.ts
├── services/        # API client (axios)
│   └── api.ts
├── store/           # Zustand state management
│   └── auth.ts
├── App.tsx
└── main.tsx
```

## Development

```bash
npm install
npm run dev     # Starts at http://localhost:3000
```

The dev server proxies `/v1/*` requests to the Go backend at `http://localhost:8080`.

## Build

```bash
npm run build   # Outputs to dist/
npm run preview # Preview production build
```

## Linting

```bash
npm run lint
npm run type-check
```
