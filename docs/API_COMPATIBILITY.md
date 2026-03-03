# API Compatibility Guide

This app decodes API responses directly into Swift `Codable` models. Backend contract changes can break runtime decoding and feature behavior.

Use this file as a compatibility checklist when changing either repo.

## Base URL

- Default: `https://barsbookkeeper.com/api`
- Override path: Settings -> Connection
- Runtime source: `APIService.baseURL`

## Endpoint -> Model Map

### Auth and Profile

1. `POST /auth/login` -> `AuthResponse`
   - required: `token`
2. `GET /me` -> `ProfileResponse`
   - required: `user`, `tenant`
3. `PATCH /me` -> `ProfileUpdateResponse`
   - required: `user`
4. `POST /me/password` -> `OkResponse`
   - required: `ok`
5. `PATCH /tenant` -> `TenantUpdateResponse`
   - required: `tenant`

### Inventory

1. `GET /inventory/on-hand` -> `OnHandResponse`
   - required root key: `onHand`
   - item fields used in UI:
     - `sku_id`, `name`, `unit`, `on_hand`
     - optional: `category_name`, `par_level`, `effective_weekly_par`, `lead_time_days`, `icon`

### Requests

1. `GET /requests` -> `RequestsResponse`
   - required root key: `requests`
2. `PATCH /requests/{id}` -> `RequestUpdateResponse`
   - required root key: `request`

### Forecasts

1. `GET /inventory/forecast/latest?ensureFresh=1` -> `ForecastResponse`
   - required root key: `forecasts`
   - optional root key: `run`
2. `POST /inventory/forecast/run` -> `RunForecastResponse`
   - required: `runId`, `runAt`, `inserted`

### Orders and Vendors

1. `GET /orders` -> `OrdersResponse`
   - required root key: `orders`
2. `POST /orders/generate` -> `GenerateOrdersResponse`
3. `POST /orders/{orderId}/send` -> `SendOrderResponse`
4. `PATCH /orders/{orderId}` -> `OrderUpdateResponse`
5. `GET /vendors` -> `VendorsResponse`
6. `POST /vendors` -> `VendorCreateResponse`

## Breaking vs Safe Changes

### Usually Breaking

1. Renaming existing JSON keys.
2. Changing data types (for example number -> string).
3. Removing required root keys (`orders`, `requests`, `onHand`, `forecasts`).
4. Changing enum raw values returned for statuses without app updates.

### Usually Safe

1. Adding optional fields not yet consumed by app.
2. Adding new endpoints unused by current app.
3. Adding new enum values if app has a safe fallback.

## Change Procedure for Cross-Repo Work

When backend contract changes are required:

1. Update backend endpoint/response.
2. Update app `Models/` and affected views in this repo.
3. Run app build and manual feature checks.
4. Reference both PRs in each repo.
5. Merge/deploy in coordinated order to avoid client/server mismatch windows.

