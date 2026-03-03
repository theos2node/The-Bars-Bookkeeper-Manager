# Bars Bookkeeper Manager

iPad companion app for [Bars Bookkeeper](https://github.com/theos2node/The-Bars-Bookkeeper) — the inventory management, forecasting, and ordering platform for bars and restaurants.

## Overview

Bars Bookkeeper Manager is a **landscape-only iPad app** designed for managers to access their Bars Bookkeeper account on the go. It connects to the same backend API and provides a native iPadOS experience with sidebar navigation optimized for tablet use.

## Features

- **Inventory Management** — View all on-hand inventory with real-time stock levels, par level indicators, category grouping, and detailed item inspection
- **Stock Requests** — Review, approve, or deny staff stock requests with batch processing
- **Predictions** — View ML-driven forecasts with run-out dates, daily usage trends, and recommended order quantities. Run new forecasts directly from the app
- **Orders** — Generate AI-powered purchase orders, manage vendors, preview email drafts, and send orders to vendors
- **Settings** — Manage your profile, organization, password, and API connection

## Requirements

- iPad running iOS 17.0+
- Landscape orientation
- Active Bars Bookkeeper account (manager or owner role)

## Tech Stack

- **SwiftUI** — Native declarative UI framework
- **Swift 5** — Modern Swift with async/await concurrency
- **Keychain** — Secure token storage
- **URLSession** — Native networking with the Bars Bookkeeper REST API

## Design

The app mirrors the web application's design language:
- Matching color system (light/dark theme support)
- Consistent typography and spacing scale
- Sidebar navigation pattern optimized for iPad landscape
- Detail panels for in-depth item inspection

## Setup

1. Open `BarsBookkeeperManager.xcodeproj` in Xcode 15+
2. Set your development team in Signing & Capabilities
3. Build and run on an iPad or iPad Simulator
4. Sign in with your Bars Bookkeeper credentials

The app connects to `https://barsbookkeeper.com/api` by default. You can change the API URL in Settings > Connection.

## Documentation

- Contributor workflow: `CONTRIBUTING.md`
- Architecture overview: `docs/ARCHITECTURE.md`
- API contract and compatibility checklist: `docs/API_COMPATIBILITY.md`
- Repo strategy (split repo + integration): `docs/REPO_STRATEGY.md`

If you plan to contribute across both repos (backend + iPad app), start with `CONTRIBUTING.md` and `docs/API_COMPATIBILITY.md` first.

## Project Structure

```
BarsBookkeeperManager/
├── App/                    # App entry point & root view
├── Models/                 # Data models (Auth, Inventory, Requests, Forecasts, Orders)
├── Services/               # API client, Auth service, Keychain
├── Views/
│   ├── Auth/               # Login screen
│   ├── Dashboard/          # Main layout with sidebar
│   ├── Inventory/          # Inventory list & detail panel
│   ├── Requests/           # Stock request management
│   ├── Predictions/        # Forecast predictions
│   ├── Orders/             # Order management & vendor sheet
│   ├── Settings/           # Account, connection, about
│   └── Components/         # Shared UI components
├── Theme/                  # Design tokens matching the web app
└── Assets.xcassets/        # App icon & accent color
```

## Relationship to Bars Bookkeeper

This is **not** a standalone app — it works alongside your existing Bars Bookkeeper web deployment. It uses the same:
- Authentication system (JWT tokens)
- REST API endpoints
- Database and tenant isolation
- Role-based access control

Any changes made in the iPad app are immediately reflected in the web app and vice versa.

## Safe Contribution Strategy

Contributing is a good idea if you treat this as an API-coupled client:

1. Keep PRs small and focused.
2. Run the simulator build before every PR.
3. Validate impacted screens manually.
4. Coordinate backend response changes with matching app model updates.
