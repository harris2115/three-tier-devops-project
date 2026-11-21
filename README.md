# Three-Tier Student Portal | AWS, Docker, Jenkins CI/CD & Monitoring

A hands-on DevOps project that takes a React-based Student Portal from application source code to a containerised deployment on **AWS EC2**, automates releases with **Jenkins**, and monitors the host and Docker containers with **Prometheus and Grafana**.

The application has three tiers:

- **Frontend:** React application served by Nginx
- **Backend:** Node.js / Express API
- **Database:** MySQL

The project was completed in stages, beginning with learning and testing Docker containers individually, then moving to Docker Compose, AWS deployment, CI/CD automation and monitoring.

> **Application source:** The Student Portal application was provided as the starting application for the exercise. The DevOps implementation documented here covers containerisation, deployment, automation, infrastructure and monitoring.

---

## Architecture

### End-to-end delivery pipeline

```text
Developer
   |
   v
GitHub repository
   |
   v
Jenkins pipeline (local Ubuntu VM)
   |
   +--> Build frontend and backend Docker images
   |
   +--> Push versioned images to Docker Hub
   |
   v
AWS EC2 (Ubuntu)
   |
   +--> Pull images
   +--> Docker Compose deployment
   +--> Nginx serves frontend and proxies API requests
   |
   v
Three-tier application
   Browser -> React/Nginx -> Node.js API -> MySQL
```

### Monitoring architecture

```text
AWS EC2 host --------------------> Node Exporter ----+
                                                     |
Docker containers ----------------> cAdvisor --------+--> Prometheus --> Grafana
                                                     |
Prometheus self-monitoring -------------------------+
```

Monitoring runs as a separate Docker Compose stack on EC2. Prometheus, Node Exporter, cAdvisor and Grafana are bound to EC2 localhost and accessed through SSH tunnels rather than exposed as public services.

---

## Technology stack

| Area | Tools |
|---|---|
| Operating system | Ubuntu Linux |
| Cloud | AWS EC2 |
| Infrastructure provisioning | Terraform |
| Version control | Git, GitHub |
| CI/CD | Jenkins |
| Containerisation | Docker, Docker Compose |
| Image registry | Docker Hub |
| Frontend / web server | React, Nginx |
| Backend | Node.js, Express |
| Database | MySQL |
| Metrics collection | Prometheus |
| Host metrics | Node Exporter |
| Container metrics | cAdvisor |
| Dashboards and alerts | Grafana |
| Remote administration | SSH |

---

## Repository structure

```text
three-tier-devops-project/
├── frontend/                  # React application, Dockerfile and Nginx config
├── backend/                   # Node.js API, dependencies and Dockerfile
├── database/                  # MySQL image definition
├── monitoring/
│   ├── docker-compose.yaml    # Prometheus, exporters, cAdvisor and Grafana
│   └── prometheus.yml         # Prometheus scrape configuration
├── screenshots/               # Evidence from the build and deployment work
├── assets/                    # Architecture / infrastructure visual
├── docker-compose.yaml         # Local development stack
├── docker-compose.prod.yaml    # EC2 production stack using Docker Hub images
├── Jenkinsfile                # CI/CD pipeline
├── .env.example               # Environment variable template
├── .gitignore
└── README.md
```

Terraform was used during infrastructure provisioning, but the Terraform state and infrastructure source files are not currently included in this repository. No live credentials, private keys, production environment files or database volumes belong in source control.

---

# Project implementation — from start to finish

## Phase 1 — Obtain and understand the three-tier application

The starting application was organised into three components:

1. React frontend for the user interface.
2. Node.js / Express backend exposing API endpoints.
3. MySQL database storing student and teacher records.

Before containerising, the application structure, frontend API calls, backend routes, database connection settings and required ports were reviewed.

**Key learning:** Each tier has a separate responsibility and communicates with the next tier over the application network.

## Phase 2 — Version control with Git and GitHub

The complete source code and DevOps configuration were placed in a Git repository.

Typical workflow:

```bash
git init
git add .
git commit -m "Initial project setup"
git branch -M main
git remote add origin https://github.com/harris2115/three-tier-devops-project.git
git push -u origin main
```

Subsequent changes were committed and pushed so Jenkins could retrieve the latest project source.

**Important:** Never commit `.env` files containing real passwords, SSH private keys, access tokens, Terraform state or other secrets.

## Phase 3 — Containerise the application with Docker

### 3.1 Database container

A MySQL image was configured for the application database. The database uses a named Docker volume so records survive container replacement.

Important concepts practised:

- MySQL image and database initialisation
- Port 3306
- Named volume mounted at `/var/lib/mysql`
- Container logs and health checks

### 3.2 Backend container

The Node.js API was packaged using a Dockerfile. The backend listens on port 3500 and receives its database connection settings through environment variables.

The backend connects to MySQL using the Compose service name `db`, rather than relying on a container IP address.

### 3.3 Frontend container

The React application is built in a Node.js build stage and served by Nginx in the runtime stage.

Nginx serves the frontend and reverse-proxies API paths such as `/student`, `/teacher`, `/addstudent`, `/addteacher` and `/health` to the backend service.

### 3.4 Docker Compose

After practising individual container builds, Docker Compose was used to manage the three services together.

Local stack:

```bash
# From the repository root
cp .env.example .env
# Edit .env and set a strong local MYSQL_ROOT_PASSWORD value.
docker compose up -d --build
docker compose ps
docker compose logs -f
```

The local frontend is mapped to host port 8081 in the checked-in Compose configuration. Open:

`http://localhost:8081`

Stop the local stack without deleting its database volume:

```bash
docker compose down
```

Do **not** use `docker compose down -v` unless you intentionally want to delete the database volume and its data.

### 3.5 Troubleshooting and verification

Issues encountered and resolved during the containerisation work included:

- Container-name conflicts caused by containers created during earlier manual runs.
- MySQL connection and DNS issues between containers.
- Ensuring the backend uses the correct Compose service hostname.
- Frontend API requests failing because a container-only hostname was embedded in browser-side code.
- Host Nginx already using port 80 during local testing, so the frontend was tested on port 8081.
- Checking container logs, health status, port mappings and API responses.

Useful commands:

```bash
docker compose ps
docker compose logs backend
docker compose logs db
docker network ls
docker volume ls
curl http://localhost:8081/health
```

## Phase 4 — Provision AWS infrastructure

AWS EC2 was prepared as the remote deployment host. Terraform was used during the infrastructure setup to define AWS networking and compute resources, including the VPC, subnet, security group and EC2 instance.

The EC2 host ran Ubuntu and Docker Engine with the Docker Compose plugin.

After provisioning:

1. Confirm the instance was running and passed its status checks.
2. Configure SSH access using the EC2 key pair.
3. Verify SSH connectivity from the local Ubuntu VM.
4. Install and verify Docker Engine and Docker Compose on EC2.
5. Prepare the application deployment directory on EC2.

Example SSH connection (replace the path and address with your own values):

```bash
ssh -i /path/to/your-ec2-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

**Infrastructure note:** Terraform configuration files are not part of this repository yet. The infrastructure steps above document the work performed, not a claim that this repository currently contains reusable Terraform code.

## Phase 5 — Deploy the application on AWS EC2

The production Compose file, `docker-compose.prod.yaml`, uses the published Docker Hub images instead of building images on the EC2 host.

The production deployment uses:

- Frontend image: `harris2115/three-tier-frontend`
- Backend image: `harris2115/three-tier-backend`
- MySQL image: `mysql:8.0.40-oraclelinux9`
- Persistent named volume: `mysql-data`

The production stack exposes the frontend on port 80. Backend port 3500 and database port 3306 are internal to the Compose network and are not published to the internet.

On EC2, create a private `.env` file in the deployment directory with the database password and image tag. Do not commit that file.

Example deployment commands:

```bash
docker compose --env-file .env -f docker-compose.prod.yaml pull
docker compose --env-file .env -f docker-compose.prod.yaml up -d
docker compose --env-file .env -f docker-compose.prod.yaml ps
```

The application was verified through the EC2 public HTTP endpoint:

`http://YOUR_EC2_PUBLIC_IP`

## Phase 6 — Automate deployment with Jenkins CI/CD

Jenkins was installed and configured on the local Ubuntu VM. The pipeline is defined in the root `Jenkinsfile`.

### Pipeline stages

| Stage | What it does |
|---|---|
| Checkout | Retrieves the source code from GitHub |
| Build Docker Images | Builds frontend and backend images |
| Push Images to Docker Hub | Authenticates using Jenkins credentials and pushes versioned and latest tags |
| Deploy to AWS EC2 | Connects to EC2 over SSH, pulls the selected images and updates the Compose deployment |
| Post actions | Reports pipeline success or failure |

### Pipeline flow

```text
GitHub -> Jenkins -> Docker Build -> Docker Hub -> SSH -> AWS EC2
```

Jenkins credentials are referenced by ID in the pipeline:

- `dockerhub-creds` — Docker Hub username and access token.
- `ec2-ssh-key` — SSH private key credential for the EC2 deployment user.

The pipeline tags images with the Jenkins build number as well as `latest`. The build-number tag supports traceability of deployed releases.

**Before running the pipeline:**

1. Configure the GitHub repository in the Jenkins Pipeline job.
2. Add the two credentials above in Jenkins.
3. Ensure the Jenkins host can run Docker commands.
4. Ensure the EC2 host and deployment directory are reachable from Jenkins.
5. Set the current EC2 public IP in the Jenkinsfile's `EC2_HOST` setting before running a deployment. EC2 public IPs can change when an instance is stopped and started unless an Elastic IP is assigned.
6. Confirm the production `.env` file exists on EC2 and contains the required values.

A successful pipeline run checks out the code, builds and pushes images, and deploys the selected image tag to EC2.

## Phase 7 — Configure monitoring with Prometheus

Monitoring was deployed as a separate Compose stack under `monitoring/`, independent of the application Compose project.

Prometheus scrapes these targets every 15 seconds:

| Target | Port | Purpose |
|---|---:|---|
| Prometheus | 9090 | Prometheus self-monitoring |
| Node Exporter | 9100 | EC2 host metrics |
| cAdvisor | 8080 | Docker container metrics |

Start the monitoring stack on EC2:

```bash
cd ~/monitoring
docker compose up -d
docker compose ps
```

Check Prometheus targets from the EC2 host:

```bash
curl http://localhost:9090/api/v1/targets
```

The Prometheus targets page should show the configured scrape targets as **UP** when collection is working.

## Phase 8 — Visualise metrics and configure alerts with Grafana

Grafana was deployed in the monitoring Compose stack and configured with Prometheus as its data source:

`http://prometheus:9090`

Dashboards were imported for:

- EC2 host metrics using Node Exporter.
- Docker container metrics using cAdvisor.

CPU and memory utilisation alerts were configured with an 80% threshold and a 5-minute pending period.

### Secure access using SSH tunnels

The monitoring ports are bound to `127.0.0.1` on EC2. From the local Ubuntu VM, open a tunnel in a terminal and keep it running:

**Grafana:**

```bash
ssh -i /path/to/your-ec2-key.pem \
  -L 3000:127.0.0.1:3000 \
  ubuntu@YOUR_EC2_PUBLIC_IP
```

Open `http://localhost:3000` in the local browser.

**Prometheus:** Open a separate terminal and run:

```bash
ssh -i /path/to/your-ec2-key.pem \
  -L 9090:127.0.0.1:9090 \
  ubuntu@YOUR_EC2_PUBLIC_IP
```

Open `http://localhost:9090` in the local browser.

Useful Prometheus pages:

- Graph: `http://localhost:9090/graph`
- Targets: `http://localhost:9090/targets`
- Alerts: `http://localhost:9090/alerts`

If the EC2 public IP changes, use the new address in the SSH tunnel command and update the Jenkins deployment host setting.

---

## Verification checklist

- [x] Three-tier application containerised.
- [x] Docker Compose used to run the application services.
- [x] Application deployed to AWS EC2.
- [x] Jenkins pipeline built and pushed Docker images.
- [x] Jenkins pipeline deployed the application to EC2.
- [x] Prometheus configured with Node Exporter and cAdvisor targets.
- [x] Grafana connected to Prometheus.
- [x] Host and container dashboards configured.
- [x] CPU and memory alerts configured.

## Security and operational considerations

- Keep production `.env` files, passwords, tokens, SSH keys and private key material out of Git.
- Use Jenkins Credentials for CI/CD authentication.
- Restrict inbound SSH (port 22) to trusted source IP addresses.
- Expose only required application ports publicly. Keep MySQL (3306), backend (3500), Prometheus (9090), Node Exporter (9100), cAdvisor (8080) and Grafana (3000) private.
- Access Grafana and Prometheus through SSH tunnels.
- Keep the MySQL named volume when updating or recreating application containers.
- Use versioned Docker image tags to identify releases.

## Key learning outcomes

- Understanding three-tier application communication.
- Writing and troubleshooting Dockerfiles.
- Managing services, networks, health checks and persistent volumes with Docker Compose.
- Deploying containerised applications to AWS EC2.
- Automating image build, push and deployment with Jenkins.
- Managing credentials in Jenkins.
- Collecting host and container metrics with Prometheus exporters.
- Building Grafana dashboards and threshold alerts.
- Troubleshooting networking, service discovery, deployment and monitoring issues.

## Screenshots

The `screenshots/` directory contains evidence from the application and Docker implementation. Additional Jenkins, AWS, Prometheus and Grafana screenshots can be added as they are captured. Please ensure screenshots do not expose credentials, tokens, private IP details that should remain private, or other sensitive information.

## Author

**Harris Shakeel**

- GitHub: [@harris2115](https://github.com/harris2115)
- Repository: [three-tier-devops-project](https://github.com/harris2115/three-tier-devops-project)

---
