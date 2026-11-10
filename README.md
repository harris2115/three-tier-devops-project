# 🐳 Containerizing a Three-Tier Student Portal Application

A hands-on Docker project demonstrating how to containerize and run a three-tier web application consisting of a **React (Vite) frontend, Node.js backend, and MySQL database**.

The project was built progressively: first as three individually-built Dockerfiles wired together with a manually created Docker network and volume, then optimized with **multi-stage builds** and non-root runtime users, and finally automated end-to-end with **Docker Compose**.

> **Note:** The base Student Portal application (student/teacher records: name, roll number, subjects) was provided as part of an instructor-led project. My own work and this documentation focus on containerization, Docker configuration, image optimization, networking, persistence, Nginx configuration, Docker Compose, and troubleshooting — every Dockerfile here was written and explained line-by-line rather than copy-pasted.

---

## 📌 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#️-architecture)
- [Technology Stack](#️-technology-stack)
- [Project Structure](#-project-structure)
- [Build Order — Bottom to Top](#-build-order--bottom-to-top)
- [Step 1: Database (MySQL) Dockerfile](#️-step-1-database-mysql-dockerfile)
- [Prerequisites: Custom Network and Volume](#-prerequisites-custom-network-and-volume)
- [Building and Running the Database Container](#-building-and-running-the-database-container)
- [Step 2: Backend (Node.js) Dockerfile](#️-step-2-backend-nodejs-dockerfile)
- [Building and Running the Backend Container](#-building-and-running-the-backend-container)
- [Step 3: Frontend (React/Vite) Dockerfile](#-step-3-frontend-reactvite-dockerfile)
- [Building and Running the Frontend Container](#-building-and-running-the-frontend-container)
- [Functional Testing](#-functional-testing)
- [Testing Data Persistence — A Real Debugging Walkthrough](#-testing-data-persistence--a-real-debugging-walkthrough)
- [Reducing Image Size — Multi-Stage Builds](#-reducing-image-size--multi-stage-builds)
- [npm install vs npm ci](#-npm-install-vs-npm-ci)
- [Running as a Non-Root User](#-running-as-a-non-root-user)
- [Docker Compose](#-docker-compose)
- [Compose Errors Hit and Fixed](#-compose-errors-hit-and-fixed)
- [Final Verification](#-final-verification)
- [Image Size Comparison](#-image-size-comparison)
- [Running the Project](#️-running-the-project)
- [Docker Commands Reference](#-docker-commands-reference)
- [Security and Production Considerations](#-security-and-production-considerations)
- [What I Learned](#-what-i-learned)
- [Quick Revision Summary](#-quick-revision-summary)
- [Future Improvements](#-future-improvements)
- [Screenshots](#-screenshots)
- [Author](#-author)
- [Acknowledgements](#-acknowledgements)

---

## 📖 Project Overview

This project demonstrates the containerization of a three-tier **Student Portal** web application storing student and teacher records (name, roll number, subjects).

- **Frontend:** React (Vite/TSX)
- **Backend:** Node.js
- **Database:** MySQL

Everything — including the database — is configured purely through Dockerfiles, with no external setup scripts. Functionally, this is an **M-N stack** (MySQL instead of MongoDB), rather than the usual MERN/MEAN.

The goals of the project:

1. Containerize each tier from scratch, understanding *why* every Dockerfile line exists (not just what it does)
2. Wire the tiers together with Docker networking
3. Make database data persistent across container recreation
4. Optimize every image with multi-stage builds
5. Harden the backend to run as a non-root user
6. Replace manual `docker build` / `docker run` commands with a single Docker Compose workflow
7. Deliberately hit and fix real bugs (naming mismatches, version pinning, healthchecks) rather than skip past them

---

## 🏗️ Architecture

```text
                    ┌──────────────────┐
                    │      Browser     │
                    └────────┬─────────┘
                             │
                             │ HTTP :80
                             ▼
                  ┌─────────────────────┐
                  │      FRONTEND       │
                  │   React + Nginx     │
                  │    Container :80    │
                  └──────────┬──────────┘
                             │
                             │ API :3500
                             ▼
                  ┌─────────────────────┐
                  │       BACKEND       │
                  │     Node.js API     │
                  │   Container :3500   │
                  └──────────┬──────────┘
                             │
                             │ MySQL :3306
                             ▼
                  ┌─────────────────────┐
                  │      DATABASE       │
                  │       MySQL         │
                  │   Container :3306   │
                  └─────────────────────┘
```

---

## 🛠️ Technology Stack

| Technology | Purpose |
|---|---|
| React (Vite/TSX) | Frontend application |
| Node.js | Backend runtime |
| MySQL | Relational database |
| Docker | Application containerization |
| Dockerfile | Image creation for all three tiers, including the database |
| Multi-stage Docker Builds | Image size and security optimization |
| Nginx | Production frontend web server |
| Docker Compose | Multi-container orchestration |
| Docker Volumes | Persistent database storage |
| Docker Networking | Container-to-container communication |

---

## 📂 Project Structure

```text
Student-Portal-Three-Tier-Application/
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   ├── package-lock.json
│   └── ...
│
├── backend/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   ├── package-lock.json
│   ├── .env.example
│   └── ...
│
├── database/
│   └── Dockerfile
│
├── docker-compose.yml
│
├── .gitignore
│
└── README.md
```

---

## 🐳 Build Order — Bottom to Top

Containers are built and started in this order:

```text
Database → Backend → Frontend
```

The backend depends on the database being available, and the frontend depends on the backend being available. Starting in dependency order avoids connection errors that would occur if a dependent service started before what it needs.

---

## 🗄️ Step 1: Database (MySQL) Dockerfile

No application source code is needed for the database — just a base image plus configuration.

```dockerfile
FROM mysql:latest

ENV MYSQL_ROOT_PASSWORD=<your-password>
ENV MYSQL_DATABASE=school

EXPOSE 3306

VOLUME /var/lib/mysql

CMD ["mysqld"]
```

| Line | Explanation |
|---|---|
| `FROM mysql:latest` | Uses the official MySQL image. **Flagged as bad practice** — a specific version should be pinned instead of `latest`, to avoid unexpected version-related breakage (this comes back as a real bug — see [Compose Errors Hit and Fixed](#-compose-errors-hit-and-fixed)) |
| `ENV MYSQL_ROOT_PASSWORD=...` | Sets the required root password for MySQL to start. **Not best practice** to hardcode a password in a Dockerfile — acceptable only for local/learning use, not a real deployment. Real-world equivalent: a secrets manager (HashiCorp Vault, AWS Secrets Manager, Parameter Store) |
| `ENV MYSQL_DATABASE=school` | Creates a database named `school` automatically on container startup |
| `EXPOSE 3306` | Documents the standard MySQL port so the backend container can connect to it |
| `VOLUME /var/lib/mysql` | Declares a persistent storage location — MySQL's actual data directory — so data can be mounted to a volume instead of living only inside the ephemeral container |
| `CMD ["mysqld"]` | Starts the MySQL daemon process when the container runs |

> Also flagged (acknowledged, but out of scope for this local demo): the database uses the root MySQL user directly, instead of a dedicated username/database pairing. A dedicated user with limited permissions is the real-world recommended approach.

---

## 🌐 Prerequisites: Custom Network and Volume

### Why a Custom Network Is Needed

With three separate containers (DB, backend, frontend) that must talk to each other, a shared custom network is created so they can all communicate. This also acts as a network-isolation best practice — containers on other, unrelated networks won't be able to reach these containers.

> On Kubernetes this manual network step isn't needed — Kubernetes handles it differently.

```bash
docker network create three-tier-network
docker network ls
```

### Why a Named Volume Is Needed

Ensures MySQL's data physically persists on the local machine, outside the container's own ephemeral storage — so if the container is deleted, the data survives and a new container can pick up right where the old one left off.

```bash
docker volume create mysql-data
docker volume ls
```

---

## ▶️ Building and Running the Database Container

```bash
docker build -t mysql-image database/
```

> Build produces a warning: *"Secret used in ARG or ENV: do not use build arguments or environment instructions for sensitive data"* — expected and acknowledged, since a hardcoded password is used deliberately for this local demo.

```bash
docker run -d \
  -p 3306:3306 \
  --network three-tier-network \
  -v mysql-data:/var/lib/mysql \
  --name mysql-container \
  mysql-image
```

> ⚠️ The correct MySQL port is `3306` — double-check this when typing it out.

Verified success via:

```bash
docker ps
docker logs mysql-container
```

confirming "ready for startup" and the MySQL server running.

---

## ⚙️ Step 2: Backend (Node.js) Dockerfile

An `.env` file was used to hold config values (DB host, password, container name) for local convenience — **flagged as an outdated approach**. Modern best practice: fetch credentials from a secrets manager (e.g., AWS Secrets Manager) instead. It's used here only because this is a local machine, not a real deployment.

> ⚠️ **Important gotcha:** the `.env` file's `DB_HOST` value must exactly match the database container's `--name`. A mismatch here caused a real failure later in the project — see [Testing Data Persistence](#-testing-data-persistence--a-real-debugging-walkthrough).

```dockerfile
FROM node:14

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

EXPOSE 3500

CMD ["node", "server.js"]
```

| Line | Explanation |
|---|---|
| `FROM node:14` | Base image — exact version tags for any base image can be found by searching that image on Docker Hub |
| `WORKDIR /app` | Sets the working directory for subsequent commands |
| `COPY package.json ./` | Copies **only** the dependency file first — deliberately isolated from the rest of the source code to speed up image builds via Docker's layer caching |
| `RUN npm install` | Installs dependencies, generating a `node_modules` folder |
| `COPY . .` | Copies the remaining configuration/source files (e.g., `server.js`, `.env`) |
| `EXPOSE 3500` | Documents the port the Node app listens on |
| `CMD ["node", "server.js"]` | Starts the backend application |

**`.dockerignore`** is used here to exclude specific files/folders (e.g., a local `node_modules` folder) from being copied into the image — preventing unnecessarily large or irrelevant local folders from bloating the build context.

---

## ▶️ Building and Running the Backend Container

```bash
docker build -t backend-image backend/

docker run -d \
  -p 3500:3500 \
  --network three-tier-network \
  --name backend-container \
  backend-image
```

Verified via `docker logs backend-container`: connection to MySQL succeeded, and the student/teacher tables were created automatically. Server confirmed running on port 3500.

Verified in the browser at `http://localhost:3500`: backend correctly responded with a "from backend" message and empty student data (since nothing had been added to the database yet).

---

## 🎨 Step 3: Frontend (React/Vite) Dockerfile

A different Node.js base image version is used than the backend — deliberately, since base image choice depends on the specific application's own requirements, not a fixed rule.

**Alpine** is introduced here: Alpine-based images contain far fewer default packages than standard/"native" images, meaning a significantly smaller image size — used here as `node:21-alpine3.17`.

```dockerfile
FROM node:21-alpine3.17

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

ARG REACT_APP_API_BASE_URL
ENV REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL

RUN npm run build

EXPOSE 3000

CMD ["serve", "-s", "build", "-l", "tcp://0.0.0.0:3000"]
```

### Why `ARG` + `ENV` Together for the Backend URL

The frontend needs to know the backend's address/URL to make API calls — this shouldn't be hardcoded, since it can differ per environment.

- **`ARG`**: accepts a value passed in at **build time**, via `--build-arg` on the `docker build` command — so the same Dockerfile can be reused across environments without hardcoding.
- **`ENV`**: the application code actually reads this as an environment variable at **runtime** — so the `ARG`'s value needs to be explicitly assigned into an `ENV` variable (`ENV VAR=$VAR`) for the running app to actually see it.

> Real-world equivalent: in a CI/CD pipeline, this backend URL would typically come from stored credentials/pipeline variables, not be typed manually each time.

---

## ▶️ Building and Running the Frontend Container

```bash
docker build -t frontend-image \
  --build-arg REACT_APP_API_BASE_URL=http://localhost:3500 \
  frontend/

docker run -d \
  -p 80:3000 \
  --network three-tier-network \
  --name frontend-container \
  frontend-image
```

Host port `80` is mapped to the container's port `3000` — so the app is accessed simply via `localhost`, without needing to specify a port.

> The frontend build takes noticeably longer than the backend, since the frontend project has significantly more code/dependencies to process.

---

## 🧪 Functional Testing

- Confirmed the app loads with Home / Student / Teacher navigation.
- Added a student record (name + roll number) — confirmed it appeared correctly, including a creation timestamp.
- Confirmed the **same** data was visible from the backend's own direct endpoint (`localhost:3500`) — cross-verifying that frontend, backend, and database are all correctly wired together.
- Deleted the record from the frontend and confirmed it was also gone from the backend view — further confirming correct end-to-end connectivity.
- Repeated the same add/verify flow for a teacher record.

---

## 🔄 Testing Data Persistence — A Real Debugging Walkthrough

### Step 1 — Delete the Database Container Entirely

```bash
docker ps
docker rm -f mysql-container
```

After deletion, refreshing the frontend correctly showed the Home page still working, but the Student/Teacher pages failed with a connection error — expected, since the database no longer exists.

### Step 2 — Recreate the Database Container From the Same Volume

A new DB container was started, reusing the **same** `mysql-data` volume — critical, since this is what should allow the previous data to be restored automatically.

**First attempt:** the new container was accidentally given a different name (`mysql-container-2`).

**Bug encountered:** the frontend/backend still failed to fetch data — `"failed to fetch students"`.

**Root cause:** the backend's `.env` file has `DB_HOST` hardcoded to the exact container name `mysql-container`. Since the new DB container was named `mysql-container-2`, the backend could no longer resolve/reach it — even though the correct, data-filled volume was attached.

**Fix:** removed the mismatched container, freed up port 3306, then recreated the database container using the **original** exact name `mysql-container`.

After this fix, refreshing the frontend correctly showed all previously entered student/teacher data — **confirming** that the named volume successfully persisted the data across a full container deletion and recreation, independent of the container's lifecycle.

> **Key lesson:** when connecting containers by container **name** (rather than a stable service name, as Compose provides), that exact name becomes a hard dependency elsewhere in the stack. A naming mismatch after recreating a container is a very realistic, easy-to-hit bug — and is one of the strongest reasons to move to Docker Compose (see below), where service names replace fragile container names.

---

## 📦 Reducing Image Size — Multi-Stage Builds

In production, images should have minimal layers/packages — fewer packages means fewer common vulnerabilities and smaller, more secure images.

**Baseline sizes before optimization:** frontend ≈ 594 MB, backend ≈ 891 MB, MySQL ≈ 953 MB.

### Frontend — Multi-Stage Rewrite

General principle: don't use a base image that contains far more packages than the app actually needs — after building the app (`npm run build`), the full Node.js toolchain usually isn't needed anymore, just the resulting static files.

```dockerfile
# ---- Stage 1: build ----
FROM node:21-alpine3.17 AS build

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

ARG REACT_APP_API_BASE_URL
ENV REACT_APP_API_BASE_URL=$REACT_APP_API_BASE_URL

RUN npm run build


# ---- Stage 2: serve ----
FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

| Line | Explanation |
|---|---|
| `FROM node:21-alpine3.17 AS build` | Named build stage — aliased as `build` for later reference |
| `FROM nginx:alpine` | Fresh, minimal second stage — nginx's own Alpine-based image, used only to *serve* the already-built static files, not to build anything |
| `COPY --from=build /app/build /usr/share/nginx/html` | Copies only the built static output (HTML/JS/CSS from `npm run build`) from the `build` stage into nginx's default web content directory — none of Stage 1's `node_modules`, source code, or build tools carry over |
| `COPY nginx.conf /etc/nginx/conf.d/default.conf` | Copies a custom nginx configuration file (routing/redirect behavior, server name, error pages) into nginx's default config location |
| `EXPOSE 80` | nginx serves on port 80 by default (replacing the Node app's port 3000) |
| `CMD ["nginx", "-g", "daemon off;"]` | Starts nginx in the foreground so the container keeps running as expected |

**Result: 212 MB → 29.5 MB** This level of reduction won't always be achievable for every project, but pursuing it as far as reasonably possible pays off in both image security and faster container startup times.

### Backend — Multi-Stage Rewrite With Security Hardening

Node version upgraded from `14` to `18` as part of this rewrite — `14` was too outdated, with no meaningful current support.

```dockerfile
# ---- Stage 1: build ----
FROM node:18-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --only=production
RUN npm cache clean --force

COPY . .


# ---- Stage 2: run as non-root ----
FROM node:18-alpine

RUN addgroup js && adduser -G js -S nodejs

WORKDIR /app

COPY --from=build /app /app

USER nodejs

EXPOSE 3500

CMD ["node", "server.js"]
```

**Result: 363 MB → 51.6 MB**, alongside the added non-root security improvement.

---

## 🔍 npm install vs npm ci

| Aspect | `npm install` | `npm ci` |
|---|---|---|
| Reads from | `package.json` | `package-lock.json` only |
| Speed | Slower | Faster — more deterministic, better suited for automated builds |
| `node_modules` handling | Reuses/merges with any existing `node_modules` | Removes any existing `node_modules` first, for a fully clean install |

- `--only=production`: skips installing dev-only dependencies — reduces size and avoids pulling in packages only needed during development, which could otherwise carry their own vulnerabilities into a production image.
- `npm cache clean --force`: clears npm's internal cache after install, further reducing the final image size.

---

## 🔐 Running as a Non-Root User

A dedicated group (`js`) and user (`nodejs`, attached to that group) are created specifically so the application does **not** run as root inside the container — a real security best practice consistently emphasized across Docker and Kubernetes deployments.

```dockerfile
RUN addgroup js && adduser -G js -S nodejs
```

> **Important detail:** the group and user must be created in the **same** `RUN` instruction, not split across two separate `RUN` lines — splitting them would create an unnecessary additional image layer, increasing image size for no benefit.

`COPY --from=build /app /app` brings over the already-installed dependencies and source code from Stage 1 — copying the whole `/app` directory this time, since unlike the frontend, there's no separate "just the static build output" artifact to isolate; the backend needs its full runtime code.

`USER nodejs` switches the container to run as this non-root user for everything from this point forward in the Dockerfile.

---

## 🧩 Docker Compose

Manually running 6–7 separate `docker build` / `docker run` commands (across 3 services, plus network/volume setup) is tedious and error-prone. Docker Compose reduces this to **one** command that builds all images and runs all containers together.

- A modern Compose file does **not** need a top-level `version` field — you can go straight to the top-level `services` key.
- The Compose file must be named `docker-compose.yml` (or similar) and placed in the project **root** folder.
- When using Compose, you do **not** need to manually run `docker network create` — Compose automatically creates and manages its own network for all services defined in the same file.

### Database Service

```yaml
services:
  db:
    container_name: mysql-container
    image: mysql:8.0.40
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: <your-password>
      MYSQL_DATABASE: school
    volumes:
      - mysql-data:/var/lib/mysql
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p<your-password>"]
      interval: 10s
      timeout: 5s
      retries: 5
```

| Field | Purpose |
|---|---|
| `image` | Instead of `build:`, references the same image the database Dockerfile would produce — here pinned to a **specific version** (`8.0.40`), not `latest` (this pinning becomes important — see [Compose Errors Hit and Fixed](#-compose-errors-hit-and-fixed)) |
| `restart: always` | Restart policy — conceptually similar to restart policies configured in Kubernetes |
| `environment` | Same environment variables as the Dockerfile version — values set here **override** whatever is baked into the Dockerfile itself |
| `volumes` | References the same named volume for persistent MySQL data |
| `healthcheck` | Lets Compose actively verify the container is genuinely working (not just "running") by periodically executing a test command (here: pinging MySQL). `interval` = how often to check; `timeout` = how long to wait per check; `retries` = how many consecutive failures before marking the container unhealthy |

### Backend Service

```yaml
  backend:
    container_name: backend-container
    build:
      context: ./backend
    image: backend-image
    restart: always
    ports:
      - "3500:3500"
    environment:
      DB_HOST: db
      DB_USER: root
      DB_NAME: school
      DB_PASSWORD: <your-password>
    depends_on:
      db:
        condition: service_healthy
```

- **Key difference from the manual/Dockerfile-only setup:** `DB_HOST` is now simply `db` — the Compose **service name** — rather than the literal container name `mysql-container` used before. Compose provides this kind of stable service-name-based networking automatically, sidestepping the exact container-naming bug hit earlier.
- `depends_on` with `condition: service_healthy` means the backend service will only start **after** the `db` service's healthcheck reports healthy — not just after the DB container merely starts running. This directly prevents the backend from starting before the database is actually ready to accept connections.

### Frontend Service

```yaml
  frontend:
    container_name: frontend-container
    build:
      context: ./frontend
      args:
        REACT_APP_API_BASE_URL: http://localhost:3500
    image: frontend-image
    restart: always
    ports:
      - "80:80"
    depends_on:
      backend:
        condition: service_started

volumes:
  mysql-data:
```

- `build.args` passes the backend URL as a build-time argument — same purpose as the manual `--build-arg` flag used earlier, just declared declaratively in the YAML instead.
- The frontend's `depends_on` uses `condition: service_started` (**not** `service_healthy`) — it only needs the backend service to have *started*, a lighter requirement than the strict health check used for the database dependency.
- The top-level `volumes: mysql-data:` section declares the named volume so Compose knows to create/manage it.

---

## 🐛 Compose Errors Hit and Fixed

```bash
docker compose up --build
```

| Error Encountered | Root Cause | Fix |
|---|---|---|
| `"Invalid restart policy"` | The restart policy value was accidentally capitalized (e.g., `"Always"` instead of `"always"`) — YAML/Compose expects the exact lowercase keyword | Corrected the value to lowercase `always` in every service |
| Database container reported **"unhealthy"** | Version incompatibility between the `mysql:latest` image being pulled and the *existing* data already stored in the `mysql-data` volume (created under a different, older MySQL version) | Pinned the image explicitly to `mysql:8.0.40` (matching the version the volume's data was already compatible with) instead of `latest` |

> This reinforces the earlier "never use `:latest`" warning — this is the exact real-world failure mode that pinning a specific version is meant to prevent.

---

## ✅ Final Verification

- `docker compose up --build` succeeded — pulled/built the DB, backend, and frontend, and started all three.
- Since Compose creates its **own** `mysql-data` volume (separate from the manually created one used earlier), the app correctly started with **no pre-existing** student/teacher data — expected, and confirmed via `docker volume ls` (which showed both the old manually-created volume and the new Compose-managed one).
- Similarly, `docker network ls` showed a **new** Compose-managed network (auto-named based on the project/folder), separate from the manually created `three-tier-network` — confirming Compose fully manages its own networking without needing the earlier manual `docker network create` step.
- New test data was added via the frontend and confirmed working end-to-end again.
- `docker compose up -d --build` can be used instead to run everything in detached/background mode.
- Final `docker ps` confirmed all three containers running, with the database explicitly showing a **"healthy"** status — confirming the healthcheck configuration was working correctly end to end.

---
## 📦 Image Size Comparison
| Image | Manual Dockerfile Build (Original) | After Multi-Stage Optimization |
|---|---|---|
| Frontend | 212 MB | 29.5 MB |
| Backend | 363 MB | 51.6 MB |

---

## ▶️ Running the Project

### Prerequisites

- Docker
- Docker Compose / Docker Compose plugin
- Git

```bash
docker --version
docker compose version
```

### Run Using Docker Compose

From the project root:

```bash
docker compose up --build
```

Detached mode:

```bash
docker compose up -d --build
```

Check running containers:

```bash
docker compose ps
# or
docker ps
```

### Access the Application

| Service | URL |
|---|---|
| Frontend | http://localhost |
| Backend | http://localhost:3500 |
| MySQL | localhost:3306 |

---

## 🧰 Docker Commands Reference

**Manual (Dockerfile-only) workflow**

```bash
# Network + volume
docker network create three-tier-network
docker volume create mysql-data

# Database
docker build -t mysql-image database/
docker run -d -p 3306:3306 --network three-tier-network \
  -v mysql-data:/var/lib/mysql --name mysql-container mysql-image

# Backend
docker build -t backend-image backend/
docker run -d -p 3500:3500 --network three-tier-network \
  --name backend-container backend-image

# Frontend
docker build -t frontend-image \
  --build-arg REACT_APP_API_BASE_URL=http://localhost:3500 frontend/
docker run -d -p 80:3000 --network three-tier-network \
  --name frontend-container frontend-image
```

**Inspection / cleanup**

```bash
docker ps
docker ps -a
docker logs <container-name>
docker rm -f <container-name>
docker images
docker network ls
docker volume ls
```

**Docker Compose**

```bash
docker compose up --build       # start and build
docker compose up -d --build    # start in detached mode
docker compose down             # stop services
docker compose ps               # view Compose services
docker compose logs             # view logs
```

---

## 🔒 Security and Production Considerations

This project is intended for learning and local development. Some configurations should be improved before using the application in a real production environment.

1. **Do not hardcode database passwords.** All examples in this README use `<your-password>` placeholders. Set the real value in an untracked `.env` file and commit a `.env.example` instead of a real `.env`. Production alternatives: Docker secrets, AWS Secrets Manager, AWS Systems Manager Parameter Store, HashiCorp Vault, Kubernetes Secrets.
2. **Avoid using the MySQL root user.** The backend currently uses the MySQL root account. A production application should use a dedicated database user with only the required permissions.
3. **Pin image versions.** Avoid `mysql:latest` — this project hit a real "unhealthy container" bug because of it. Prefer a specific version, e.g. `mysql:8.0.40`.
4. **Run containers as non-root.** The backend runtime uses a dedicated `nodejs` user created in a single `RUN` instruction.
5. **Production HTTPS.** A real deployment should use HTTPS/TLS rather than exposing the application directly over HTTP, typically via a reverse proxy or load balancer.
6. **Connect by Compose service name, not container name.** Referencing containers by exact `--name` (as in the manual workflow) is a fragile, easy-to-break pattern once containers get recreated — Compose service names (`db`, `backend`) avoid this class of bug entirely.

---

## 🧠 What I Learned

**Docker Fundamentals** — images, containers, Dockerfiles, port mapping, container logs, image layers, container lifecycle

**Docker Networking** — custom Docker networks, container-to-container communication, service-name-based DNS, host ports vs container ports, `localhost` vs container/service names

**Docker Storage** — named volumes, persistent database storage, container lifecycle vs data lifecycle, and the real bug that happens when a container is renamed after recreation

**Dockerfile Best Practices** — `FROM`, `WORKDIR`, `COPY`, `RUN`, `ARG`, `ENV`, `EXPOSE`, `CMD`, `.dockerignore`, layer caching, multi-stage builds

**Multi-Stage Builds** — separating build and runtime environments, reducing image size, using Node.js only during the frontend build, serving production React files with Nginx, minimizing runtime dependencies

**Security Hardening** — running as a non-root user, creating group + user in a single `RUN` layer, `npm ci --only=production` + cache cleaning

**Docker Compose** — declarative multi-container configuration, service definitions, build contexts, environment variables, build arguments, volumes, healthchecks, `depends_on` conditions, automatic Compose networking, restart policies

**Troubleshooting** — port conflicts, container-naming mismatches, frontend/backend API connectivity, build-time environment variables, database persistence, image version compatibility (`latest` vs pinned), invalid Compose YAML values

---

## 📝 Quick Revision Summary

- Build multi-container apps bottom-to-top: **Database → Backend → Frontend**, since each layer depends on the one before it.
- **Never use `:latest`** for a base image in real projects — pin a specific version to avoid silent, hard-to-diagnose breakage (this caused a real "unhealthy container" bug in this project).
- **Never hardcode secrets/passwords** in a Dockerfile for real deployments — use a secrets manager; acceptable only for local/learning purposes.
- **Named volumes** make container data survive full container deletion/recreation — but when containers reference each other by exact **container name** (not a Compose service name), a naming mismatch after recreation is a very real, easy bug to hit.
- **Copy dependency files (`package.json`) before the rest of the source code** in a Dockerfile — enables Docker layer caching and speeds up rebuilds.
- **`.dockerignore`** excludes local files/folders (e.g., `node_modules`) from being copied into the build context.
- **`ARG` (build-time input) + `ENV` (runtime variable the app actually reads)** together let a Dockerfile accept a configurable value (e.g., a backend URL) without hardcoding it.
- **Multi-stage builds** dramatically cut image size by discarding build-only tools/source code in the final stage — frontend dropped from 212 MB → 29.5 MB using an `nginx:alpine` final stage; backend dropped from 363 MB → 51.6 MB using `npm ci --only=production`, cache cleaning, and a clean `node:18-alpine` final stage.
- **Run containers as a non-root user** for security — create the group and user in a single `RUN` instruction to avoid an unnecessary extra image layer.
- **`npm ci`** (uses `package-lock.json`, faster, fully clean install) differs from **`npm install`** (uses `package.json`, can merge with existing `node_modules`) — `ci` is generally preferred for reproducible, automated builds.
- **Docker Compose** replaces many manual `docker build`/`docker run` commands with one declarative YAML file and one command (`docker compose up --build`) — and automatically manages its own network and volumes, without needing manual `docker network create`.
- **`depends_on`** supports `condition: service_healthy` (wait for a real healthcheck to pass) vs. `condition: service_started` (just wait for the container to start) — choose based on how strict the dependency actually needs to be.
- **Compose service names** (e.g., `db`) can be used directly as hostnames by other services — a more robust alternative to relying on exact container names.
- Docker mastery is a hard prerequisite before learning Kubernetes, since Kubernetes exists specifically to orchestrate containers. Docker Swarm is Docker's own native alternative to Kubernetes.

---

## 🚀 Future Improvements

This project is intended to be extended as part of a broader Cloud/DevOps learning path — the natural next steps after mastering this Docker/Compose workflow are deploying the same application on **Kubernetes**, and eventually packaging it with **Helm charts** for multi-environment deployments.

- [ ] GitHub Actions CI/CD
- [ ] Automated Docker image builds
- [ ] Push images to Docker Hub / container registry
- [ ] Deploy application to AWS
- [ ] Kubernetes Deployment manifests, Services, ConfigMaps, Secrets, Ingress
- [ ] Helm charts
- [ ] Monitoring with Prometheus + Grafana dashboards
- [ ] Centralized logging
- [ ] HTTPS/TLS
- [ ] Production database configuration with a dedicated (non-root) DB user
- [ ] External secrets management

---## 📸 Screenshots
| # | Screenshot | Definition |
|---|---|---|
| 1 | ![docker images before](screenshots/docker-images.png) | `docker images` output — all three images built with their sizes (before the multi-stage rewrite) |
| 2 | ![docker images after](screenshots/docker-images-multistage.png) | `docker images` output — all three images built with their sizes (after the multi-stage rewrite) |
| 3 | ![docker ps manual](screenshots/docker-ps-manual.png) | `docker ps` showing `mysql-container`, `backend-container`, `frontend-container` all running from the manual workflow |
| 4 | ![homepage](screenshots/homepage.png) | Application homepage with Home / Student / Teacher navigation |
| 5 | ![student page](screenshots/student-page.png) | Student page with an added record (name, roll number, creation timestamp) |
| 6 | ![backend response](screenshots/backend-response.png) | Browser at `localhost:3500` showing the raw backend JSON response with student/teacher data, confirming frontend ↔ backend ↔ database wiring |
| 7 | ![compose up success 1](screenshots/compose-up-success1.png) | `docker compose up --build` completing successfully with all three services started |
| 8 | ![compose up success 2](screenshots/compose-up-success2.png) | `docker compose up --build` completing successfully with all three services started |
| 9 | ![docker volume and network ls](screenshots/docker-volume&network-ls.png) | `docker volume ls` and `docker network ls` showing both the manually created volume and the new Compose-managed volume & manually created network and the new Compose-managed network |

---

## 👨‍💻 Author

**Neha V M**

B.Tech — Electronics & Communication Engineering

Interested in: Cloud Computing · DevOps · Docker · Kubernetes · AWS · Linux · CI/CD · Computer Networks

---

## 🙏 Acknowledgements

The base Student Portal application and the instructional project workflow were provided through an instructor-led learning project. This repository documents my hands-on work and learning around:

- Docker containerization (including the database tier)
- Dockerfiles written and explained line-by-line
- Multi-stage builds and non-root security hardening
- Nginx, Docker networking, Docker volumes
- Docker Compose, healthchecks, `depends_on` conditions
- Real container-naming and image-versioning bugs, and how they were diagnosed and fixed
