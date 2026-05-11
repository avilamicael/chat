# External Integrations

**Analysis Date:** 2026-05-11

## APIs & External Services

**Messaging & Channels:**
- **WhatsApp** (Multi-provider support)
  - Providers: Baileys (open-source, via `/home/micael/chatwoot_vps/baileys-api`), WhatsApp Cloud API, 360Dialog, Zapi
  - SDK/Client: `twilio-ruby`, custom Baileys integration
  - Configuration: `app/models/channel/whatsapp.rb`
  - Webhook: Incoming messages via `Webhooks::WhatsappMessagesJob`, `Webhooks::WhatsappStatusJob`
  - Provider service: `app/services/whatsapp/providers/`
  - Health checks: `Channels::Whatsapp::BaileysConnectionCheckSchedulerJob`
  - Credentials: Stored in `channel_whatsapp.provider_config` (JSONB), `provider_connection` (JSONB)

- **Twilio**
  - Services: SMS and WhatsApp messaging
  - SDK/Client: `twilio-ruby` gem
  - Configuration: `app/models/channel/twilio_sms.rb`
  - Authentication: Account SID + Auth Token or API Key auth
  - Credentials: `account_sid`, `auth_token`, `api_key_sid` (encrypted in DB)
  - Webhook: Delivery status callbacks to `twilio_delivery_status_index_url`

- **Facebook/Instagram**
  - SDK/Client: `facebook-messenger` gem, `koala` gem
  - Configuration: `app/models/channel/facebook_page.rb`, `app/models/channel/instagram.rb`
  - Provider: `app/services/instagram/providers/`, `app/services/facebook/providers/`
  - Webhook: `config/initializers/facebook_messenger.rb` (events routed to `Webhooks::FacebookEventsJob`, `Webhooks::FacebookDeliveryJob`)
  - Credentials: Page access tokens stored in `Channel::FacebookPage.page_access_token`

- **Slack**
  - SDK/Client: `slack-ruby-client` gem (~2.7.0)
  - Configuration: `app/models/channel/slack.rb` (if exists)
  - OAuth: Slack app token-based authentication
  - Webhook: Incoming messages, slash commands, interactive components
  - Credentials: Workspace token stored in channel config

- **Twitter/X**
  - SDK/Client: `twitty` gem (0.1.5)
  - Configuration: `app/models/channel/twitter_profile.rb`
  - Authentication: OAuth 1.0a or Bearer token
  - Webhook: Twitter account event subscriptions
  - Service: `app/services/twitter/webhook_subscribe_service.rb`

- **LINE Messaging**
  - SDK/Client: `line-bot-api` gem
  - Configuration: `app/models/channel/line.rb`
  - Webhook: Message callbacks
  - Credentials: Channel access token

- **TikTok**
  - Configuration: `app/models/channel/tiktok.rb`
  - Service: `app/services/tiktok/auth_client.rb` (webhook and OAuth flows)
  - Webhook: Message events via `update_webhook_callback`

- **Telegram**
  - Configuration: `app/models/channel/telegram.rb`

## Data Storage

**Databases:**
- **PostgreSQL**
  - Primary OLTP database
  - Version: Supports pg 1.5.3 driver
  - ORM: Rails ActiveRecord
  - Credentials: Configurable via `DATABASE_URL` env var or Rails database.yml
  - Extensions: pgvector (for embeddings), pg_search (full-text search)

**File Storage:**
- **AWS S3**
  - Client: `aws-sdk-s3` gem (1.208.0)
  - Connection: ENV vars `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET_NAME`
  - Rails integration: ActiveStorage configured via `config/storage.yml`

- **Google Cloud Storage**
  - Client: `google-cloud-storage` gem (1.48.0+)
  - Credentials: `GCS_PROJECT`, `GCS_CREDENTIALS`, `GCS_BUCKET` env vars
  - Rails integration: ActiveStorage (config/storage.yml)

- **Azure Blob Storage**
  - Client: `azure-storage-blob` gem (custom fork from Chatwoot)
  - Credentials: `AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_STORAGE_ACCESS_KEY`, `AZURE_STORAGE_CONTAINER`
  - Rails integration: ActiveStorage

- **S3-Compatible (R2, Spaces, Minio)**
  - Service: S3
  - Credentials: `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, `STORAGE_BUCKET_NAME`, `STORAGE_ENDPOINT`
  - Rails integration: ActiveStorage

- **Local Disk** (test/development default)
  - Root: `storage/` or `tmp/storage` (test)

**Search & Indexing:**
- **OpenSearch**
  - Client: `opensearch-ruby` gem (3.4.0)
  - Configuration: Conditional queue setup in `config/initializers/searchkick.rb`
  - Environment var: `OPENSEARCH_URL`
  - AWS integration: Optional AWS Signature v4 auth via `OPENSEARCH_AWS_ACCESS_KEY_ID`, `OPENSEARCH_AWS_SECRET_ACCESS_KEY`, `OPENSEARCH_AWS_REGION`
  - Library: `searchkick` gem provides abstraction

- **PostgreSQL Full-Text Search** (fallback)
  - Built-in via pg_search gem
  - Used if OpenSearch not configured

**Caching & Sessions:**
- **Redis**
  - Client: `redis` gem (5.0.6)
  - Uses: Sidekiq job queue, ActionCable WebSocket subscriptions, rate limiting (Rack::Attack), session/cache store
  - Configuration: `config/initializers/01_redis.rb`, `config/initializers/sidekiq.rb`
  - Connection: `Redis::Config.app` utility (defined in `lib/redis/config.rb`)
  - Env var: `REDIS_URL` or individual `REDIS_*` settings
  - Health checks: `sidekiq_alive` gem monitors Sidekiq via Redis

## Authentication & Identity

**Auth Provider:**
- **Local/Custom Implementation** (primary)
  - Framework: Devise 4.9.4 + Devise Token Auth
  - 2FA: Devise Two-Factor 6.1.0 (TOTP/SMS)
  - Strong password: `devise-secure_password` (custom Chatwoot fork)

- **OAuth 2.0 (Multi-provider)**
  - SDK/Client: `omniauth`, `omniauth-oauth2`, `omniauth-rails_csrf_protection`
  - Providers: Google, Microsoft (via omniauth-oauth2), SAML (omniauth-saml)
  - Libraries: `omniauth-google-oauth2`, `omniauth-oauth2` for refresh tokens

- **Gmail OAuth**
  - Library: `gmail_xoauth` gem
  - Use case: OAuth2-based email authentication for ActionMailbox

## Monitoring & Observability

**Error Tracking:**
- **Sentry** (optional, env-gated)
  - SDK: `sentry-rails`, `sentry-sidekiq`
  - Activation: ENV var `SENTRY_DSN`
  - Tracks: Rails exceptions, Sidekiq job failures
  - Configuration: Auto-initialized in `config/initializers/`

- **Datadog** (optional, env-gated)
  - SDK: `datadog` gem (2.19.0)
  - Activation: Checks for Datadog API key in environment
  - Tracks: APM, profiling, logs

- **Elastic APM** (optional, env-gated)
  - SDK: `elastic-apm` gem (4.6.2)
  - Tracks: Performance and error data to Elastic Cloud

- **Scout APM** (optional, env-gated)
  - SDK: `scout_apm` gem (5.3.3)

- **New Relic** (optional, env-gated)
  - SDK: `newrelic_rpm`, `newrelic-sidekiq-metrics`
  - Tracks: Application monitoring, Sidekiq job metrics

**Logs:**
- Framework: Rails Logger (default STDOUT)
- Optional: `lograge` gem (0.14.0, env-gated) for structured log aggregation
- Sidekiq: Custom logger that logs job pulls from Redis (`config/initializers/sidekiq.rb`)

**LLM Observability:**
- **OpenTelemetry**
  - SDKs: `opentelemetry-sdk`, `opentelemetry-exporter-otlp`
  - Purpose: Tracing LLM calls and AI agent execution
  - Configuration: `config/initializers/opentelemetry.rb` (if exists)

## CI/CD & Deployment

**Hosting:**
- Platform: Supports Heroku (with `barnes` metrics gem), Docker, Kubernetes, or self-hosted VPS
- Server: Puma 6.4.3 (configurable concurrency/workers)
- Process Manager: Foreman or Overmind (Procfile.dev for development)

**CI Pipeline:**
- Infrastructure: GitHub Actions (`.github/workflows/` present)
- Assumed: Docker builds, automated testing on pull requests

**Scaling:**
- Optional Heroku autoscaling via `judoscale-rails`, `judoscale-sidekiq` gems (production group)
- Request timeout: `rack-timeout` gem (production) prevents hanging requests

## Environment Configuration

**Required env vars (production):**
- Database: `DATABASE_URL` or `DB_HOSTNAME`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- Redis: `REDIS_URL` or individual Redis settings
- AWS: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET_NAME`
- Stripe: `STRIPE_SECRET_KEY`
- Sidekiq: `SIDEKIQ_CONCURRENCY` (default 10)

**Optional env vars (features/providers):**
- Twilio: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
- WhatsApp: Provider-specific configs (360Dialog, Cloud API, Baileys, Zapi)
- Baileys: `BAILEYS_PROVIDER_USE_INTERNAL_HOST_URL` (use internal service URL)
- Facebook/Instagram: `FACEBOOK_VERIFY_TOKEN`, page/app credentials
- Slack: OAuth credentials
- OpenSearch: `OPENSEARCH_URL`, `OPENSEARCH_AWS_*`
- Resend: `RESEND_API_KEY` (email delivery)
- SMTP: `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- Monitoring: `SENTRY_DSN`, `DATADOG_API_KEY`, `NEW_RELIC_LICENSE_KEY`, etc.
- Google Cloud: `GCS_PROJECT`, `GCS_CREDENTIALS`, `GCS_BUCKET`
- Azure: `AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_STORAGE_ACCESS_KEY`
- OpenAI: `OPENAI_API_KEY`

**Secrets location:**
- Rails credentials: `config/credentials.yml.enc` (decrypted via `config/master.key`)
- Environment variables: `.env` file (development), production secrets manager (AWS Secrets Manager, Heroku Config Vars, etc.)
- **NEVER commit `.env` file or `master.key`**

## Webhooks & Callbacks

**Incoming Webhooks (from external services to Chatwoot):**
- **WhatsApp Cloud API**: POST `/api/v1/webhooks/whatsapp/` → routes to `Webhooks::WhatsappMessagesJob`, `Webhooks::WhatsappStatusJob`
- **Baileys**: Internal integration via `/home/micael/chatwoot_vps/baileys-api` (sibling repo)
  - Connection: HTTP POST to Chatwoot API endpoints
  - Status: Monitored by `Channels::Whatsapp::BaileysConnectionCheckSchedulerJob`
- **Twilio**: Delivery status callbacks → `twilio_delivery_status_index_url`
- **Facebook Messenger**: Webhook events → `Webhooks::FacebookEventsJob`, `Webhooks::FacebookDeliveryJob`
- **Instagram**: POST `/api/v1/webhooks/instagram/` → similar event routing
- **Slack**: OAuth, message events, interactive components
- **Twitter**: POST `/api/v1/webhooks/twitter/` → `Webhooks::TwitterEventsJob`
- **TikTok**: Configured via `update_webhook_callback` in auth client

**Outgoing Webhooks (from Chatwoot to user-configured URLs):**
- **Kanban Webhook**: `app/jobs/kanban/webhook_job.rb`
  - Purpose: POST kanban event payloads to user-defined URLs
  - Method: Net::HTTP POST with JSON body
  - Retry: None (background job with error logging only)
  - Timeout: 5s open, 10s read
  - Triggered by: Kanban state changes (cards, boards, etc.)
  - Logging: Info on success (response code), error on failure
  - Configuration: Webhook URL stored in kanban model/integration config

- **Macro Webhooks**: `app/services/macros/execution_service.rb`
  - Purpose: Execute webhook actions as part of macro automation
  - Method: `send_webhook_event(webhook_url)` - POST with action/conversation context

**API Callbacks & Polling:**
- WhatsApp Health Check: `Channels::Whatsapp::BaileysConnectionCheckSchedulerJob` polls Baileys API for connection status (scheduled job via Sidekiq-Cron)
- Message Status Polling: May use polling for delivery/read receipts on some channels

## Payment & Billing

**Stripe**
- SDK/Client: `stripe` gem (~18.0)
- Configuration: `config/initializers/stripe.rb`
- API Key: `STRIPE_SECRET_KEY` env var
- Use: Subscription management, payment processing, billing
- Webhook: Incoming stripe events (if webhook endpoint configured)
- Models: `Account` model integrates with Stripe (plan, subscription, billing)

## LLM & AI Services

**OpenAI**
- SDK/Client: `ruby-openai` gem (7.3.1)
- Configuration: API key via `OPENAI_API_KEY` env var
- Uses: Response bot, text generation, embeddings (via AI agents)

**Google Cloud AI**
- Dialogflow V2: `google-cloud-dialogflow-v2` gem (0.24.0+)
  - Use: Intent detection, NLU
- Translation: `google-cloud-translate-v3` gem (0.7.0+)
  - Use: Message translation

**AI Agents Framework**
- Library: `ai-agents` gem (0.9.1)
- Supporting libs: `ruby_llm` (1.8.2+), `ruby_llm-schema`
- Purpose: Orchestrate multi-step AI workflows, routing, function calling
- Configuration: `config/initializers/ai_agents.rb`
- Observability: OpenTelemetry for tracing

**Vector Search (Embeddings)**
- PostgreSQL: pgvector extension + `neighbor` gem
- Use: Semantic search for knowledge bases, responses, articles
- Language detection: `cld3` gem (3.7) for multi-language support

## Email & Messaging

**Email Delivery:**
- **Primary Framework**: ActionMailer (Rails)
- **Delivery Methods** (configurable via `config/initializers/mailer.rb`):
  - SMTP (standard): `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
  - Resend: `RESEND_API_KEY` (custom Mail provider in `lib/mail/resend_provider.rb`)
  - Sendmail: Falls back if `SMTP_ADDRESS` is blank
- **Email Ingest**: ActionMailbox with AWS SES (`aws-actionmailbox-ses` gem)
  - Routes incoming email to conversations

**Email Utilities:**
- `gmail_xoauth` gem: OAuth2 for Gmail authentication
- `email_reply_trimmer` gem: Strip quoted replies from inbound emails
- `html2text` gem: Convert HTML emails to plain text

## Infrastructure & Utilities

**Message Templating:**
- `liquid` gem: Render message templates with variables (for broadcast messages, macros)

**Document Processing:**
- `reverse_markdown` gem: Convert HTML to Markdown (for knowledge base, articles)
- `image_processing` gem: Image resizing/optimization for attachments
- `streamio-ffmpeg` gem (~3.0): Video processing metadata

**Geocoding:**
- `geocoder` gem: IP geolocation for visitor tracking
- `maxminddb` gem: MaxMind database parsing for offline geolocation

**Database Utilities:**
- `hairtrigger` gem: Define database triggers in Ruby migrations
- `activerecord-import` gem: Bulk insert optimization
- `groupdate` gem: Group query results by date ranges

**Pub/Sub & Events:**
- `wisper` gem (2.0.0): In-app pub/sub for decoupled event handling

**Testing Utilities (test/dev):**
- `webmock` gem: HTTP mocking for API tests
- `database_cleaner` gem: Test database cleanup
- `mock_redis` gem: Redis mock for testing
- `factory_bot_rails` gem: Test data factories

---

*Integration audit: 2026-05-11*
