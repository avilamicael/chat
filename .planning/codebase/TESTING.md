# Testing Patterns

**Analysis Date:** 2026-05-11

## Test Framework

**Runner:**
- RSpec 6.1.5+ for Ruby (config: `spec/rails_helper.rb`, `spec/spec_helper.rb`)
- Vitest with Vue Test Utils for JavaScript/Vue (config: `vite.config.ts` test section)

**Assertion Library:**
- Ruby: RSpec matchers + Shoulda matchers
- JavaScript: Vitest assertions (expect)

**Run Commands:**
```bash
# Ruby - All tests
bundle exec rspec

# Ruby - Single test file
bundle exec rspec spec/path/to/file_spec.rb

# Ruby - Single test by line number
bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER

# JavaScript - All tests (no watch)
pnpm test

# JavaScript - Watch mode
pnpm test:watch

# JavaScript - With coverage
pnpm test:coverage
```

## Test File Organization

**Location:**
- Ruby: `spec/` directory, co-located with `app/` structure
- JavaScript: `app/**/*.spec.js` (inline with source code, not separate directory)

**Naming:**
- Ruby: `[unit]_spec.rb` (e.g., `message_spec.rb`, `webhook_job_spec.rb`)
- JavaScript: `[name].spec.js` or `[name].test.js` (e.g., `storeFactory.spec.js`)

**Structure:**
```
spec/
├── models/               # Model tests (e.g., message_spec.rb)
├── services/             # Service tests (e.g., csat_template_name_service_spec.rb)
├── controllers/          # Controller tests (being phased out)
├── jobs/                 # Sidekiq job tests (e.g., webhook_job_spec.rb)
├── requests/             # HTTP request tests (e.g., conversations_spec.rb)
├── policies/             # Pundit policy tests
├── support/              # Shared helpers, fixtures, stubs
├── factories/            # FactoryBot factories
├── fixtures/             # Static test data
├── enterprise/           # Enterprise-specific tests (mirrors app structure)
└── [directory]/          # Test coverage mirrors app/ structure
```

## Test Structure

**Suite Organization:**

RSpec suite uses nested `describe` blocks organized by concern:

```ruby
require 'rails_helper'

RSpec.describe Message do
  # Shared setup
  before do
    allow_any_instance_of(described_class).to receive(:reindex_for_search).and_return(true)
  end

  # Context groups by behavior
  context 'with validations' do
    it { is_expected.to validate_presence_of(:inbox_id) }
    it { is_expected.to validate_presence_of(:conversation_id) }
  end

  describe 'length validations' do
    let!(:message) { create(:message) }

    context 'when it validates name length' do
      it 'valid when within limit' do
        message.content = 'a' * 120_000
        expect(message.valid?).to be true
      end

      it 'invalid when crossed the limit' do
        message.content = 'a' * 150_001
        message.valid?
        expect(message.errors[:content]).to include('is too long')
      end
    end
  end
end
```

**Patterns:**
- `before` blocks for setup (executed before each test)
- `before(:all)` or `let_it_be` (from test-prof) for expensive shared setup
- `let` for lazy-evaluated fixtures (FactoryBot objects)
- `let!` for eager-evaluated fixtures (needed for associations)
- `subject` for the object under test (auto-provided to matchers)

## Job Testing Pattern

Sidekiq jobs use `ActiveJob::TestHelper` for queue and retry assertions:

```ruby
require 'rails_helper'

RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(url, payload, webhook_type) }

  let(:url) { 'https://test.chatwoot.com' }
  let(:payload) { { name: 'test' } }
  let(:webhook_type) { :account_webhook }

  # Queue assertion
  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(url, payload, webhook_type)
      .on_queue('medium')
  end

  # Execution assertion
  it 'executes perform with default webhook type' do
    expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)
    perform_enqueued_jobs { job }
  end

  # Retry handler assertion
  it 'is configured to retry on CustomExceptions::Webhook::RetriableError' do
    retry_handler = described_class.rescue_handlers.find do |handler|
      handler[0] == 'CustomExceptions::Webhook::RetriableError'
    end
    expect(retry_handler).to be_present
  end

  # Error handling with retry
  context 'when webhook type is api_inbox_webhook' do
    it 'marks message as failed after retries are exhausted' do
      allow(Webhooks::Trigger).to receive(:execute).and_raise(
        CustomExceptions::Webhook::RetriableError.new('Webhook endpoint not found')
      )
      perform_enqueued_jobs { job }
      expect(message.reload.status).to eq('failed')
    end
  end
end
```

**Key patterns:**
- Use `have_enqueued_job()` to assert job was enqueued
- Use `on_queue('queue_name')` to assert queue selection
- Use `perform_enqueued_jobs { job }` to execute queued jobs inline during tests
- Verify `rescue_handlers` array for exception configuration
- Test state changes after job execution (e.g., message status updates)

## Mocking

**Framework:** RSpec mocks via `allow()` and `expect()`

**HTTP Mocking:**
- WebMock for external HTTP calls (config: enabled in `spec/spec_helper.rb` with `WebMock.disable_net_connect!`)
- Example: `allow_any_instance_of(described_class).to receive(:reindex_for_search).and_return(true)`

**Patterns:**

```ruby
# Method stubbing (return value)
allow(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)

# Method stubbing with conditional return
allow(Webhooks::Trigger).to receive(:execute).and_raise(
  CustomExceptions::Webhook::RetriableError.new('Not found')
)

# Instance double for complex mocks
processor_service = instance_double(Crm::Leadsquared::ProcessorService)
allow(Crm::Leadsquared::ProcessorService).to receive(:new).with(hook).and_return(processor_service)

# Spy for verifying method calls
expect(SendOnSlackJob).to receive(:perform_later).with(event_data[:message], hook)
```

**What to Mock:**
- External API calls (HTTP requests via WebMock)
- Heavy operations (file uploads, email sends)
- Expensive lookups (database queries in unit tests)
- Non-deterministic behavior (current time, random values)

**What NOT to Mock:**
- Database operations (use real fixtures/factories)
- Business logic core to the test
- Association lookups (ActiveRecord relations)
- Validation behavior (use real models)

## Fixtures and Factories

**Test Data:**
- FactoryBot factories for model creation
- Location: `spec/factories/` (one file per model or related group)

Factory pattern:
```ruby
# spec/factories/messages.rb
FactoryBot.define do
  factory :message do
    account { create(:account) }
    inbox { create(:inbox, account: account) }
    conversation { create(:conversation, inbox: inbox) }
    content { 'Hello, world!' }
    message_type { :incoming }
  end

  # Trait for attachment scenario
  trait :with_attachment do
    attachments { [create(:attachment)] }
  end

  # Usage in spec:
  # let(:message) { create(:message) }
  # let(:message) { create(:message, :with_attachment) }
end
```

**Location:**
- `spec/factories/` for all FactoryBot definitions
- `spec/fixtures/` for static JSON/YAML test data (rare in this codebase)

**FactoryBot Configuration:**
- Enabled via `config.include FactoryBot::Syntax::Methods` in `spec/rails_helper.rb`
- Short syntax: `create(:message)` not `FactoryBot.create(:message)`

## Coverage

**Requirements:** No enforced coverage target (SimpleCov available but optional)

**View Coverage:**
```bash
# Generate coverage report
pnpm test:coverage  # JavaScript
bundle exec rspec --coverage  # Ruby (with simplecov)
```

Coverage config (Ruby): Not enforced; `.simplecov` file exists but no minimum threshold set.

## Test Types

**Unit Tests:**
- Scope: Single class behavior (models, services, policies)
- Example: `spec/models/message_spec.rb` — tests Message model validations, methods, scopes
- Approach: Use factories for dependencies, mock external services

**Integration Tests:**
- Scope: Multiple components working together (services calling models, models with associations)
- Example: `spec/services/` — test service classes that coordinate models and external calls
- Approach: Use real database, real models, mock only external APIs

**Request Tests (HTTP/API):**
- Scope: Full request cycle from Rails routing through controller to response
- Location: `spec/requests/api/v1/accounts/` (mirrors routes)
- Example from `spec/requests/api/v1/accounts/base_controller_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::BaseController', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'allows assignments via API' do
    post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
         headers: { api_access_token: agent_bot.access_token.token },
         params: { assignee_id: agent.id },
         as: :json

    expect(response).to have_http_status(:success)
  end
end
```

**E2E Tests:**
- Not used in this codebase (focus is on integration + request specs)

## Common Patterns

**Async Testing:**
```ruby
# Job execution in test (ActiveJob::TestHelper)
subject(:job) { described_class.perform_later(url, payload, webhook_type) }

# Execute all queued jobs
perform_enqueued_jobs { job }

# Assert job was queued
expect { job }.to have_enqueued_job(described_class).on_queue('medium')
```

**Error Testing:**
```ruby
# Expect exception to be raised
expect { perform_enqueued_jobs { job } }.to raise_error(CustomExceptions::Webhook::RetriableError)

# Stub to raise error and test error handling path
allow(Webhooks::Trigger).to receive(:execute).and_raise(
  CustomExceptions::Webhook::RetriableError.new('Endpoint not found')
)
perform_enqueued_jobs { job }
expect(message.reload.status).to eq('failed')

# Test error class name (for comparison in reloading environments)
expect(error.class.name).to eq('CustomExceptions::Webhook::RetriableError')
```

**Environment Variables in Tests:**
```ruby
# Use with_modified_env from spec_helper (prefers ClimateControl)
with_modified_env 'CONVERSATION_MESSAGE_PER_MINUTE_LIMIT': '2' do
  # Test code here; env var is set
end
```

## Vue/JavaScript Testing

**Setup:**
- Vitest global test utilities auto-imported (vitest-globals plugin)
- Vue Test Utils for component mounting
- Store setup via Pinia (test setup in `vitest.setup.js`)

Example from `app/javascript/shared/components/specs/DateSeparator.spec.js`:
```javascript
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import DateSeparator from '../DateSeparator.vue';

describe('DateSeparator', () => {
  let dateSeparator = null;

  beforeEach(() => {
    dateSeparator = shallowMount(DateSeparator, {
      global: {
        plugins: [store],
        mocks: {
          $t: msg => msg, // Mock i18n
        },
      },
      props: {
        date: 'Nov 18, 2019',
      },
    });
  });

  it('date separator snapshot', () => {
    expect(dateSeparator.vm).toBeTruthy();
    expect(dateSeparator.element).toMatchSnapshot();
  });
});
```

**Mocking in JS:**
```javascript
// Mock module
vi.mock('dashboard/store/utils/api', () => ({
  throwErrorMessage: vi.fn(),
}));

// Mock store function
vi.mock('shared/helpers/vuex/mutationHelpers', () => ({
  set: vi.fn(),
  create: vi.fn(),
}));
```

## RSpec Configuration

**Key settings in `spec/rails_helper.rb`:**
- `config.use_transactional_fixtures = true` — wrap each test in database transaction
- `config.include FactoryBot::Syntax::Methods` — enable short factory syntax
- `require 'pundit/rspec'` — Pundit matchers for policy testing
- WebMock enabled with `WebMock.disable_net_connect!(allow_localhost: true)`
- Test-prof loaded for `before_all`, `let_it_be` performance optimizations

**Helper method:**
```ruby
# From spec/spec_helper.rb - use instead of ENV stubbing
def with_modified_env(options, &)
  ClimateControl.modify(options, &)
end
```

## Running Tests

**Development workflow:**
```bash
# Run all Ruby tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/jobs/webhook_job_spec.rb

# Run test by line number
bundle exec rspec spec/jobs/webhook_job_spec.rb:40

# Run tests matching pattern
bundle exec rspec --pattern "spec/services/**/*_spec.rb"

# Run tests with verbose output
bundle exec rspec --format documentation

# Run JavaScript tests in watch mode
pnpm test:watch

# Run JavaScript tests once
pnpm test
```

---

*Testing analysis: 2026-05-11*
