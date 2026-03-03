# Architecture

This document explains how Bars Bookkeeper Manager is structured so contributors can change it safely.

## High-Level Flow

1. `BarsBookkeeperManagerApp` starts the app and injects `AuthService`.
2. `ContentView` switches between `LoginView` and `DashboardView` based on auth state.
3. Feature views call `APIService` async functions to fetch/update data.
4. JSON responses decode into `Codable` structs in `Models/`.
5. UI rendering and lightweight view state live in each feature view.

## Layer Responsibilities

### App Layer
- `BarsBookkeeperManager/App/BarsBookkeeperManagerApp.swift`
- `BarsBookkeeperManager/App/ContentView.swift`
- Responsibility: app entry, environment setup, auth-based root routing.

### Services Layer
- `BarsBookkeeperManager/Services/AuthService.swift`
- `BarsBookkeeperManager/Services/APIService.swift`
- `BarsBookkeeperManager/Services/KeychainService.swift`
- Responsibility:
  - session/token lifecycle
  - centralized API calls and error mapping
  - secure token storage

### Models Layer
- `BarsBookkeeperManager/Models/*.swift`
- Responsibility:
  - decode backend responses
  - expose derived/computed properties used by views
  - avoid UI concerns except simple formatting helpers

### Views Layer
- `BarsBookkeeperManager/Views/*`
- Responsibility:
  - feature-specific state (`@State`)
  - user interactions and view composition
  - triggering service calls

### Theme Layer
- `BarsBookkeeperManager/Theme/Theme.swift`
- Responsibility: design tokens and adaptive colors/typography/spacing.

## Feature Map

1. `Views/Auth/LoginView.swift`
   - Handles credentials and login submission.
2. `Views/Dashboard/*`
   - Sidebar and tab routing between feature screens.
3. `Views/Inventory/InventoryView.swift`
   - On-hand inventory table + detail panel.
4. `Views/Requests/RequestsView.swift`
   - Request queue and status updates.
5. `Views/Predictions/PredictionsView.swift`
   - Forecast data, stock risk, forecast run action.
6. `Views/Orders/*`
   - Order drafts, vendor interactions, send flow.
7. `Views/Settings/SettingsView.swift`
   - Profile, password, tenant, API base URL updates.

## Critical Invariants

1. Unauthorized responses (`401`) must log users out consistently.
2. All API requests should go through `APIService`.
3. `Codable` models must remain aligned with backend JSON keys and types.
4. Role-sensitive actions (like running forecasts) rely on `AuthService` role checks.
5. Base URL override from Settings must remain functional for staging/debug.

## Where Changes Usually Belong

1. New endpoint call:
   - add method in `APIService`
   - add/adjust model in `Models`
   - call from feature view
2. New screen behavior:
   - keep business logic near model/service when reusable
   - keep UI state local to the feature view
3. Design changes:
   - prefer updating `Theme` or shared components first

