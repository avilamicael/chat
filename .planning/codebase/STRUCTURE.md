# Codebase Structure

**Analysis Date:** 2026-05-11

## Directory Layout

```
chatwoot/
├── app/                          # Rails application code
│   ├── assets/                   # Asset pipeline files (images, icons, etc.)
│   ├── builders/                 # Object builders (complex construction patterns)
│   ├── channels/                 # ActionCable WebSocket channel definitions
│   ├── controllers/              # HTTP request handlers
│   │   ├── api/                  # REST API endpoints
│   │   │   ├── v1/               # API v1 (core endpoints)
│   │   │   │   └── accounts/     # Account-scoped routes
│   │   │   │       ├── kanban_boards_controller.rb
│   │   │   │       ├── kanban_boards/
│   │   │   │       └── [other resource controllers]
│   │   │   └── v2/               # API v2 (reporting, analytics)
│   │   ├── devise_overrides/     # Devise auth customizations
│   │   ├── public/               # Public webhook receivers
│   │   ├── super_admin/          # Admin panel controllers
│   │   └── dashboard_controller.rb # Renders Vue SPA
│   ├── dispatchers/              # Event dispatcher system
│   │   ├── dispatcher.rb         # Main dispatcher (singleton)
│   │   ├── sync_dispatcher.rb    # Runs listeners inline
│   │   └── async_dispatcher.rb   # Queues async listeners
│   ├── jobs/                     # Sidekiq background jobs
│   │   ├── kanban/               # Kanban-specific jobs
│   │   │   └── webhook_job.rb    # Async webhook delivery
│   │   ├── action_cable_broadcast_job.rb # WebSocket push
│   │   ├── webhook_job.rb        # Generic webhook dispatch
│   │   └── [other job types]/
│   ├── javascript/               # Frontend Vue 3 SPA + assets
│   │   ├── dashboard/            # Main dashboard application
│   │   │   ├── api/              # API client modules (fetch wrappers)
│   │   │   │   └── kanban.js     # Kanban API endpoints
│   │   │   ├── routes/           # Vue Router route definitions
│   │   │   │   └── dashboard/
│   │   │   │       ├── kanban/   # Kanban board routes
│   │   │   │       │   ├── kanban.routes.js
│   │   │   │       │   ├── KanbanBoard.vue
│   │   │   │       │   ├── KanbanBoardSettings.vue
│   │   │   │       │   ├── KanbanBoardHistory.vue
│   │   │   │       │   └── components/
│   │   │   │       │       ├── KanbanColumn.vue
│   │   │   │       │       ├── KanbanCard.vue
│   │   │   │       │       └── KanbanColumnSettingsModal.vue
│   │   │   │       └── [other routes]/
│   │   │   ├── store/            # Vuex/Pinia state management
│   │   │   │   └── modules/
│   │   │   │       └── kanban/   # Kanban state (board, columns, cards)
│   │   │   ├── components/       # Reusable Vue components
│   │   │   ├── components-next/  # Next-generation components (message bubbles, etc.)
│   │   │   ├── composables/      # Vue 3 Composition API hooks
│   │   │   ├── i18n/             # Internationalization (translations)
│   │   │   │   └── locale/
│   │   │   │       ├── en/       # English translations
│   │   │   │       │   └── kanban.json
│   │   │   │       └── pt_BR/    # Portuguese (Brazil) translations
│   │   │   └── helper/           # Utility functions
│   │   ├── widget/               # Chat widget application (separate SPA)
│   │   ├── portal/               # Knowledge base portal
│   │   ├── survey/               # Survey application
│   │   ├── shared/               # Shared utilities across apps
│   │   └── entrypoints/          # Vite entry files
│   ├── listeners/                # Event subscribers (react to domain events)
│   │   ├── kanban_listener.rb    # Kanban event handlers
│   │   ├── webhook_listener.rb   # Webhook event handlers
│   │   ├── hook_listener.rb      # Integration hook handlers
│   │   ├── action_cable_listener.rb # WebSocket broadcast handlers
│   │   └── base_listener.rb      # Base class for all listeners
│   ├── models/                   # Active Record models (data persistence)
│   │   ├── kanban_board.rb       # Board entity
│   │   ├── kanban_column.rb      # Column in board
│   │   ├── kanban_card.rb        # Task card
│   │   ├── kanban_card_conversation.rb # Card-conversation relationship
│   │   ├── conversation.rb       # Core conversation model
│   │   ├── account.rb            # Multi-tenant account
│   │   ├── user.rb               # User/agent
│   │   └── [other models]/
│   ├── services/                 # Business logic (Service Objects)
│   │   ├── kanban/               # Kanban-specific services
│   │   │   ├── card_move_service.rb      # Move card to column/position
│   │   │   ├── card_creation_service.rb  # Create new card
│   │   │   ├── auto_populate_service.rb  # Auto-create card from conversation
│   │   │   ├── board_template_service.rb # Apply board template
│   │   │   ├── column_actions_service.rb # Run column enter/exit actions
│   │   │   └── column_action_service.rb  # Legacy action runner
│   │   ├── conversations/        # Conversation services
│   │   ├── contacts/             # Contact services
│   │   └── [other service domains]/
│   ├── views/                    # ERB templates (mainly for admin/auth)
│   ├── mailers/                  # Action Mailer classes
│   ├── helpers/                  # View helpers
│   ├── policies/                 # Pundit authorization policies
│   │   └── kanban_board_policy.rb
│   ├── presenters/               # Serializers for API responses
│   ├── concerns/                 # Shared modules (mixed into models/controllers)
│   └── [other Rails dirs]/
├── config/                       # Rails configuration
│   ├── routes.rb                 # Route definitions (API v1, v2, dashboard, webhooks)
│   ├── initializers/             # Runtime initialization
│   │   ├── event_handlers.rb     # Dispatcher setup, listener registration
│   │   └── [other initializers]/
│   ├── environments/             # Environment-specific configs
│   └── [other Rails configs]/
├── db/                           # Database schema and migrations
│   ├── migrate/                  # Schema migrations
│   │   ├── 20260323162457_create_kanban_boards.rb
│   │   ├── 20260323162458_create_kanban_columns.rb
│   │   ├── 20260323162459_create_kanban_cards.rb
│   │   └── [other migrations]/
│   ├── schema.rb                 # Current schema dump
│   └── seeds.rb                  # Seed data (development)
├── lib/                          # Non-Rails libraries
│   ├── events/                   # Event types and constants
│   │   └── types.rb              # Events::Types constants
│   ├── custom_exceptions/        # Custom exception classes
│   └── [other utilities]/
├── spec/                         # RSpec test suite
│   ├── controllers/              # Controller specs
│   ├── models/                   # Model specs
│   ├── services/                 # Service specs
│   ├── jobs/                     # Job specs
│   └── [other specs]/
├── enterprise/                   # Enterprise Edition overrides
│   ├── app/                      # Enterprise-specific code (mirrors app/)
│   ├── config/                   # Enterprise config
│   └── spec/                     # Enterprise specs
├── public/                       # Static files served by web server
├── package.json                  # JavaScript dependencies (pnpm)
├── Gemfile                       # Ruby dependencies
├── Procfile.dev                  # Local development processes (overmind)
├── Procfile.build                # Vite build processes
├── config.ru                     # Rack app entry point
├── Rakefile                      # Rake tasks
└── .env.example                  # Environment variable template
```

## Directory Purposes

**app/**: Rails application code - models, controllers, views, business logic
**app/controllers/api/v1/accounts/**: Core API endpoints, account-scoped routes
**app/javascript/dashboard/**: Vue 3 dashboard SPA (agents, admins, conversation management, kanban boards)
**app/javascript/dashboard/routes/dashboard/kanban/**: Kanban-specific routes and page components
**app/javascript/dashboard/store/modules/kanban/**: Vuex/Pinia state for kanban (board, columns, cards)
**app/listeners/**: Event subscribers (react to domain events via Dispatcher)
**app/services/**: Business logic encapsulation (Service Objects pattern)
**app/services/kanban/**: Kanban board, card, and column management services
**app/jobs/**: Sidekiq background job workers (async processing)
**app/jobs/kanban/**: Kanban-specific jobs (webhook dispatch)
**app/models/**: Active Record data models (persistence, relationships, validations)
**app/dispatchers/**: Event publisher (singleton dispatcher, sync/async dispatchers)
**config/**: Rails configuration, routes, initializers
**db/**: Database schema, migrations, seed data
**lib/**: Libraries, custom exceptions, utilities
**spec/**: RSpec test suite (unit, integration, system tests)
**enterprise/**: Enterprise Edition code (overrides, extensions)

## Key File Locations

**Entry Points:**
- `config/routes.rb`: All route definitions (API v1, v2, public webhooks, dashboard)
- `app/controllers/api/v1/accounts/kanban_boards_controller.rb`: Kanban board HTTP handlers
- `app/controllers/dashboard_controller.rb`: Vue SPA entry (renders layout, sets global config)
- `app/javascript/dashboard/routes/dashboard/kanban/kanban.routes.js`: Kanban route definitions

**Configuration:**
- `config/initializers/event_handlers.rb`: Dispatcher initialization, listener loading
- `config/routes.rb`: Route namespace structure (API v1 scoped to accounts, v2 for reporting)
- `.env.example`: Environment variable reference
- `package.json`: JavaScript dependency versions

**Core Logic:**
- `app/models/kanban_board.rb`: Board model, associations to columns
- `app/models/kanban_column.rb`: Column model, position, conversation_status, enter/exit actions
- `app/models/kanban_card.rb`: Card model, linked to conversation, has task fields (status, priority, due_date, assignee, team)
- `app/services/kanban/card_move_service.rb`: Primary kanban service (move card, sync conversation, run actions, dispatch event)
- `app/services/kanban/auto_populate_service.rb`: Auto-create card from conversation
- `app/listeners/kanban_listener.rb`: Kanban event subscribers (card moved, conversation status changed, etc.)
- `app/jobs/kanban/webhook_job.rb`: Async webhook delivery (HTTP POST to external URL)

**Testing:**
- `spec/services/kanban/`: Kanban service specs
- `spec/models/kanban_*.rb`: Model specs
- `spec/jobs/kanban/`: Job specs
- `spec/listeners/kanban_listener_spec.rb`: Event listener specs

## Naming Conventions

**Files:**
- `snake_case.rb` for Ruby files (models, controllers, services, jobs)
- `PascalCase.vue` for Vue components
- `camelCase.js` for JavaScript modules
- `snake_case.json` for translation files

**Directories:**
- `snake_case/` for feature grouping (kanban, conversations, contacts)
- `v1/`, `v2/` for API versioning

**Models:**
- `KanbanBoard`: Top-level board
- `KanbanColumn`: Column in board
- `KanbanCard`: Card/task in column
- `KanbanCardConversation`: Relationship model (cards may be linked to conversations)

**Controllers:**
- `Api::V1::Accounts::KanbanBoardsController`: API v1 endpoint (boards)
- `Api::V1::Accounts::Kanban::KanbanColumnsController`: API v1 endpoint (columns, nested under board)

**Services:**
- `Kanban::CardMoveService`: Move card to column/position
- `Kanban::BoardTemplateService`: Apply template to board (create columns)
- `Kanban::AutoPopulateService`: Auto-create card from conversation
- `Kanban::ColumnActionsService`: Run enter/exit actions on column change

**Jobs:**
- `Kanban::WebhookJob`: Dispatch webhook to external URL
- `ActionCableBroadcastJob`: Broadcast event to WebSocket clients
- `HookJob`: Execute integration hook (Slack, Dialogflow, etc.)

**Listeners:**
- `KanbanListener`: React to kanban events (card added/moved/removed, board updated)
- `WebhookListener`: React to conversations/messages, dispatch webhooks
- `HookListener`: React to integration-specific events
- `ActionCableListener`: React to events, enqueue broadcast jobs

**Vue Components:**
- `KanbanBoard.vue`: Main board page
- `KanbanColumn.vue`: Single column (draggable container)
- `KanbanCard.vue`: Single card (draggable item, clickable for details)
- `KanbanColumnSettingsModal.vue`: Column configuration modal

**Events:**
- `KANBAN_CARD_ADDED`: Event type (const in `Events::Types`)
- `KANBAN_CARD_MOVED`: Event type
- `KANBAN_BOARD_UPDATED`: Event type

**Routes:**
- `/app/accounts/:account_id/kanban` - Main kanban dashboard
- `/app/accounts/:account_id/kanban/settings` - Board/column settings
- `/api/v1/accounts/:account_id/kanban_boards` - Board CRUD
- `/api/v1/accounts/:account_id/kanban_boards/:board_id/kanban_columns` - Column CRUD
- `/api/v1/accounts/:account_id/kanban_columns/:column_id/kanban_cards` - Card CRUD

## Where to Add New Code

**New Feature (e.g., Kanban Card Template):**
- Primary code: `app/services/kanban/card_template_service.rb` (business logic)
- Model: `app/models/kanban_card_template.rb` (data persistence)
- Controller: Add action to `app/controllers/api/v1/accounts/kanban_boards_controller.rb` (HTTP handler)
- Frontend: Add Vue component `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCardTemplate.vue`
- Tests: `spec/services/kanban/card_template_service_spec.rb`, `spec/models/kanban_card_template_spec.rb`

**New Component/Module (e.g., Kanban Reporting):**
- Implementation:
  - Backend: `app/services/kanban/reporting_service.rb` (calculation logic)
  - Controller: `app/controllers/api/v2/accounts/kanban_reports_controller.rb` (use v2 for new analytics endpoints)
  - Model: Add scopes/associations to `KanbanCard` or create new model if complex
  - Job: Only if async calculation needed
- Tests: `spec/services/kanban/reporting_service_spec.rb`, `spec/controllers/api/v2/accounts/kanban_reports_controller_spec.rb`
- Frontend: `app/javascript/dashboard/routes/dashboard/settings/reports/KanbanReports.vue` (already exists, extend)

**Utilities:**
- Shared helpers: `app/helpers/` (for ERB view helpers) or `app/services/` (for domain utilities)
- Frontend composables: `app/javascript/dashboard/composables/` (Vue 3 Composition API hooks)
- Shared Vue utilities: `app/javascript/shared/` (used across multiple SPAs)

**Background Job:**
- Location: `app/jobs/kanban/{feature_name}_job.rb` (e.g., `kanban_sync_job.rb`)
- Parent: Inherit from `ApplicationJob`
- Queue: Declare with `queue_as :default` or `:critical` depending on priority
- Example: `app/jobs/kanban/webhook_job.rb` (HTTP POST to webhook URL)

**Event Type:**
- Location: `lib/events/types.rb`
- Pattern: Add const `KANBAN_X_UPDATED = 'kanban.x_updated'`
- Dispatch: In service, call `Rails.configuration.dispatcher.dispatch(Events::Types::KANBAN_X_UPDATED, Time.zone.now, data:)`
- Listen: Add method to listener `def kanban_x_updated(event); ... end` (method name matches event type with dots → underscores)

**Listener (Event Handler):**
- Location: `app/listeners/` (new file if new domain, or add method to existing listener)
- Parent: Inherit from `BaseListener`
- Pattern: Define public method for event (e.g., `def kanban_card_moved(event)`)
- Helper: Call `broadcast(account, tokens, event_name, data)` to enqueue ActionCable broadcast
- Exception handling: Wrap in rescue StandardError, log, notify tracker

**Database Migration:**
- Location: `db/migrate/{timestamp}_{description}.rb`
- Generate: `rails generate migration CreateKanbanX` (auto-names with timestamp)
- Kanban models already created; extend via migration to add fields
- Example: `20260325000005_add_team_ids_to_kanban_cards.rb` (adds JSONB array field)

## Special Directories

**app/policies/:**
- Purpose: Pundit authorization policies (define who can do what)
- Generated: `rails generate pundit:policy KanbanBoard`
- Example: `KanbanBoardPolicy#show?`, `KanbanBoardPolicy#update?` — return true if user authorized, false otherwise
- Usage: Controller calls `authorize(board)` before action
- Committed: Yes

**enterprise/:**
- Purpose: Enterprise Edition code (overrides, extensions, premium features)
- Generated: Not auto-generated; manually created by enterprise team
- Pattern: Mirror structure of `app/` (e.g., `enterprise/app/services/kanban/` extends `app/services/kanban/`)
- Usage: Use `include_mod_with`, `prepend_mod_with` to mixin enterprise logic (see CLAUDE.md)
- Committed: Yes (but only enterprise-specific code)

**lib/custom_exceptions/:**
- Purpose: Domain-specific exception classes
- Example: `KanbanLimitReached`, `ConversationNotFound`, etc.
- Pattern: Inherit from `StandardError` or `ApplicationError`
- Usage: Raise in services, rescue in controllers, return HTTP error

**app/javascript/dashboard/store/modules/kanban/:**
- Purpose: Vuex/Pinia state management for kanban
- Files: `state.js`, `getters.js`, `mutations.js`, `actions.js` (or single file if using Pinia)
- Generated: No; manually created as feature needs state
- Committed: Yes

**spec/:**
- Purpose: Test suite (RSpec for Ruby, Jest for JavaScript)
- Layout: Mirrors `app/` structure (spec/models/, spec/services/, spec/jobs/, etc.)
- Generated: Manual or via `rails generate` with `--skip-test-unit` to skip old test framework
- Committed: Yes
- Run: `bundle exec rspec spec/services/kanban/` or `pnpm test`

---

*Structure analysis: 2026-05-11*
