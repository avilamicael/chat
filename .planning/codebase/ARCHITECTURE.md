<!-- refreshed: 2026-05-11 -->
# Architecture

**Analysis Date:** 2026-05-11

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           HTTP Request Entry                             │
│  Rails Routing (config/routes.rb): /api/v1, /api/v2, /app, webhooks   │
└──────────────────────┬──────────────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ API v1       │ │ API v2       │ │ Dashboard    │
│ Controllers  │ │ Controllers  │ │ View (Vue)   │
│ `app/        │ │ `app/        │ │ `config/     │
│ controllers/ │ │ controllers/ │ │ routes.rb`   │
│ api/v1/*`    │ │ api/v2/*`    │ │              │
└────┬─────────┘ └────┬─────────┘ └──────┬───────┘
     │                │                  │
     └────────────────┼──────────────────┘
                      │
                      ▼
        ┌─────────────────────────────────────┐
        │      Service Layer (Business Logic) │
        │  app/services/*                     │
        │  - Kanban::CardMoveService          │
        │  - Kanban::BoardTemplateService     │
        │  - Kanban::AutoPopulateService      │
        │  - Kanban::ColumnActionsService     │
        └──────────────┬──────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│ Model Layer  │ │ Builders     │ │ Event Dispatcher │
│ `app/models/*│ │ `app/        │ │ `app/dispatchers/│
│              │ │ builders/*`  │ │ dispatcher.rb`   │
└──────────────┘ └──────────────┘ └────────┬─────────┘
                                           │
        ┌──────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────┐
│  Event Listeners (app/listeners/)            │
│  - KanbanListener                            │
│  - WebhookListener                           │
│  - HookListener                              │
│  - NotificationListener                      │
│  - ActionCableListener                       │
└──────┬──────────────────────────────────────┘
       │
       ├──────────────────┬──────────────────┐
       │                  │                  │
       ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│ Sidekiq Jobs │  │ ActionCable  │  │ Database Models  │
│ `app/jobs/*` │  │ Broadcasts   │  │ `app/models/*`   │
│              │  │              │  │                  │
│ Background   │  │ Real-time    │  │ PostgreSQL       │
│ Processing   │  │ Push Events  │  │                  │
└──────────────┘  └──────────────┘  └──────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Controllers (API v1) | HTTP request handling, authorization, response formatting | `app/controllers/api/v1/accounts/*` |
| Controllers (API v2) | v2 API endpoints (reporting, summaries, analytics) | `app/controllers/api/v2/accounts/*` |
| Services | Business logic, state transitions, validation | `app/services/*` |
| Models | Data persistence, relationships, validations | `app/models/*` |
| Builders | Complex object construction with relationships | `app/builders/*` |
| Jobs | Async background processing via Sidekiq | `app/jobs/*` |
| Listeners | Event subscription and handling (sync/async) | `app/listeners/*` |
| Dispatcher | Pub/sub event distribution system | `app/dispatchers/dispatcher.rb` |
| Kanban Models | Cards, columns, boards, tasks (linked to conversations) | `app/models/kanban_*.rb` |
| Vue SPA | Frontend dashboard (Vue 3 Composition API) | `app/javascript/dashboard/*` |

## Pattern Overview

**Overall:** Rails 7 MVC + Vue 3 SPA + Event-Driven Pub/Sub Architecture

**Key Characteristics:**
- **Monolithic Rails backend**: Central request processing, database abstraction, business logic
- **Vue 3 frontend**: Composition API, real-time updates via WebSocket/ActionCable
- **Event-driven**: Service actions dispatch events through `Dispatcher` singleton → listeners execute sync and async work
- **Background jobs**: Sidekiq for async tasks (webhooks, broadcasts, state changes)
- **Account scoped**: Multi-tenant design with `Current.account` context throughout request lifecycle

## Layers

**HTTP Layer:**
- Purpose: Accept requests, route to appropriate controller action
- Location: `config/routes.rb`, `app/controllers/*`
- Contains: Controller definitions (API v1, v2, Dashboard, webhooks)
- Depends on: ApplicationController (base), Devise auth, Pundit authorization
- Used by: Client applications (browsers, SDKs, webhooks)

**Application Layer (Controllers → Services):**
- Purpose: Parse params, validate authorization, invoke business logic, format response
- Location: `app/controllers/api/v{1,2}/accounts/*`, `app/services/*`
- Contains: Controller actions calling service objects; services implementing business rules
- Depends on: Models, builders, authorization policies
- Used by: HTTP handlers, background jobs

**Domain Layer (Models):**
- Purpose: Data persistence, relationships, domain validation
- Location: `app/models/*` (KanbanBoard, KanbanCard, KanbanColumn, Conversation, Account, etc.)
- Contains: Active Record models with scopes, callbacks, associations
- Depends on: Database schema, validations, concerns (auditing, multi-tenancy)
- Used by: Services, builders, controllers, listeners

**Event Publishing & Subscription:**
- Purpose: Decouple components via event-driven messaging
- Location: `app/dispatchers/dispatcher.rb`, `app/listeners/*`
- Contains: Dispatcher singleton (manages sync/async dispatchers), listener classes (subscribe to events)
- Depends on: Events::Types constants, listener registration
- Used by: Services (dispatch events), listeners (process events)

**Background Processing (Jobs):**
- Purpose: Execute time-consuming or scheduled tasks asynchronously
- Location: `app/jobs/*`
- Contains: Sidekiq job classes (ActionCableBroadcastJob, WebhookJob, HookJob, etc.)
- Depends on: Sidekiq, Event listeners triggering jobs
- Used by: Listeners, controllers (enqueue work via `perform_later`)

**Real-time Push:**
- Purpose: Push events to connected clients over WebSocket
- Location: `app/listeners/action_cable_listener.rb`, `app/jobs/action_cable_broadcast_job.rb`
- Contains: ActionCable message broadcasting by account/user tokens
- Depends on: ActionCable server, client websocket connections
- Used by: Frontend to receive real-time updates (conversations, kanban cards, notifications)

**Frontend (Vue 3 SPA):**
- Purpose: User interface for dashboard, kanban boards, inboxes, conversations
- Location: `app/javascript/dashboard/*`
- Contains: Vue components (Composition API), routes, stores (state management), API clients
- Depends on: Rails backend API, ActionCable WebSocket, i18n
- Used by: Web browsers, agents/admins

## Data Flow

### Primary Request Path: Create Kanban Board

1. POST `/api/v1/accounts/:account_id/kanban_boards` → `KanbanBoardsController#create` (`app/controllers/api/v1/accounts/kanban_boards_controller.rb:14`)
2. Validate authorization via `check_authorization` (Pundit policy)
3. Create board: `Current.account.kanban_boards.create!(board_params)` (calls `KanbanBoard` model save)
4. Apply template: `Kanban::BoardTemplateService.new(board:, template:, locale:).perform` (`app/services/kanban/board_template_service.rb`)
   - Service creates default kanban columns (e.g., "Open", "Won", "Lost") based on template
   - Reload columns and return to client
5. Dispatch event: `Rails.configuration.dispatcher.dispatch(Events::Types::KANBAN_BOARD_UPDATED, Time.zone.now, board: @board)` (implicit, may happen in listener)
6. Response: JSON serialization of board with columns

### Kanban Card Movement & Updates

1. PUT `/api/v1/accounts/:account_id/kanban_boards/:board_id/kanban_cards/:card_id` → `KanbanCardsController#update` 
2. Service invoked: `Kanban::CardMoveService.new(card, { column_id:, position: }, user).perform` (`app/services/kanban/card_move_service.rb:11`)
   - Update card column and position (without auditing if same column)
   - If column changed:
     - Record move audit log
     - Sync conversation status if target column has status mapping (`conversation.send(:"#{status}!")`)
     - Run exit actions on source column (e.g., mark lost, update labels)
     - Run enter actions on target column
   - Dispatch `KANBAN_CARD_MOVED` event with card, board, source/target columns, column_changed flag
3. Event listener triggered: `KanbanListener#kanban_card_moved` (`app/listeners/kanban_listener.rb:87`)
   - Execute column enter/exit actions via `Kanban::ColumnActionsService`
   - Reload card with associations (conversation, contact, inbox, assignee)
   - Broadcast to account via ActionCable: `'kanban.card_moved'` event
4. Job enqueued: `ActionCableBroadcastJob.perform_later(tokens, 'kanban.card_moved', { card:, board_id:, source_column_id:, target_column_id:, column_changed: })` (`app/jobs/action_cable_broadcast_job.rb:13`)
5. ActionCable broadcasts to WebSocket clients (listening on `account_#{account_id}` channel)
6. Frontend receives `kanban.card_moved` message, updates Vuex store, re-renders board

### Outbound Webhook Dispatch: Kanban::WebhookJob Pattern

1. **Event triggered** (e.g., conversation status changes, kanban card moves)
2. **Event listener invoked** (sync, in request context)
   - Example: `KanbanListener#conversation_status_changed` detects status change
   - Updates kanban card status
   - Broadcasts card update (see above flow)
3. **Webhook listener processes event** (sync): `WebhookListener#conversation_status_changed`
   - Extracts payload from conversation
   - Calls `deliver_webhook_payloads(payload, inbox)` → `HookListener` or `WebhookListener` (different listener base class for delivery)
   - Enqueues webhook delivery jobs for registered webhooks
4. **Kanban::WebhookJob** processes async:
   - Location: `app/jobs/kanban/webhook_job.rb`
   - Input: URL (webhook endpoint) and payload (JSON)
   - Method: `perform(url, payload)` - Makes synchronous HTTP POST to external URL with 5s open timeout, 10s read timeout
   - Logs success (code) and errors; rescues all exceptions (no retry)
   - **Primary use case**: Custom integrations receiving kanban events (e.g., third-party project management, CRM updates)

### Conversation → Kanban Auto-Population

1. Conversation created event: `CONVERSATION_CREATED` dispatched
2. `KanbanListener#conversation_created` listens (sync):
   - Calls `Kanban::AutoPopulateService.new(conversation).perform` (`app/services/kanban/auto_populate_service.rb`)
   - Service finds account's default kanban board (or boards with matching filters)
   - Creates kanban card in board's intake column, linked to conversation
   - Calls `Kanban::CardCreationService` to perform card creation with events
3. Card creation event dispatched: `KANBAN_CARD_ADDED`
4. `KanbanListener#kanban_card_added` listens:
   - Executes enter actions for intake column
   - Broadcasts card to connected dashboard clients via ActionCable

**State Management:**
- Controller request sets `Current.account = account` via `set_current_account` before action
- Service inherits account context from models' associations
- Event dispatch includes account in data payload
- Listeners broadcast to `account_#{account.id}` channel (all users in that account)
- Async jobs re-fetch necessary records to ensure correct context

## Key Abstractions

**Service Objects:**
- Purpose: Encapsulate business logic, single responsibility
- Examples: `Kanban::CardMoveService`, `Kanban::AutoPopulateService`, `Kanban::BoardTemplateService`
- Pattern: Initialize with params, call `perform` method, return result

**Builders:**
- Purpose: Complex object construction (often with nested relationships)
- Examples: `AccountBuilder`, `ContactInboxBuilder`, `ContactInboxWithContactBuilder`
- Pattern: Initialize with options, call public method to construct, return fully-built object

**Listeners:**
- Purpose: React to domain events (triggered by services via Dispatcher)
- Examples: `KanbanListener`, `WebhookListener`, `HookListener`, `ActionCableListener`
- Pattern: Inherit from `BaseListener`, define method for each event type (e.g., `kanban_card_moved`), call helper methods to trigger side effects (broadcast, enqueue jobs)

**Models:**
- Purpose: Data persistence and relationships
- Core kanban models:
  - `KanbanBoard` (`app/models/kanban_board.rb`): Top-level board entity, scoped to account
  - `KanbanColumn` (`app/models/kanban_column.rb`): Column in board (e.g., Open, Won, Lost), has position, conversation_status mapping, enter/exit actions
  - `KanbanCard` (`app/models/kanban_card.rb`): Task card, linked to conversation, has position, status, priority, assignee(s), team(s), due_date, title, description
  - `KanbanCardConversation` (`app/models/kanban_card_conversation.rb`): Join model (many-to-many or tracking)

**Events & Event Types:**
- Purpose: Publish state changes so listeners can react
- Location: `lib/events/types.rb` (constants), dispatched via `Rails.configuration.dispatcher.dispatch(Events::Types::EVENT_NAME, timestamp, data)`
- Key kanban events:
  - `KANBAN_CARD_ADDED`: Card inserted into board
  - `KANBAN_CARD_MOVED`: Card moved to different column or position
  - `KANBAN_CARD_REMOVED`: Card deleted
  - `KANBAN_BOARD_UPDATED`: Board renamed/updated

## Entry Points

**API v1 Kanban Endpoints:**
- Location: `app/controllers/api/v1/accounts/kanban_boards_controller.rb`
- Triggers: Board CRUD, conversation_card lookup
- Responsibilities: Validate params, check authorization, invoke services, format JSON response

**Webhook Entry Points:**
- Location: `app/controllers/public/` or `app/controllers/webhooks/`
- Triggers: Inbound events from external providers (Facebook, Instagram, Telegram, etc.)
- Responsibilities: Parse provider webhook payload, dispatch internal event (e.g., `CONVERSATION_CREATED`)

**Dashboard Frontend:**
- Location: `app/javascript/dashboard/`
- Triggers: User navigation to `/app/accounts/:account_id/kanban` or `/app/accounts/:account_id/boards`
- Responsibilities: Render Vue components, fetch board data, subscribe to real-time updates

**CLI Seeding:**
- Location: `app/services/seeders/` or `Internal::SeedAccountJob`
- Triggers: Rails runner or Super Admin UI
- Responsibilities: Create test data (boards, columns, cards, conversations)

## Architectural Constraints

- **Threading:** Single-threaded Rails request handling; Sidekiq workers run in separate threads/processes. ActionCable maintains persistent WebSocket connections.
- **Global state:** `Current` gem provides thread-safe request context (`Current.account`, `Current.user`, `Current.account_user`). Dispatcher is singleton, but thread-safe (via SyncDispatcher and AsyncDispatcher instances).
- **Circular imports:** Service → Model → Model associations are acyclic. Listeners do NOT import services; they call them via dispatcher pattern to break coupling.
- **Multi-tenancy:** All models scoped to Account. Controllers enforce authorization via Pundit policies. WebSocket broadcasts scoped to account token.
- **Event ordering:** Dispatcher runs sync listeners in-request, then queues async jobs. No guaranteed order between async jobs; UI uses optimistic updates.

## Anti-Patterns

### Direct Service Calls in Listeners

**What happens:** A listener imports a service and calls it directly (tight coupling)
**Why it's wrong:** Hard to test; listeners become dependent on service signatures; difficult to reuse listener logic
**Do this instead:** Use the event dispatcher pattern: services dispatch events, listeners react. If cross-listener communication is needed, dispatch intermediate events or use a coordinator service called by both listeners.

### Missing Event Dispatch After State Change

**What happens:** A service modifies data but doesn't dispatch an event, so listeners never respond
**Why it's wrong:** Derived state (ActionCable broadcasts, webhooks, notifications) doesn't update; frontend gets stale data
**Do this instead:** Always dispatch relevant event at end of service perform method (see `Kanban::CardMoveService#dispatch_card_moved`). If unsure of event type, check `Events::Types` for existing event or create one.

### Synchronous HTTP Calls in Request Context

**What happens:** Webhook delivery happens in the request handler, blocking until external service responds
**Why it's wrong:** Request timeouts, slow external API degrades user experience
**Do this instead:** Enqueue job for webhook delivery (see `Kanban::WebhookJob`). Listener receives event, enqueues job with URL and payload, job retries on failure.

### Unscoped Model Queries in Multi-Tenant Context

**What happens:** A service queries `KanbanBoard.find(id)` without account scope
**Why it's wrong:** Security issue; users can access boards from other accounts
**Do this instead:** Always scope through account: `Current.account.kanban_boards.find(id)` or `account.kanban_boards.find(id)` if account is passed as param.

## Error Handling

**Strategy:** Graceful degradation with error logging and optional exception tracking (ChatwootExceptionTracker)

**Patterns:**
- Controllers: Rescue exceptions via `ApplicationController#handle_with_exception` (RequestExceptionHandler concern), return JSON error with HTTP status
- Services: Raise custom exceptions (`lib/custom_exceptions/`) for validation errors; catch and log operational failures (e.g., external API errors)
- Listeners: Rescue StandardError, log, and notify exception tracker (don't crash processing)
- Jobs: Rescue all exceptions (Sidekiq default behavior), log, optional retry logic

## Cross-Cutting Concerns

**Logging:** Rails logger (configured in `config/initializers/`). Services log state transitions; listeners log broadcast/job enqueue events. Use structured logging (lograge) for request metrics.

**Validation:** Models enforce business rules via Active Record validations. Controllers accept strong params (whitelist). Services validate domain constraints (e.g., board limit checks in `KanbanBoardsController#validate_board_limit`).

**Authentication:** Devise Token Auth via `mount_devise_token_auth_for 'User'` in routes. Controllers verify user context via `Current.user` set in `ApplicationController#set_current_user`.

**Authorization:** Pundit policies in `app/policies/`. Controllers call `authorize_policy_and_user!` or custom `check_authorization` methods. Define policy rules in `app/policies/{resource}_policy.rb`.

---

*Architecture analysis: 2026-05-11*
