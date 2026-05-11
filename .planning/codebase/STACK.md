# Technology Stack

**Analysis Date:** 2026-05-11

## Languages

**Primary:**
- Ruby 3.4.4 - Backend application, Sidekiq jobs, Rails framework
- JavaScript/TypeScript - Frontend, Vue 3 components, build tooling
- Node.js 24.x - Runtime for frontend build pipeline (Vite)
- YAML - Configuration files (config/sidekiq.yml, storage.yml, credentials)

**Secondary:**
- SQL - PostgreSQL queries and migrations
- HTML/CSS - Email templates, ActionMailer views

## Runtime

**Environment:**
- Ruby on Rails 7.1.5.2 - Web application framework
- Node.js 24.13.0 - JavaScript runtime for frontend build

**Package Manager:**
- Bundler (Ruby) - Gemfile.lock present
- pnpm 10.2.0+ - Frontend package manager (package-lock.json via pnpm)

## Frameworks

**Core:**
- Rails 7.1.5.2 - MVC web framework, ActiveRecord ORM, ActionMailer, ActionCable
- Vue 3.5.12 - Frontend UI framework (Composition API with `<script setup>`)
- Vite 5.4.21 - JavaScript/Vue bundler and dev server (via vite_rails 3.0.17)

**Background Jobs:**
- Sidekiq 7.3.1 - Job queue processor (Redis-backed)
- Sidekiq-Cron 1.12.0 - Scheduled jobs/cron support
- Sidekiq Alive 2.5.0 - Sidekiq health monitoring

**Authorization & Authentication:**
- Devise 4.9.4 - User authentication (local accounts)
- Devise Token Auth 1.2.5 - API token-based auth
- Devise Two-Factor 6.1.0 - 2FA support
- Pundit 2.3.0 - Authorization/policy framework

**Testing:**
- Vitest 3.0.5 - Frontend unit test runner
- RSpec Rails 6.1.5+ - Backend unit/integration tests
- Factory Bot Rails 6.4.3+ - Test fixtures/factories

**Build/Dev:**
- Vite Rails 3.0.17 - Rails + Vite integration
- Tailwind CSS 3.4.19 - Utility-first CSS framework
- Puma 6.4.3 - Ruby web server

## Key Dependencies

**Critical:**
- redis 5.0.6 - In-memory store for Sidekiq, caching, WebSocket subscriptions
- postgresql (pg 1.5.3) - Primary database
- stripe 18.0.1 - Payment processing for subscriptions/billing
- aws-sdk-s3 1.208.0 - S3 storage for file uploads (via ActiveStorage)

**Messaging & Communications:**
- twilio-ruby 7.6.0 - SMS and WhatsApp via Twilio
- slack-ruby-client 2.7.0 - Slack channel integration
- facebook-messenger 2.0.1 - Facebook/Instagram channels
- line-bot-api - LINE messaging channel
- twitty 0.1.5 - Twitter/X integration

**Cloud Storage:**
- aws-sdk-s3 1.208.0 - Amazon S3 storage
- google-cloud-storage 1.48.0+ - Google Cloud Storage
- azure-storage-blob (custom fork) - Azure Blob storage
- aws-actionmailbox-ses - Email ingest via AWS SES

**Search & Data:**
- searchkick 5.5.2 - Full-text search abstraction layer
- opensearch-ruby 3.4.0 - OpenSearch integration (alternative to Elasticsearch)
- pgvector - PostgreSQL vector search (for AI/embeddings)
- neighbor - PostgreSQL similarity search

**AI & LLM:**
- ruby-openai 7.3.1 - OpenAI API client
- ai-agents 0.9.1 - Agent framework for AI workflows
- ruby_llm 1.8.2+ - LLM abstraction layer
- google-cloud-dialogflow-v2 0.24.0+ - Dialogflow NLU
- google-cloud-translate-v3 0.7.0+ - Translation service

**HTTP Clients:**
- faraday 2.14.1 - HTTP client (used by multiple SDK gems)
- rest-client 2.1.0 - HTTP client for API calls
- faraday-middleware-aws-sigv4 - AWS Signature v4 signing for OpenSearch

**Observability:**
- datadog 2.19.0 - Application Performance Monitoring (optional, env-gated)
- sentry-rails 5.19.0+ - Error tracking (optional, env-gated)
- sentry-sidekiq 5.19.0+ - Sidekiq error tracking (optional)
- elastic-apm 4.6.2 - Elastic APM monitoring (optional, env-gated)
- scout_apm 5.3.3 - Scout APM (optional, env-gated)
- newrelic_rpm - New Relic APM (optional, env-gated)
- newrelic-sidekiq-metrics 1.6.2+ - New Relic Sidekiq integration
- opentelemetry-sdk - OpenTelemetry observability (for LLM tracing)
- opentelemetry-exporter-otlp - OTLP exporter

**Push Notifications:**
- fcm - Firebase Cloud Messaging
- web-push 3.0.1+ - Web Push API for notifications

**Utilities & Helpers:**
- kaminari - Pagination
- pundit - Authorization
- wisper 2.0.0 - Pub/Sub event system
- liquid - Template engine for message templates
- jbuilder - JSON builder for API responses
- json_schemer - JSON Schema validation
- devise-secure_password (custom fork) - Enhanced password security
- acts-as-taggable-on - Tagging system

**Email Delivery:**
- actionmailer (Rails) - Primary email framework
- net-smtp 0.3.4 - SMTP protocol support
- gmail_xoauth - Gmail OAuth2 authentication
- resend gem - Resend.com email provider support (custom Mail provider)

## Configuration

**Environment:**
- dotenv-rails 3.0.0+ - Load `.env` files for environment variables
- Puma server via Procfile.dev (development) and Procfile (production)
- Rails credentials system (`config/credentials.yml.enc`) for secrets
- Environment-gated monitoring (Datadog, Sentry, etc. loaded only when env vars set)

**Build:**
- `vite.config.ts` - Vite configuration for Vue/JavaScript
- `tailwind.config.js` - Tailwind CSS customization
- `postcss.config.js` - PostCSS pipeline
- `config/sidekiq.yml` - Sidekiq queue configuration with ERB templating
- `.ruby-version` - Ruby version enforcement
- `.nvmrc` - Node version enforcement

**Rails Initializers (config/initializers/):**
- `actioncable.rb` - WebSocket (ActionCable) with Redis adapter
- `devise.rb` - Devise configuration
- `devise_token_auth.rb` - Token auth setup
- `stripe.rb` - Stripe API key initialization
- `sidekiq.rb` - Sidekiq queue setup, Redis connection
- `facebook_messenger.rb` - Facebook Messenger webhook handlers
- `searchkick.rb` - OpenSearch/Elasticsearch configuration
- `mailer.rb` - SMTP/Resend/SendMailer configuration
- `cors.rb` - CORS policy for widget and API
- `ai_agents.rb` - AI agent framework configuration
- `baileys.rb` - WhatsApp Baileys provider initialization
- `rack_attack.rb` - Rate limiting with Redis

## Platform Requirements

**Development:**
- Ruby 3.4.4 (via rvm or similar)
- Node 24.x (via nvm or similar)
- PostgreSQL 14+ (local or Docker)
- Redis 7+ (local or Docker)
- pnpm 10.x (Node package manager)
- Optional: Elasticsearch/OpenSearch for search features

**Production:**
- Deployment platform: Heroku, Docker, Kubernetes, or self-hosted VPS
- PostgreSQL managed service (AWS RDS, GCP Cloud SQL, etc.)
- Redis managed service (AWS ElastiCache, GCP Memorystore, etc.)
- S3-compatible object storage (AWS S3, Cloudflare R2, DigitalOcean Spaces, Minio)
- Optional: Elasticsearch/OpenSearch cluster for full-text search
- Requires: SMTP server or Resend account for email delivery

---

*Stack analysis: 2026-05-11*
