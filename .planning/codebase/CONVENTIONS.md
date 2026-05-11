# Coding Conventions

**Analysis Date:** 2026-05-11

## Naming Patterns

**Files:**
- Ruby files: snake_case (e.g., `user_service.rb`, `conversation_policy.rb`)
- Vue components: PascalCase (e.g., `DateSeparator.vue`, `CheckBox.vue`)
- JavaScript files: camelCase (e.g., `settingsHelpers.spec.js`, `storeFactory.spec.js`)
- Service objects: `[Noun]Service` (e.g., `CsatTemplateNameService`, `BaseRefreshOauthTokenService`)
- Policy files: `[Model]Policy` (e.g., `ConversationPolicy`, `AccountPolicy`)
- Job files: `[Noun]Job` (e.g., `WebhookJob`, `HookJob`)

**Functions:**
- Ruby methods: snake_case (e.g., `def extract_version`, `def csat_base_name_for_inbox`)
- JavaScript functions: camelCase (e.g., `createStore`, `generateMutationTypes`)
- Vue emits: camelCase (e.g., `@update`, `@change`)

**Variables:**
- Ruby instance variables: @snake_case (e.g., `@conversation`, `@account`)
- Ruby class variables/constants: UPPER_SNAKE_CASE (e.g., `CSAT_BASE_NAME`, `NUMBER_OF_PERMITTED_ATTACHMENTS`)
- JavaScript variables: camelCase (e.g., `isLibraryMode`, `dateSeparator`)

**Types/Classes:**
- Ruby classes: PascalCase (e.g., `Message`, `ConversationPolicy`)
- Vue component props: PascalCase for component names, camelCase for prop names
- Custom exceptions: `CustomExceptions::[Category]::[Name]` (e.g., `CustomExceptions::Webhook::RetriableError`)

## Code Style

**Formatting:**
- Tool: RuboCop (Ruby), Prettier (JavaScript)
- Line length: 150 characters max for Ruby (enforced via `.rubocop.yml` at `Layout/LineLength`)
- ESLint for JavaScript/Vue with Airbnb base config extended

**Linting:**
- Ruby: RuboCop with plugins (rubocop-rails, rubocop-rspec, rubocop-performance, rubocop-factory_bot)
  - Key rules: No frozen string literal comments required, no documentation required on classes
  - Hash syntax: enforce new syntax with `EnforcedStyle: no_mixed_keys` and `EnforcedShorthandSyntax: never`
- JavaScript: ESLint with airbnb-base, prettier, vue3-recommended plugins
  - Vue component name casing: PascalCase in template usage
  - Vue custom event casing: camelCase
  - Block order: `<script>`, `<template>`, `<style>`

## Import Organization

**Order:**
1. External libraries/gems (Rails, Vue, npm packages)
2. Local application modules and classes
3. Relative imports (helpers, services, mixins)

**Path Aliases:**
- `components`: `app/javascript/dashboard/components`
- `next`: `app/javascript/dashboard/components-next` (new message bubble components)
- `v3`: `app/javascript/v3` (Vue 3 composables and components)
- `dashboard`: `app/javascript/dashboard`
- `helpers`: `app/javascript/shared/helpers`
- `shared`: `app/javascript/shared`
- `survey`: `app/javascript/survey`
- `widget`: `app/javascript/widget`
- `assets`: `app/javascript/dashboard/assets`

## Error Handling

**Patterns:**
- Ruby: Raise custom exceptions from `lib/custom_exceptions/[category].rb` (e.g., `CustomExceptions::Webhook::RetriableError`)
- Custom exceptions inherit from `CustomExceptions::Base` and implement `http_status()` and `to_hash()`
- Controllers rescue specific custom exceptions and call `render_could_not_create_error(e.message)` or equivalent helpers
- Sidekiq jobs use `rescue_with` to handle specific exception classes (e.g., `rescue_with CustomExceptions::Webhook::RetriableError`)

Example from `app/jobs/webhook_job.rb`:
```ruby
rescue_with 'CustomExceptions::Webhook::RetriableError' do |exception|
  # Handle retry logic
end
```

## Logging

**Framework:** `Rails.logger` (standard Rails logging) or local logger methods

**Patterns:**
- Use `Rails.logger.info`, `Rails.logger.warn`, `Rails.logger.error`
- Log at method entry/exit for debugging critical paths
- Include context (IDs, states) in log messages for traceability

## Comments

**When to Comment:**
- Complex business logic requiring explanation (e.g., transaction ordering, rate limiting calculations)
- Workarounds or temporary fixes (prefix with `FIXME:` or `TODO:`)
- Non-obvious algorithmic decisions
- Do not comment obvious code

**JSDoc/TSDoc:**
- Not enforced; brief inline comments preferred
- Use for complex parameter transformations or return value shapes

## Function Design

**Size:**
- Target: Methods under 19 lines (RuboCop `Metrics/MethodLength: Max: 19`)
- Exceptions excluded in `.rubocop.yml` (e.g., `enterprise/lib/captain/agent.rb`)

**Parameters:**
- Use strong parameters (`params.require(:model).permit(...)`) in Rails controllers
- Ruby services use dependency injection (constructor parameters via `attr_extras` with `pattr_initialize`)
- Vue components use `defineProps()` with PropTypes for type safety

**Return Values:**
- Consistent return types: services return hashes with result/error structure or raise exceptions
- Example from `Conversations::FilterService.perform`: `{ conversations: [...], count: ... }`

## Module Design

**Exports:**
- Ruby: Classes exported as-is; modules included or prepended for composition
- JavaScript: Named exports preferred for utilities, default export for components
- Vue: Single File Components (.vue) exported as default

**Barrel Files:**
- Not heavily used; prefer explicit imports for clarity
- Exception: `app/javascript/dashboard/components-next/` may have index files for component families

**Pundit Policies:**
- One policy per model (e.g., `ConversationPolicy` in `app/policies/conversation_policy.rb`)
- Policies inherit from `ApplicationPolicy` which provides access to `user`, `record`, and `account`
- Helper methods prefixed with underscore (private) for conditional checks (e.g., `def administrator?`, `def inbox_access?`)
- Policy files use `prepend_mod_with('PolicyName')` at the end to allow Enterprise edition overrides

Example from `app/policies/conversation_policy.rb`:
```ruby
class ConversationPolicy < ApplicationPolicy
  def show?
    administrator? || agent_bot? || agent_can_view_conversation?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
```

## Service Object Pattern

**Location:** `app/services/` with nested subdirectories by domain (e.g., `app/services/messages/`, `app/services/conversations/`)

**Design:**
- Constructor using `pattr_initialize` from `attr_extras` for immutable initialization
- Public method `call` or `perform` (no `!` suffix required for context; `perform!` for jobs)
- Dependencies injected as constructor parameters
- Single responsibility per service class

Example from `app/services/csat_template_name_service.rb`:
```ruby
class CsatTemplateNameService
  def self.csat_template_name(inbox_id, version = nil)
    # Static method approach for simple utilities
  end
end
```

More typical service instance pattern:
```ruby
class ConversationBuilder
  pattr_initialize [:params!, :contact_inbox!]
  
  def perform
    # returns object or hash
  end
end

# Usage in controller:
@conversation = ConversationBuilder.new(params: params, contact_inbox: @contact_inbox).perform
```

## Styling Rules

**Critical: Tailwind Only**
- Do not write custom CSS files (no scoped `<style>` blocks)
- Do not use inline styles (`:style=` in templates)
- Always use Tailwind utility classes
- Color definitions from `tailwind.config.js` (e.g., `text-n-brand`, `bg-n-slate-2`)
- Responsive classes: `sm:`, `md:`, `lg:`, `xl:` prefixes

Example from `app/javascript/v3/components/Form/CheckBox.vue`:
```vue
<input
  class="flex-shrink-0 mt-0.5 border-n-strong border bg-n-slate-2 checked:border-none checked:bg-n-brand shadow-sm appearance-none rounded-[4px] w-4 h-4"
/>
```

## Vue 3 Component Pattern

**Script Setup:**
- Always use `<script setup>` (not composition API with `setup()` function or options API)
- Use `defineProps()` for props, `defineEmits()` for emits, `defineExpose()` for exposed methods
- Composition functions imported via `import { useX } from 'path'`
- Reactive state: `ref()`, `computed()`, `reactive()` for complex state

Example from `app/javascript/v3/components/Form/CheckBox.vue`:
```vue
<script setup>
import { computed } from 'vue';

const props = defineProps({
  isChecked: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const checked = computed({
  get: () => props.isChecked,
  set: value => emit('update', props.value, value),
});
</script>
```

**Template i18n:**
- No bare strings in templates; always use `$t()` or i18n key references
- Back-end i18n: `en.yml` file
- Front-end i18n: `en.json` file

## Strong Parameters & Pundit

**Controllers:**
- Use `permitted_update_params`, `permitted_create_params` methods for strong parameter filtering
- All controller actions authorize via Pundit: `authorize resource, :action?`
- Base controller includes `include Pundit` and sets up before_action for authorization

Example from `app/controllers/api/v1/accounts/conversations_controller.rb`:
```ruby
def update
  @conversation.update!(permitted_update_params)
end

def filter
  result = ::Conversations::FilterService.new(params.permit!, current_user, current_account).perform
  # ...
rescue CustomExceptions::CustomFilter::InvalidAttribute => e
  render_could_not_create_error(e.message)
end
```

---

*Convention analysis: 2026-05-11*
