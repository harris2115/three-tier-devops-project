# Frontend — Student Portal

This directory contains the React frontend for the three-tier Student Portal.

## Technology

- React
- React Router
- Axios for API requests
- Nginx for serving the production build and reverse-proxying API routes

## Local development

From this directory:

```bash
npm ci
npm start
```

The Create React App development server starts locally (normally at `http://localhost:3000`).

## Production container

The frontend Dockerfile uses a multi-stage build:

1. Node.js installs dependencies and creates the React production build.
2. Nginx serves the generated static files.
3. The Nginx configuration forwards backend API paths to the Compose service named `backend`.

When running through the root Compose configuration, the frontend is published on host port 8081:

```bash
# Run from repository root
docker compose up -d --build frontend
```

Open `http://localhost:8081`.

## Configuration

The optional `.env.example` documents the frontend API base URL setting. The deployed Nginx configuration proxies API requests internally to the backend service. Do not commit real credentials or environment-specific secrets.

For the complete build, deployment, Jenkins pipeline and monitoring walkthrough, see the [root project README](../README.md).
