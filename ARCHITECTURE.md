# Hybrid Architecture Documentation

This project implements a **Hybrid "Split-Horizon" Architecture** for Kong Konnect.
It allows a single API Service to be exposed differently for **Internal** and **External** consumers, complying with security best practices.

## 🏗️ Architecture Overview

### Concept: Split-Horizon
Instead of duplicating Services, we define the API **once** (OpenAPI Spec).
The CI/CD pipeline automatically generates **two Routes** for each Service:
1.  **External Route**: Public-facing, secured with **mTLS + OIDC**.
2.  **Internal Route**: Private-facing, secured with **Key Auth + Rate Limiting**.

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
Environment variables in `config/vars/*.json` control the routing:

```json
// config/vars/dev-envs.json
{
    "host": "api.kong-air.com",              // Backend Upstream URL
    "route_external": "localhost:8000",      // Matching Host for External Gateway
    "route_internal": "localhost:8001"       // Matching Host for Internal Gateway
}
```

## 🚀 CI/CD Pipeline (GitHub Actions)

The `.github/workflows/ci-cd.yaml` pipeline automates this logic:

1.  **Lint**: Validates OpenAPI spec.
2.  **Build (Split-Horizon)**:
    *   Reads `openapi.yaml`.
    *   Reads `config/vars/{env}-envs.json`.
    *   **Generates** `my-api-external` (Host: `route_external`, Plugins: `mtls-oidc`).
    *   **Generates** `my-api-internal` (Host: `route_internal`, Plugins: `internal`).
3.  **Deploy**: Syncs this configuration to Kong Konnect.
4.  **Test**: Runs Postman collection against `route_external`.

### ⚠️ Note on GitHub Actions Testing
If configured with `localhost` ports (as above), Integration Tests will **fail** on GitHub Hosted Runners because they cannot reach your local machine.
*   **Solution**: Use Self-Hosted Runners OR use tunneling (ngrok) OR update config with real DNS for Cloud environments.
