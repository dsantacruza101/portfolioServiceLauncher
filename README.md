# Portfolio Service Launcher

Backend infrastructure for the portfolio contact form. Built with a microservices architecture using NATS as the message broker, a NestJS API gateway, and a dedicated email microservice.

## Architecture

```
Internet → Caddy (TLS) → Client Gateway (NestJS) → NATS → Email Microservice (Nodemailer)
```

| Service | Role | Stack |
|---|---|---|
| `client-gateway` | REST API, rate limiting, hCaptcha, CORS | NestJS 11, TypeScript |
| `nodemailer-micro-service` | Sends transactional emails via SMTP | Node.js, Nodemailer |
| `nats-server` | Internal message broker | NATS (Alpine), TLS + token auth |
| `caddy` | Reverse proxy, automatic HTTPS | Caddy (Alpine) — production only |

### Contact flow

1. Frontend posts `POST /api/portfolio/contact-me` with a captcha token.
2. The gateway validates the payload and verifies the hCaptcha token.
3. The gateway publishes a `mail.send` event to NATS.
4. The email microservice picks it up and sends two emails in parallel:
   - A confirmation email to the sender.
   - A notification email to the portfolio owner.

## Requirements

- Docker & Docker Compose
- A valid SMTP account (or any SMTP-compatible provider)
- An [hCaptcha](https://www.hcaptcha.com/) secret key
- TLS certificates for NATS (self-signed is fine for dev — see [Certificates](#certificates))

## Environment Variables

Create a `.env` file in the project root. All services read from it via Docker Compose.

```env
# NATS
NATS_SERVERS=nats://nats-server:4222
NATS_TOKEN=your_nats_token

# Client Gateway
CLIENT_GATEWAY_PORT=3000
TZ=America/Bogota
CORS_ENV=development               # or "production"
CORS_ALLOW_DOMAINS=localhost       # comma-separated list of allowed origins

# hCaptcha
HCAPTCHA_SECRET=your_hcaptcha_secret

# Email Microservice
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your@email.com
SMTP_PASS=your_smtp_password
OWNER_EMAIL=owner@email.com        # receives contact notifications
MAIL_FROM=noreply@yourdomain.com   # the "from" address on all outgoing emails
```

## Running Locally (Development)

```bash
# Start all services with hot-reload
- Clone the repository
- Create a .env base on .env.template
- Execute the command git submodule update --init --recursive to rebuild the sub-modules
- Execute the command docker compose up --build
```

The gateway will be available at `http://localhost:3000`.

## Running in Production

```bash
docker compose -f docker-compose.prod.yml up -d
```

In production:
- Caddy handles TLS termination automatically (ports 80 and 443).
- NATS ports are not exposed externally — all broker traffic stays on the internal Docker network.
- Services are built from production Dockerfiles (`dockerfile.prod`).

## Certificates

NATS requires TLS certificates. Place them in the `./certs` directory:

```
certs/
├── ca.crt       # Certificate Authority
├── server.crt   # NATS server certificate
└── server.key   # NATS server private key
```

The CA certificate (`ca.crt`) is mounted into the gateway and email microservice containers so they can trust the NATS server.

## API

### `POST /api/portfolio/contact-me`

Rate limited to **3 requests per minute** per client. Requires a valid hCaptcha token.

**Request body**

```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "subject": "Hello from your portfolio",
  "message": "I would like to get in touch with you.",
  "captchaToken": "<hcaptcha-response-token>"
}
```

| Field | Type | Rules |
|---|---|---|
| `name` | string | 3–100 characters |
| `email` | string | valid email, max 255 characters |
| `subject` | string | 5–150 characters |
| `message` | string | 10–2000 characters |
| `captchaToken` | string | required, validated server-side |

**Responses**

| Status | Meaning |
|---|---|
| `200` | Emails sent successfully |
| `400` | Validation error |
| `429` | Rate limit exceeded |

## Project Structure

```
portfolioServiceLauncher/
├── client-gateway/          # NestJS API gateway
│   └── src/
│       ├── modules/portfolio-contact-me/
│       ├── common/          # Guards, exception filters
│       ├── config/          # Env validation, service tokens
│       └── transport/       # NATS module
├── nodeMailer-ms/           # Email microservice
│   └── src/
│       ├── core/            # Use cases & interfaces
│       ├── infrastructure/
│       │   ├── mailer/      # Nodemailer sender
│       │   ├── nats/        # NATS transport adapter
│       │   └── templates/   # HTML email templates
│       └── config/          # Env validation
├── certs/                   # TLS certificates (not committed)
├── Caddyfile                # Caddy reverse proxy config
├── nats-server.conf         # NATS server config
├── docker-compose.yml       # Development compose
└── docker-compose.prod.yml  # Production compose
```
