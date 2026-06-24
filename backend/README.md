# Backend — Nexus Finance Wallet Engine

The Spring Boot backend serving as the core ledger, registry, and authentication gateway for the Nexus Finance Super App. It exposes a REST API consumed by both the Flutter host app and the Astro mini-apps via the in-app WebView bridge.

---

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Runtime | Java (JDK) | 17 |
| Framework | Spring Boot | 3.2.5 |
| Database | PostgreSQL (Neon Serverless) | 16 |
| ORM | Spring Data JPA / Hibernate | 6.x |
| Auth | JWT (Auth0 java-jwt) | 4.4.0 |
| Password Hashing | jBCrypt | 0.4 |
| Build | Maven | 3.9+ |

---

## API Endpoints

### Authentication

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| `POST` | `/api/auth/register` | No | Register a new user with username/password. Returns a JWT token. |
| `POST` | `/api/auth/login` | No | Authenticate and receive a JWT token (expires in 1 hour). |

### Wallet Operations

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| `GET`  | `/api/v1/wallet/{userId}/balance` | No | Get current balance. Auto-creates user if not found (default $1,500.00). |
| `POST` | `/api/v1/wallet/{userId}/deduct` | Yes (JWT) | Deduct funds. Requires `Authorization: Bearer <token>` header. |
| `POST` | `/api/v1/wallet/{userId}/credit` | No | Add funds to a user's wallet. |
| `POST` | `/api/v1/wallet/{userId}/transfer` | No | Transfer funds between two users. Requires `recipientId` in body. |

### Mini-App Registry

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| `GET`  | `/api/v1/registry/mini-apps` | No | Returns metadata (name, icon, entry URL) for all active mini-apps. Entry URLs are dynamically resolved to the requesting host's IP. |

### Common Request/Response Format

**All endpoints** return JSON. Success responses include a `success: true` field; errors include `success: false` with a `message` field explaining the failure.

---

## Package Structure

```text
src/main/java/com/nexus/finance/
├── NexusBackendApplication.java       # Spring Boot entry point
├── controller/
│   ├── AuthController.java            # /api/auth — register & login
│   ├── WalletController.java           # /api/v1/wallet — balance, deduct, credit, transfer
│   └── MiniAppRegistryController.java  # /api/v1/registry — mini-app discovery
├── model/
│   ├── User.java                       # JPA entity mapped to "users" table
│   └── MiniApp.java                    # POJO for registry metadata (not persisted)
├── repository/
│   └── UserRepository.java             # JPA repository for User persistence
└── security/
    ├── JwtUtil.java                    # Token generation & validation (HMAC256)
    ├── JwtInterceptor.java             # HandlerInterceptor — guards /deduct with JWT
    ├── WebMvcConfig.java               # Registers JwtInterceptor on /deduct route only
    └── DataSeeder.java                 # Seeds user-001 & sarthak on startup
```

### Layer Responsibilities

- **controller/** — REST endpoints. Thin layer; delegates to repository for persistence. No service-layered indirection (kept intentionally flat for this PoC).
- **model/** — Domain objects. `User` is a JPA `@Entity`; `MiniApp` is a plain POJO returned as registry metadata.
- **repository/** — Data access. `UserRepository` extends `JpaRepository<User, String>` — the only persistence interface in the module.
- **security/** — Authentication infrastructure. JWT signing/verification, request interceptor that extracts and validates tokens, and a data seeder for development.

---

## Repository Layer

### UserRepository

`UserRepository` is the sole data access interface, extending Spring Data JPA's `JpaRepository<User, String>`.

- **Entity:** `User` (`@Table(name = "users")`)
- **Primary key:** `String username` (natural key — no synthetic UUID)
- **Persistence coverage:**
  - `findById(String)` — used by `AuthController` (login) and `WalletController` (balance, deduct, credit, transfer)
  - `existsById(String)` — used by `AuthController` (registration conflict check) and `DataSeeder` (idempotent seeding)
  - `save(User)` — used everywhere for creates and updates
- **Design rationale:** The natural-key approach keeps lookups simple and avoids JOINs on a user-to-ID mapping table. This is intentional for a PoC — if the system evolves to support username changes or GDPR-mandated anonymization, consider switching to a synthetic `UUID` primary key and treating `username` as a unique mutable column.

> The `users` table is managed by Hibernate via `spring.jpa.hibernate.ddl-auto=update`, so it is created automatically on first startup. See [Configuration](#configuration) for details.

---

## Configuration

All configuration lives in `src/main/resources/application.properties`.

```properties
# Server
server.port=8080
spring.application.name=nexus-backend

# PostgreSQL (Neon)
spring.datasource.url=jdbc:postgresql://<host>/neondb?sslmode=require
spring.datasource.username=<user>
spring.datasource.password=<password>
spring.datasource.driver-class-name=org.postgresql.Driver

# Hibernate
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
```

### Key Settings

- **`ddl-auto=update`** — Hibernate auto-creates/migrates the `users` table from the `User` entity definition. Safe for development; switch to `validate` + Flyway/Liquibase for production.
- **`show-sql=true`** — Logs all SQL statements to stdout. Disable in production.
- **CORS** — `@CrossOrigin(origins = "*")` is set on every controller. In production, restrict to known origins.

---

## Development Guide

### Running Locally

```bash
cd backend
mvn spring-boot:run
```

The server starts on `http://localhost:8080`. On first startup, `DataSeeder` creates two test users:

| Username | Password | Starting Balance |
|----------|----------|-----------------|
| `user-001` | `password123` | $1,500.00 |
| `sarthak` | `password123` | $1,500.00 |

### JWT Authentication for Wallet Deducts

The `/api/v1/wallet/{userId}/deduct` endpoint requires a valid JWT in the `Authorization` header:

```bash
# 1. Obtain a token
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user-001", "password": "password123"}'

# 2. Use the token to deduct funds
curl -X POST http://localhost:8080/api/v1/wallet/user-001/deduct \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"amount": 50.00}'
```

### Adding a New Feature

1. **New entity?** — Create a `@Entity` class in `model/`, then add a `JpaRepository` interface in `repository/`.
2. **New endpoint?** — Add a method to an existing controller or create a new `@RestController` in `controller/`.
3. **New auth guard?** — Extend `JwtInterceptor` or register additional path patterns in `WebMvcConfig`.
4. **No service layer exists yet** — For PoC simplicity, controllers talk directly to repositories. If business logic grows complex, extract it into a `service/` package.

---

## Related Documentation

- [Root README](../README.md) — Architecture overview, run instructions for the full ecosystem
- `src/main/java/com/nexus/finance/repository/UserRepository.java` — Javadoc with design rationale
