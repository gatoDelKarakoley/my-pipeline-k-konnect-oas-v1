# Hybrid Architecture Documentation

This project implements a **Hybrid "Split-Horizon" Architecture** for Kong Konnect.
It allows a single API Service to be exposed differently for **Internal** and **External** consumers, complying with security best practices.

## 🏗️ Architecture Overview

### Concept: Split-Horizon
Instead of duplicating Services, we define the API **once** (OpenAPI Spec).
The CI/CD pipeline automatically generates **two Routes** for each API endpoint:
1.  **Public Route** (tag: `external`): Public-facing, secured with **mTLS + OIDC** (template: `public.yaml`).
2.  **Private Route** (tag: `internal`): Private-facing, secured with **Key Auth + Rate Limiting** (template: `private.yaml`).

**Example**: For an API with 2 endpoints (`/flights` and `/health`), the pipeline generates **4 routes**:
- `getflights-external` (public)
- `getflights-internal` (private)
- `gethealth-external` (public)
- `gethealth-internal` (private)

### 🌍 Deployment Topology (8 Data Planes)
To ensure isolation, we define **1 Data Plane per Control Plane per Scope**.
Total: **8 Data Planes** running locally via Docker.

| Environnement | Types        | Port HTTP | Port HTTPS | Tag Konnect |
| :------------ | :----------- | :-------- | :--------- | :---------- |
| **DEV**       | **External** | `8000`    | `8443`     | `external`  |
|               | **Internal** | `8001`    | `8444`     | `internal`  |
| **UAT**       | **External** | `8002`    | `8445`     | `external`  |
|               | **Internal** | `8003`    | `8446`     | `internal`  |
| **STAGING**   | **External** | `8004`    | `8447`     | `external`  |
|               | **Internal** | `8005`    | `8448`     | `internal`  |
| **PROD**      | **External** | `8006`    | `8449`     | `external`  |
|               | **Internal** | `8007`    | `8450`     | `internal`  |

## ⚙️ Configuration

### Environment Variables
Environment variables in `config/vars/*.json` control the routing:

```json
// config/vars/dev-envs.json
{
    "host": "api.kong-air.com",              // Backend Upstream URL
    "route_external": "localhost:8000",      // Matching Host for External Gateway
    "route_internal": "localhost:8001"       // Matching Host for Internal Gateway
}
```

### Security Templates
The pipeline uses two security templates located in `config/templates/`:

1. **`public.yaml`**: For public/external routes
   - **mTLS Authentication**: Requires client certificates signed by the configured CA
   - **OIDC Authentication**: OpenID Connect integration (Okta in this example)
   - **CA Certificates**: Self-signed CA certificate for mTLS validation

2. **`private.yaml`**: For private/internal routes
   - **Key Authentication**: API key-based authentication (`apikey` header)
   - **Rate Limiting**: 100 requests per minute (local policy)

These templates are automatically applied during the build phase based on route tags.

## 🚀 CI/CD Pipeline (GitHub Actions)

The `.github/workflows/ci-cd.yaml` pipeline automates this logic:

1.  **Lint**: Validates OpenAPI spec.
2.  **Build (Split-Horizon)**:
    *   Reads `openapi.yaml`.
    *   Reads `config/vars/{env}-envs.json`.
    *   For each endpoint in the OpenAPI spec:
      *   **Generates** `{endpoint}-external` (Host: `route_external`, Tags: `["external","cicd"]`, Plugins from `public.yaml`).
      *   **Generates** `{endpoint}-internal` (Host: `route_internal`, Tags: `["internal","cicd"]`, Plugins from `private.yaml`).
    *   Applies security plugins from templates:
      *   **Public routes**: mTLS + OIDC authentication (`config/templates/public.yaml`).
      *   **Private routes**: Key Auth + Rate Limiting (`config/templates/private.yaml`).
3.  **Deploy**: Syncs this configuration to Kong Konnect.
4.  **Test**: Runs Postman collection against `route_external`.

### ⚠️ Note on GitHub Actions Testing
If configured with `localhost` ports (as above), Integration Tests will **fail** on GitHub Hosted Runners because they cannot reach your local machine.
*   **Solution**: Use Self-Hosted Runners OR use tunneling (ngrok) OR update config with real DNS for Cloud environments.
