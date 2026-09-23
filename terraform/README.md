# Terraform Infrastructure

This directory contains the Infrastructure as Code (IaC) setup for the Agent on GCP. It is modularized by theme and designed to follow security best practices.

## Architecture Diagram

The following Mermaid diagram illustrates how the components interact securely.

```mermaid
flowchart TD
    subgraph GCP Environment
        Scheduler[Cloud Scheduler\n(Cron Job)]
        CR[Cloud Run\n(Private Agent Service)]
        IAM[Service Account\n(Agent Identity)]
        BQ[(BigQuery)]

        Scheduler -- "1. Invokes endpoint using\nOIDC Auth Token" --> CR
        CR -- "2. Runs with Identity of" --> IAM
        IAM -- "3. Authorized to Query" --> BQ
    end

    subgraph Gemini Agent Platform
        GAP[Gemini Agent Platform]
        GAP -- "User Prompts via OIDC Auth" --> CR
    end

    classDef gcp fill:#e3f2fd,stroke:#1976d2,stroke-width:2px;
    classDef ext fill:#fff3e0,stroke:#f57c00,stroke-width:2px;

    class Scheduler,CR,IAM,BQ gcp;
    class GAP ext;
```

## Modules

- **`iam`**: Sets up the Service Account for the agent and grants it necessary BigQuery roles (`roles/bigquery.dataViewer`, `roles/bigquery.jobUser`).
- **`cloudrun`**: Provisions a **private** Cloud Run service. By default, Cloud Run restricts access to only identities with the `roles/run.invoker` role.
- **`scheduler`**: Creates a Cloud Scheduler cron job to periodically trigger the agent. It hits the native ADK `/run` endpoint with a JSON payload, authenticating to the private Cloud Run service using an OIDC token generated from the agent's Service Account.

## Security & Authentication

A key part of this architecture is its **private nature**. The Cloud Run service does *not* allow unauthenticated access (`allUsers`).

1. **Internal Invocation (Cron)**: The Cloud Scheduler is explicitly granted the `run.invoker` role and uses OIDC to securely access the service.
2. **External Invocation (Gemini Platform)**: The Gemini Agent Platform also authenticates via OIDC when you register the agent using the `gemini agents create` CLI command.

*Note: While infrastructure provisioning (Cloud Run, IAM) is managed here via Terraform, the registration of the agent to the Gemini Agent Platform is currently done via the CLI. This is because the Agent Platform is a specialized service where registration is often handled via imperative deployment tools or the `adk` CLI.*
