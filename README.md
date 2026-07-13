[![CI](https://github.com/neutron-1985/project-devops-deploy/actions/workflows/ci.yml/badge.svg)](https://github.com/neutron-1985/project-devops-deploy/actions/workflows/ci.yml)

# Project DevOps Deploy

Bulletin board service.

Deployed service: [n-devops.jumpingcrab.com](http://n-devops.jumpingcrab.com)

## Docker artifact

This fork builds the backend and frontend into a single Spring Boot application image. The image repository is configured in `config.mk`; the artifact contains the executable jar with the compiled React Admin frontend in Spring static resources.

Build the image:

```bash
make docker-build
```

Start the container:

```bash
make docker-start
```

By default, Make uses the Docker registry and repository configured in `config.mk`, publishes the application on port `8080` and Actuator on port `9090`. Override the local image name and ports when needed:

```bash
make docker-build IMAGE_NAME=my-project-devops-deploy
make docker-start IMAGE_NAME=my-project-devops-deploy APP_PORT=8081 MANAGEMENT_PORT=9091
```

Open the service at `http://localhost:8080/`; Swagger UI is available at `http://localhost:8080/swagger-ui/index.html`.

> **Fork policy**: this upstream repository is read-only. We do not review or merge pull requests and we do not accept infrastructure changes (Dockerfiles, Ansible roles, CI/CD workflows, etc.). To experiment or extend the project, fork it and work inside your own repository.

The default `dev` profile uses an in-memory H2 database and seeds 10 sample bulletins through `DataInitializer`, so the API works immediately after startup.

API documentation is available via Swagger UI at `http://localhost:8080/swagger-ui/index.html`.

## Project layout

- Backend (Spring Boot) lives in the repository root.
- Frontend (React Admin + Vite) is located in `frontend/`.
- Shared static assets for the backend are served from `src/main/resources/static` (populated by the frontend build when needed).

Keep this structure in mind when running commands—backend tooling (`gradlew`, `make run`, tests) run from the root, frontend tooling (`npm`, `vite`) runs from `frontend/`.

## Environment variables

Key variables are read directly by Spring Boot (see `src/main/resources/application.yml` and `application-prod.yml` for defaults):

| Variable                     | Description                                                   | Default                                      |
|------------------------------|---------------------------------------------------------------|----------------------------------------------|
| `SPRING_PROFILES_ACTIVE`     | Active Spring profile (`dev`, `prod`, etc.)                   | `dev`                                        |
| `SPRING_DATASOURCE_URL`      | JDBC URL for PostgreSQL in `prod`                             | `jdbc:postgresql://localhost:5432/bulletins` |
| `SPRING_DATASOURCE_USERNAME` | DB username                                                   | `postgres`                                   |
| `SPRING_DATASOURCE_PASSWORD` | DB password                                                   | `postgres`                                   |
| `STORAGE_S3_BUCKET`          | Bucket name for bulletin images                               | empty                                        |
| `STORAGE_S3_REGION`          | Region for the S3-compatible storage                          | empty                                        |
| `STORAGE_S3_ENDPOINT`        | Optional custom endpoint                                      | empty                                        |
| `STORAGE_S3_ACCESSKEY`       | Access key ID                                                 | empty                                        |
| `STORAGE_S3_SECRETKEY`       | Secret key                                                    | empty                                        |
| `STORAGE_S3_CDNURL`          | Optional public CDN prefix                                    | empty                                        |
| `MANAGEMENT_SERVER_PORT`     | Port for Spring Actuator endpoints (health, metrics, etc.)    | `9090`                                       |
| `JAVA_OPTS`                  | Extra JVM parameters (heap, `-Dspring.profiles.active`, etc.) | empty                                        |

All other variables supported by Spring Boot can be overridden the same way; check the application configuration files if you need to confirm a property name.

## Requirements

- JDK 21+.
- Gradle 9.2.1.
- PostgreSQL only if you run the `prod` profile with an external database.
- Make.
- NodeJS 20+

## Running

### Backend (local dev profile)

1. Install prerequisites from the **Requirements** section.
2. From the repository root start the backend:

    ```bash
    make run
    ```

3. Explore the API:
   - `GET http://localhost:8080/api/bulletins`
   - `GET http://localhost:8080/api/bulletins?page=1&perPage=9&sort=createdAt&order=DESC&state=PUBLISHED&search=laptop`
   - Swagger UI: `http://localhost:8080/swagger-ui/index.html`

`/api/bulletins` accepts pagination (`page`, `perPage`), sorting (`sort`, `order`) and filters (`state`, `search`). Filters are processed via JPA Specifications so the same contract is available to the React Admin frontend.

### Frontend (development build)

1. Open a second terminal and move into the frontend directory:

    ```bash
    cd frontend
    make install   # npm install
    make start     # Vite dev server on http://localhost:5173
    ```

2. The dev server proxies `/api` requests to `http://localhost:8080`, so keep the backend running.

### Production profile on a single host

1. Export the environment variables from the table above (DB access, S3 storage, `JAVA_OPTS`, etc.). The defaults in `application-prod.yml` show the exact property names if you need to double-check.
2. Build and launch the backend:

    ```bash
    make build
    java -jar build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar
    ```

3. Serve the frontend either from the same JVM (see **Build and serve from the Java app**) or deploy it separately (any static hosting/CDN works once `frontend/dist` is uploaded).

`JAVA_OPTS` can be used to control heap size, GC, or add any `-D` system properties without editing the manifest.

### Deployment

Install the Ansible roles and collections:

```bash
make ansible-install
```

Production targets and their verified SSH host keys are stored in the encrypted `ansible/vault/production.yml`. Create a local Vault password file and place the same password as the `ANSIBLE_VAULT_PASSWORD` GitHub Secret inside it:

```bash
install -m 600 /dev/null ansible/.vault-password
$EDITOR ansible/.vault-password
```

Edit the encrypted production configuration with:

```bash
ansible-vault edit ansible/vault/production.yml --vault-password-file ansible/.vault-password
```

Rotate the Vault password with:

```bash
make vault-rekey
```

The command opens a temporary password file in `$EDITOR`, re-encrypts the production Vault, and replaces the local `.vault-password` only after a successful rekey. Update the `ANSIBLE_VAULT_PASSWORD` GitHub Secret with the new value afterward.

`make provision`, `make deploy`, and the Ansible check targets render a temporary `ansible/inventory.generated.ini` and `ansible/.generated/known_hosts`. The password file and rendered configuration are ignored by Git.

The connection users are stored in the production Vault and rendered as `provision_user` and `deploy_user` variables for the `production` inventory group.

- `provision_user` must be a sudo-capable account. It installs Docker, configures UFW, creates the deployment user and prepares persistent directories.
- `deploy_user` performs regular container deployments without sudo. It must belong to the `docker` group and have an authorized SSH key.

The playbook targets the `production` inventory group. Run one-time server provisioning:

```bash
make provision
```

Provisioning installs Docker, configures UFW, creates the configured deployment user, and prepares persistent directories. Regular CI deployments use only the `deploy` tag and do not require that user to have sudo privileges.

Before the first deployment, add the deployment public key to `/home/<deploy_user>/.ssh/authorized_keys` on every target server. The directory and file must be owned by the configured deployment user; use mode `0700` for `.ssh` and `0600` for `authorized_keys`.

The deployment role pulls the repository configured in `config.mk` with the `latest` tag by default, starts it with the `dev` Spring profile, publishes ports `8080` and `9090`, and mounts uploaded images from `/var/lib/project-devops-deploy/bulletin-images`. Runtime defaults live in `ansible/roles/app_deploy/defaults/main.yml`.

Deploy the latest image in one command:

```bash
make deploy
```

Deploy a stable image tag explicitly:

```bash
make deploy APP_IMAGE_TAG=v1.2.3
```

After starting the new container, the deployment waits for the Actuator readiness probe and checks the public endpoint. If the new container fails either check, the role recreates the container from the previously running image and reports a failed deployment.

Rollback uses the same deployment path with a previously published stable tag:

```bash
make deploy APP_IMAGE_TAG=v1.2.2
```

Avoid using `latest` for rollback; choose the exact tag that was known to work.

### CI/CD

For pull requests and pushes to `main`, the GitHub Actions workflow runs backend lint/tests and frontend lint/build. After a push to `main`, it also installs Ansible dependencies, decrypts the production configuration, and runs the deployment role against the configured hosts in check/diff mode.

For pushes to `main`, the workflow then builds and publishes two Docker tags to Docker Hub: `latest` and `sha-<full-commit-sha>`. The deploy job uses the immutable commit-specific tag:

```bash
make deploy APP_IMAGE_TAG=sha-<commit-sha>
```

Required GitHub Secrets:

- `DOCKER_PASSWORD`
- `DEPLOY_SSH_KEY`
- `ANSIBLE_VAULT_PASSWORD`

`ANSIBLE_VAULT_PASSWORD` decrypts the production targets long enough to render the temporary inventory and `known_hosts` files on the runner. CI loads `DEPLOY_SSH_KEY` into `ssh-agent` and verifies every server against the host keys from the Vault before Ansible connects.

`config.mk` is the single source for the Docker registry, username, and repository used by local Docker commands, CI publishing, and Ansible deployment.

### Useful commands

| Command | Purpose |
|---------|---------|
| `make run` | Run the backend locally |
| `make test` | Run backend tests |
| `make lint` | Check backend formatting |
| `make build` | Build and test the backend |
| `make docker-build` | Build the combined backend/frontend Docker image |
| `make docker-start` | Run the local Docker image on application and management ports |
| `make ansible-install` | Install required Ansible roles and collections |
| `make ansible-configure` | Render temporary inventory and SSH known hosts from the production Vault |
| `make vault-rekey` | Rotate the local and encrypted production Vault password |
| `make provision` | Provision hosts from the production inventory group |
| `make deploy` | Deploy the selected Docker image tag |
| `make ansible-check` | Run the deployment role in Ansible check mode with diff output |

All defaults and supported overrides are defined in [Makefile](./Makefile).

## Frontend

### Development

1. Install Node.js 24 LTS (or newer) and npm.
2. Install dependencies and start the Vite dev server:

    ```bash
    cd frontend
    make install
    make start
    ```

3. The dev server proxies `/api` requests to `http://localhost:8080`, so keep the backend running via `make run` (or `./gradlew bootRun`) in another terminal.

### Image upload flow

1. Upload files via `POST /api/files/upload` (multipart form field named `file`).
2. The response contains `key` and a temporary `url`. Persist the `key` in the `imageKey` field when creating or updating bulletins; the backend stores only that identifier.
3. When you need a fresh link, call `GET /api/files/view?key=...` to receive a new URL (the backend issues presigned links on demand).

### Build and serve from the Java app

1. Build the production bundle:

    ```bash
    cd frontend
    make install      # run once
    make build    # outputs to frontend/dist
    ```

2. Copy the compiled assets into Spring Boot’s static resources (served from `src/main/resources/static`):

    ```bash
    rm -rf src/main/resources/static
    mkdir -p src/main/resources/static
    cp -R frontend/dist/* src/main/resources/static/
    ```

3. Restart the backend (`make run`) and open `http://localhost:8080/` — the React app will now be served directly by the Java application.

### Running in Docker

Pass JVM flags via `JAVA_OPTS`:

```bash
docker run --rm -p 8080:8080 \
  -e JAVA_OPTS="-Xms256m -Xmx512m -Dspring.profiles.active=prod" \
  ...
```

Useful JVM options:

- `-Xms/-Xmx` — set memory limits inside the container.
- `-XX:+UseContainerSupport` / `-XX:ActiveProcessorCount` (these respect cgroup limits by default).
- `-Dspring.profiles.active=prod` — switch the profile without recompiling.
- `-Dlogging.level.root=INFO` or Spring environment variables (`SPRING_DATASOURCE_URL`, `STORAGE_S3_BUCKET`, etc.) — configure external services.

## Monitoring / management ports

- Application traffic still uses port `8080` by default. Actuator endpoints (health, metrics, Prometheus scrape, logfile) listen on `MANAGEMENT_SERVER_PORT` (defaults to `9090` for every profile). Override it via env vars when you need a different port.
- If your deployment does **not** include Prometheus/Grafana yet, you can ignore the management port entirely; the application starts normally even if nothing scrapes `/actuator`. Simply avoid publishing the management port in Docker/Kubernetes until you need it.
- When monitoring is enabled, expose both ports, e.g. `docker run -p 8080:8080 -p 9090:9090 ...` and point Prometheus to `http://<host>:9090/actuator/prometheus`.
- Health probes are available at `/actuator/health/liveness` and `/actuator/health/readiness`; Grafana/Loki integrations should use the same port/env variable.

## Actuator endpoints (local check)

With the app running locally (`make run`), the management port defaults to `http://localhost:9090`. Useful URLs:

- `http://localhost:9090/actuator` — index of exposed endpoints.
- `http://localhost:9090/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness` — readiness/liveness probes.
- `http://localhost:9090/actuator/metrics` and `http://localhost:9090/actuator/metrics/http.server.requests` — raw Micrometer metrics.
- `http://localhost:9090/actuator/prometheus` — Prometheus scrape output (open in browser or `curl` to confirm it renders).
- `http://localhost:9090/actuator/logfile` — current application log (same JSON that goes to stdout).

Override the host/port with `MANAGEMENT_SERVER_PORT` if you changed it; no Prometheus or Grafana instance is needed just to inspect these endpoints.

## Logging

- The backend ships with `src/main/resources/logback-spring.xml`, which writes structured JSON events to `stdout`. Every record contains `timestamp`, `app`, `environment`, `instance`, `logger`, `thread`, message arguments, MDC, and stack traces so Promtail/Loki (or any log shipper) can parse them without extra processing.
- No extra variables are required, but you can supply a different configuration via Spring Boot’s standard options (`LOGGING_CONFIG`, `logging.config`, or by overriding `logback-spring.xml` on the classpath).
- Container runtimes should forward `stdout`/`stderr` to your logging pipeline. Avoid redirecting logs to files unless your platform explicitly demands it.

## Image Upload Checks

### Local (dev profile, H2 + temp storage)

1. Start backend: `make run` (uses in-memory H2 and local filesystem storage under `/tmp/bulletin-images`).
2. Start frontend dev server: `cd frontend && npm install && npm run dev`.
3. In React Admin:
    - Create a bulletin or edit an existing one.
    - Use the “Upload image” field; after save, the image preview should load via the generated `imageUrl`.
4. Verify backend log: look for `Stored image` entries or check `/tmp/bulletin-images` for a new file. Refresh the bulletin show page to ensure the presigned/local URL still renders.

### Production / S3

1. Ensure the S3-related variables from the table above (bucket, region, access/secret keys, optional endpoint/CDN URL) are exported alongside the `prod` profile settings.
2. Deploy backend (e.g., `java -jar build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar`).
3. In the frontend (local or deployed), upload an image for a bulletin.
4. Confirm expected behavior:
    - Response from `/api/files/upload` contains a non-empty `key`.
    - Image shows up in bulletin show view (URL should either point to CDN or be a presigned S3 link).
    - Object exists in S3 bucket (check via AWS console or `aws s3 ls s3://your-bucket/bulletins/...`).
5. Optional: run `curl -I "$(curl -s .../api/files/view?key=... | jq -r .url)"` to ensure the presigned URL is valid from the production environment.
