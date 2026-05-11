# Codebase Concerns

**Analysis Date:** 2026-05-11

## Tech Debt

### Kanban Webhook System (Fire-and-Forget, No Retry/Auth/Deduplication)

**Issue:** The Kanban webhook system (`app/jobs/kanban/webhook_job.rb`) lacks critical reliability and security features that outbound webhooks require.

**Files:** 
- `app/jobs/kanban/webhook_job.rb` (fire-and-forget implementation, no retry, silent failures)
- `app/services/kanban/column_actions_service.rb` (line 30: enqueues without validation)

**Current behavior:**
- **No retry mechanism**: Uses bare `Net::HTTP` with 5s open timeout + 10s read timeout. Failures are logged but job is discarded silently.
- **No HMAC/signature**: Unlike standard `WebhookJob` (`app/jobs/webhook_job.rb` line 51 uses `OpenSSL::HMAC`), Kanban webhooks send unsigned payloads — consumer cannot verify authenticity.
- **No deduplication/idempotency tracking**: No delivery IDs (`X-Chatwoot-Delivery` header like standard webhooks at line 47).
- **Default queue** (`queue_as :default`): Shares queue with system jobs, potential blocking during high-volume events.
- **Silent error handling** (line 20–21): Catches all `StandardError` and logs only to Rails logs — monitoring/alerting can miss failures.

**Impact:**
- Webhook consumers may receive duplicate or missing card movement events.
- Security risk: Unauthenticated payloads (endpoint hijacking via spoofing possible if consumer validates sender).
- No visibility into why webhook delivery failed (network timeout vs. consumer error vs. auth failure).
- In production with commercial SLAs, dropped webhooks block downstream integrations (CRM, billing systems, reporting).

**Fix approach:**
- Backport webhook infrastructure from standard `WebhookJob` (retry_on, discard_on, HMAC, delivery_id) to Kanban webhooks.
- Add `:high` or `:webhooks` queue to prioritize delivery over default jobs.
- Add delivery tracking (e.g., `kanban_webhook_deliveries` table with status, retry count, next_retry_at).
- Implement exponential backoff retry (5–10 attempts, 3s–5min intervals) before giving up.
- Signature verification: Include `X-Chatwoot-Signature` header (SHA256 HMAC).
- Store secret on `KanbanBoard` or column actions config for signing.

---

### Default Scope Usage (Silent Query Behavior)

**Issue:** Multiple models use `default_scope` which silently applies ordering to all queries. This can mask performance issues and cause unexpected behavior.

**Files:**
- `app/models/message.rb` (line 135: `default_scope { order(created_at: :asc) }`) — TODO comment at line 132
- `app/models/label.rb` (line 31: `default_scope { order(:title) }`)
- `app/models/installation_config.rb` (line 50: `default_scope { order(created_at: :desc) }`) — TODO comment at line 48

**Impact:**
- Queries that should not be ordered get implicit ordering, increasing execution time on large tables.
- Developers may forget to `reorder` when implementing sorts, causing duplicate sorting operations.
- Message queries: With millions of messages, implicit `order(created_at: :asc)` slows batch operations and counts.

**Fix approach:**
- Remove default_scope from `Message` and `InstallationConfig` (label scope is acceptable).
- Use explicit ordering at query sites or in scopes where needed.
- Add `# ordering handled by reorder` comment to prevent future misunderstandings.

---

### CSAT Survey Query Performance

**Issue:** CSAT response counting queries against `messages` table timeout with millions of records.

**Files:**
- `db/migrate/20250627195529_add_index_to_messages.rb` (TODO at line 10)

**Current state:**
- Compound index `idx_messages_account_content_created` added as temporary fix (lines 19–20).
- Query pattern: `account.messages.input_csat.count` — scans entire message table filtering by account + content_type + created_at.

**Impact:**
- Queries timeout in production accounts with >10M messages.
- Index on 3 columns (account_id, content_type, created_at) is not ideal for analytics queries.

**Fix approach:**
- Create dedicated `csat_survey_responses` table (store survey event immediately when sent, not on message create).
- Migrate existing CSAT survey data from `messages` table to new table.
- Query analytics from lightweight survey table instead of full message table.
- Index: `(account_id, created_at)` on survey table.

---

### WhatsApp Baileys Service Complexity (858 lines)

**Issue:** `app/services/whatsapp/providers/whatsapp_baileys_service.rb` is the largest service in the codebase at 858 lines, handling connection, message sending, group management, and webhook processing in one class.

**Files:**
- `app/services/whatsapp/providers/whatsapp_baileys_service.rb` (858 lines, multiple concerns)

**Impact:**
- Difficult to test isolated features (e.g., message sending vs. group creation).
- High risk of regressions when modifying any part of WhatsApp Baileys provider logic.
- Harder to onboard new developers to WhatsApp-specific code paths.

**Fix approach:**
- Extract group management logic into `Whatsapp::Providers::BaileysGroupService`.
- Extract webhook handling into `Whatsapp::Providers::BaileysWebhookHandler`.
- Reduce service to ~400 lines focused on connection + message sending.

---

### Message Model Default Scope and Timestamp Precision

**Issue:** `Message` model (457 lines, app/models/message.rb) has implicit ordering via default_scope, and timestamp precision mismatch documented in comments.

**Files:**
- `app/models/message.rb` (lines 135, 148–150)

**Current behavior:**
- Database stores timestamps with second-level precision (no microseconds).
- Default ordering `order(created_at: :asc)` on all queries.
- Comments (lines 143–150) warn developers about precision differences in tests.

**Impact:**
- Tests using `expect(message.created_at).to eq(time_with_microseconds)` will fail.
- Implicit ordering increases query cost for large conversations.

**Fix approach:**
- Migrate timestamp columns to use microsecond precision (`TIMESTAMP(6)` in PostgreSQL).
- Remove default_scope (see debt item above).

---

### Conversation Model Complexity and State Machine

**Issue:** `Conversation` model (357 lines, app/models/conversation.rb) lacks proper state machine, using enum + manual transitions.

**Files:**
- `app/models/conversation.rb` (line 158: FIXME comment re: state machine)

**Current behavior:**
- Status transitions (open → resolved → snoozed → pending) done via direct `update(status: ...)` calls.
- No validation that transitions are valid (e.g., can you go from "resolved" to "pending"?).
- No audit trail of who/when status changed.
- Multiple callback-driven side effects on status change (activity messages, notifications, etc.).

**Impact:**
- Conversations can enter invalid state combinations (e.g., snoozed + resolved).
- Hard to understand all side effects of a single transition.
- No way to audit conversation history (compliance/troubleshooting issue).

**Fix approach:**
- Introduce `aasm` (Acts As State Machine) gem for explicit state transitions.
- Define valid transitions and guards (e.g., only agents can resolve, only assignee can snooze).
- Use `after_transition` hooks instead of scattered `after_save` callbacks.
- Add `conversation_state_changes` table to log transitions with actor/timestamp.

---

### Encryption Migration Incomplete (Guards in Models)

**Issue:** Multiple channel models include conditional encryption guards waiting for mandatory encryption keys (target 3–4 releases out).

**Files:**
- `app/models/channel/twitter_profile.rb` (line 22–27: TODO + guard)
- `app/models/channel/facebook_page.rb` (line 24–27: TODO + guard)
- `app/models/channel/telegram.rb` (line 20–21: TODO + guard)
- `app/models/channel/twilio_sms.rb` (line 31–32: TODO + guard)
- `app/models/channel/tiktok.rb` (line 24: TODO + guard)
- `app/models/channel/line.rb` (line 21: TODO + guard)
- `app/models/channel/instagram.rb` (line 22: TODO + guard)
- `app/models/channel/email.rb` (line 43: TODO + guard)
- `app/models/integrations/hook.rb` (line 24–25: TODO + guard)

**Current behavior:**
```ruby
if Chatwoot.encryption_configured?
  encrypts :twitter_access_token
  ...
end
```

If encryption keys are not configured, sensitive credentials are stored in plaintext in database.

**Impact:**
- Security risk: Access tokens/secrets exposed in DB backups and logs if unencrypted.
- Operational overhead: Need to track which instances have encryption enabled.
- Migration path unclear: How to encrypt existing plaintext data?

**Fix approach:**
- Remove conditional guards (make encryption mandatory in Rails 7.1+).
- Add pre-deployment script to generate + rotate encryption keys.
- Create data migration to encrypt existing plaintext credentials with new key.
- Document encryption key backup/rotation procedures.

---

## Known Bugs

### ActionCable RoomChannel Auth Check Missing

**Issue:** `RoomChannel#subscribed` (app/channels/room_channel.rb, line 3–10) does not validate account ownership before streaming.

**Files:**
- `app/channels/room_channel.rb`

**Trigger:**
```ruby
def subscribed
  current_user  # May raise if user not found, but no account validation
  current_account  # Finds account via account_id param, no auth check!
  ensure_stream  # Streams to @current_account.id, assuming it's correct
end
```

**Symptoms:**
- User A could subscribe to `room_channel` with `account_id` belonging to User B, if they know the pubsub_token.
- Pubsub tokens are not strongly guarded (see `contact_inboxes.find_by!(pubsub_token: ...)`).

**Workaround:**
- Always validate `current_user.accounts.find(params[:account_id])` before streaming (done at line 56, but after stream setup).

**Fix approach:**
- Move account validation to top of `subscribed` method.
- Return early with error broadcast if account not accessible to user.

---

### Conversation Auto-Resolve Scope Can Include Snoozed Conversations

**Issue:** `Conversation::resolvable_all` scope (conversation.rb, lines 91–95) does NOT check `snoozed_until`, allowing snoozed conversations to be auto-resolved.

**Files:**
- `app/models/conversation.rb` (lines 91–95)

**Current implementation:**
```ruby
scope :resolvable_all, lambda { |auto_resolve_after|
  return none if auto_resolve_after.to_i.zero?
  open.where('last_activity_at < ?', Time.now.utc - auto_resolve_after.minutes)
}
```

Missing: `.where(snoozed_until: nil).or(...snoozed_until < now...)`

**Impact:**
- Conversations snoozed by agents are automatically resolved, defeating the snooze intent.
- Agents may miss conversations they intentionally deferred.

**Fix approach:**
- Update scope: `open.where('snoozed_until IS NULL').where('last_activity_at < ?', ...)`
- Or: `open.where('snoozed_until IS NULL OR snoozed_until < ?', Time.now.utc).where(...)`

---

### WhatsApp Baileys Message Update Not Reflected (TODO in Helpers)

**Issue:** `app/services/whatsapp/baileys_handlers/helpers.rb` (line 189) notes that contact avatar is never updated if profile picture changes on WhatsApp.

**Files:**
- `app/services/whatsapp/baileys_handlers/helpers.rb` (line 189: TODO)

**Impact:**
- Contact avatar stale in UI if user updates WhatsApp profile picture.
- No way to refresh without manual re-sync.

**Fix approach:**
- Hook into Baileys `picture_changed` event (if available).
- On picture change, fetch latest avatar and update `Contact#avatar_url`.

---

### Telegram Message Read Status Not Marked

**Issue:** `app/services/telegram/incoming_message_service.rb` (line 17: TODO) notes that new Telegram Business accounts require explicit read marking.

**Files:**
- `app/services/telegram/incoming_message_service.rb` (line 17: TODO)

**Impact:**
- Telegram contacts see messages as unread in their inbox (appears unhandled in Chatwoot).
- Potential UX confusion: "Did the support agent see my message?"

**Fix approach:**
- Call Telegram `markChatRead` API when message is delivered/marked as read in Chatwoot.
- Add feature flag to enable for Telegram Business accounts only.

---

## Security Considerations

### Kanban Webhook Payloads Unsigned

**Issue:** Kanban webhook payloads (`app/services/kanban/column_actions_service.rb`) sent without HMAC signature.

**Files:**
- `app/services/kanban/column_actions_service.rb` (lines 97–145: webhook_payload method, no signature)
- `app/jobs/kanban/webhook_job.rb` (no secret handling)

**Risk:**
- Consumer endpoint cannot verify payload authenticity.
- If webhook URL is intercepted/spoofed, consumer can't distinguish real from fake payloads.
- Potential for supply chain attack: attacker sends fake card move events to downstream system.

**Current mitigation:**
- Standard webhooks (`lib/webhooks/trigger.rb`, line 51) sign with HMAC when secret is provided.
- Kanban webhooks should follow same pattern.

**Recommendations:**
- Add `secret` field to webhook actions config or `KanbanBoard` model.
- Update `WebhookJob.perform_later` to pass `secret:` parameter.
- Sign in `Webhooks::Trigger` (reuse existing code).

---

### Webhook Delivery Secrets Encrypted (Partially)

**Issue:** `Webhook` model encrypts `secret` field (webhook.rb, line 26) but only if `Chatwoot.encryption_configured?`.

**Files:**
- `app/models/webhook.rb` (line 26)
- `app/jobs/webhook_job.rb` (line 14: accepts `secret:` parameter)

**Risk:**
- If encryption keys are not configured, webhook secrets stored in plaintext in database.
- Plaintext secrets exposed in database backups, logs, or Rails console.

**Current mitigation:**
- Conditional encryption (good, but incomplete).

**Recommendations:**
- Make encryption mandatory (remove `if` guard).
- Implement key rotation workflow.

---

### Instagram/Facebook Test Event Processing Not Validated

**Issue:** `app/jobs/webhooks/instagram_events_job.rb` (lines 54–66) processes "test events" from Facebook webhook subscription without validating payload structure.

**Files:**
- `app/jobs/webhooks/instagram_events_job.rb` (lines 54–66)

**Risk:**
- Malformed test events could cause unhandled exceptions or infinite loops.

**Current mitigation:**
- `Instagram::TestEventService.new(messaging).perform if messaging.present?` — basic nil check.

**Recommendations:**
- Add JSON schema validation for test event payloads.
- Log unexpected structures for debugging.

---

### Action Cable Pubsub Token Not Time-Limited

**Issue:** `RoomChannel` uses `pubsub_token` (from `ContactInbox` or `User`) with no expiration.

**Files:**
- `app/channels/room_channel.rb` (lines 38–47: token lookup)
- `app/models/contact_inbox.rb` / `app/models/user.rb` (pubsub_token generation)

**Risk:**
- Token valid forever — if leaked, attacker has persistent access.
- No way to revoke token except via database UPDATE.

**Recommendations:**
- Add `pubsub_token_expires_at` timestamp.
- Rotate tokens on login/logout.
- Cache token validity in Redis with TTL.

---

## Performance Bottlenecks

### Conversation Finder Agent Lookup (N+1 Risk)

**Issue:** `ConversationFinder#find_available_agent` (app/finders/conversation_finder.rb, lines 84–95) joins `kanban_cards` table and groups by `users.id`, but result depends on all conversations' kanban cards being loaded.

**Files:**
- `app/finders/conversation_finder.rb` (lines 84–95)

**Impact:**
- In large accounts (10K+ cards), loading all available agents requires expensive join + count query.
- Multiple calls to this method (e.g., auto-assignment) cause repeated joins.

**Fix approach:**
- Cache available agents list in Redis with TTL (refresh on card assignment).
- Use materialized view (PostgreSQL) for `agent_load_summary` table.

---

### Message Flooding Validation (No Index Check)

**Issue:** `Message#prevent_message_flooding` validates by querying recent messages without explicit index.

**Files:**
- `app/models/message.rb` (line 67: before_validation hook)

**Likely implementation:**
```ruby
def prevent_message_flooding
  # Prevents rapid-fire messages from single sender
  recent = Message.where(sender: sender).where('created_at > ?', 5.minutes.ago).count
end
```

**Impact:**
- Index exists on `sender_type + sender_id` (line 37 of schema comment), but query also filters by `created_at`.
- Scan of all messages by sender within 5 minutes can be slow if sender is prolific.

**Fix approach:**
- Add index: `(sender_type, sender_id, created_at DESC)`.
- Or: Use Redis sliding window counter per sender (more efficient).

---

### Conversation Last Activity Scope (Subquery + Join)

**Issue:** `Conversation::last_user_message_at` scope (lines 97–102) joins a subquery. Performance untested at scale.

**Files:**
- `app/models/conversation.rb` (lines 97–102)

**Impact:**
- Sorts 10K+ conversations by their last user message timestamp — requires subquery execution on every call.

**Fix approach:**
- Add denormalized `last_user_message_at` column to `conversations` table.
- Update via trigger or async job when messages are added.
- Index: `(account_id, last_user_message_at DESC)`.

---

### Participant Operations Loop (find_or_create in Loop)

**Issue:** `ParticipantsController` (api/v1/accounts/conversations/participants_controller.rb, lines 14–15) calls `find_or_create_by` in loop.

**Files:**
- `app/controllers/api/v1/accounts/conversations/participants_controller.rb` (lines 14–15)

**Impact:**
- Adding 100 participants = 100 separate database calls.

**Fix approach:**
- Batch: `Conversation::Participant.upsert_all(rows, unique_by: [:conversation_id, :user_id])` (Rails 6+).

---

## Fragile Areas

### Kanban Webhook System (No Error Tracking / Observability)

**Issue:** Kanban webhook job failures logged only to Rails logs; no external alerting, no retry tracking, no delivery status API.

**Files:**
- `app/jobs/kanban/webhook_job.rb` (lines 19–22: logging only)
- `app/services/kanban/column_actions_service.rb` (line 30: fire-and-forget)

**Why fragile:**
- Operator has no visibility into webhook failures (must grep Rails logs).
- If a webhook URL is misconfigured, cards are moved but webhook is silently dropped.
- Debugging webhook issues requires application logs access (not suitable for SaaS/hosted).

**Safe modification:**
- Do NOT modify webhook_job.rb without adding webhook delivery tracking.
- Before changing action execution in column_actions_service.rb, ensure webhook success is monitored.

**Test coverage gaps:**
- No spec for `Kanban::WebhookJob` (no `spec/jobs/kanban/` directory exists).
- No test for failure scenarios (network timeout, 5xx, timeout).

---

### WhatsApp Baileys Provider Stability

**Issue:** WhatsApp Baileys service (858 lines) has multiple TODO/FIXME items (line 47: "Remove on Baileys v2").

**Files:**
- `app/services/whatsapp/providers/whatsapp_baileys_service.rb`

**Stability concerns:**
- Baileys library is community-maintained, API may change.
- Version lock dependencies on `whatsapp-web.js` (if used) are not pinned.
- Group message support gated behind `BAILEYS_WHATSAPP_GROUPS_ENABLED` env var — incomplete feature.

**Safe modification:**
- Do NOT upgrade Baileys without testing full message flow (inbound/outbound) + group operations.
- Check Baileys release notes for breaking changes.

**Test coverage:**
- Baileys integration tests should cover: single chat, groups, template messages, media, errors.

---

### Conversation State Transitions (No Validation)

**Issue:** Conversation status can transition between any states without validation (e.g., resolved → pending).

**Files:**
- `app/models/conversation.rb` (status enum, no guards)

**Why fragile:**
- Multiple services can update status independently (auto-resolve job, agent action, webhook callback).
- Conversation can end up in inconsistent state (e.g., snoozed_until set but status = resolved).
- No audit trail of who changed status when.

**Safe modification:**
- Before changing conversation status, check for conflicting status bits (snoozed + resolved).
- Add guard clauses to `update` methods: `return if current_status == target_status`.

---

### Message Content Validation (JSON Schema)

**Issue:** `Message#content_attributes` validated via `ContentAttributeValidator` and `JsonSchemaValidator`, but schema is hardcoded.

**Files:**
- `app/models/message.rb` (lines 75–77: TEMPLATE_PARAMS_SCHEMA)

**Risk:**
- If schema changes, old messages fail validation (can't save, can't edit).
- No versioning or migration strategy for schema changes.

**Safe modification:**
- Any schema changes must include data migration for existing messages.
- Consider soft validation (warn, don't block) for old-format messages.

---

## Scaling Limits

### Default Conversation Finder Query (Implicit Ordering)

**Issue:** `ConversationFinder#find_all_conversations` chains multiple filters without explicit ordering until sort is applied.

**Files:**
- `app/finders/conversation_finder.rb` (lines 115–120+)

**Capacity:**
- With 100K+ conversations per account, implicit scopes can cause N+1 problems during permission filtering.
- `Conversations::PermissionFilterService` not shown, but likely does row-by-row checks.

**Scaling path:**
- Implement permission-based database view or cached permission matrix.
- Pre-compute conversation visibility matrix in Redis after user role changes.

---

### Redis Dependency for Pub/Sub (OnlineStatusTracker)

**Issue:** `RoomChannel` broadcasts presence via Redis (room_channel.rb, line 24: `ActionCable.server.broadcast`).

**Files:**
- `app/channels/room_channel.rb`
- `lib/online_status_tracker.rb` (if exists)

**Capacity:**
- With 10K concurrent users, Redis pub/sub can saturate at high message rate.

**Scaling path:**
- Shard presence data by account in Redis.
- Use Redis Streams instead of pub/sub for better persistence.
- Consider alternative: Store presence in PostgreSQL, poll via WebSocket heartbeat.

---

### Webhook Queue Contention (All on :default)

**Issue:** All webhook jobs (API webhooks, Kanban webhooks, agent bot webhooks) use mixed queue priorities.

**Files:**
- `app/jobs/webhook_job.rb` (queue_as :medium)
- `app/jobs/kanban/webhook_job.rb` (queue_as :default)
- `app/jobs/agent_bots/webhook_job.rb` (queue_as :high)

**Capacity:**
- High-priority webhooks (agent bots) may starve if :default queue is congested.
- Kanban webhooks on :default are deprioritized unfairly.

**Scaling path:**
- Create dedicated `:webhooks` queue with separate worker pool.
- Use queue priorities: agent_bots (:high), api webhooks (:medium), kanban (:default).

---

## Dependencies at Risk

### WhatsApp Baileys (Community-Maintained)

**Risk:** Baileys library (`whatsapp-web.js` wrapper) is community-maintained, not officially supported by Meta.

**Migration plan:**
- Evaluate official WhatsApp Cloud API as replacement (lines 269ff in whatsapp_cloud_service.rb show it's already integrated).
- Phase out Baileys for official API in next major version.
- Document: "Baileys is unsupported; migrate to official API for production use."

---

### RestClient Deprecation (lib/chatwoot_hub.rb)

**Issue:** `lib/chatwoot_hub.rb` (line 1: TODO) notes intention to switch from RestClient to HTTParty.

**Risk:**
- RestClient is no longer actively maintained (last gem update ~2021).
- HTTParty is more widely used and maintained.

**Migration plan:**
- Replace RestClient usage with HTTParty across codebase.
- Audit SSL certificate validation in both libraries.

---

### SearchKick (Elasticsearch Dependency)

**Issue:** `Message` model (line 42) uses Searchkick if `ChatwootApp.advanced_search_allowed?`.

**Risk:**
- Elasticsearch dependency adds operational overhead (separate cluster, scaling, backups).
- If Elasticsearch fails, search is unavailable (no fallback).

**Scaling path:**
- Consider PostgreSQL full-text search as fallback.
- Add feature flag to toggle between Elasticsearch + PG FTS.

---

## Missing Critical Features

### No Webhook Delivery Tracking / Retry Dashboard

**Problem:** Operators cannot see webhook delivery history or retry status.

**Blocks:**
- Debugging customer integration issues (webhook consumed? where did it fail?).
- SLA compliance tracking (webhook delivered within 5min?).
- Replay/retry capabilities for missed webhooks.

**Workaround:** None; requires logs access.

**Priority:** HIGH (blocks commercial use with integrations).

---

### Kanban Webhook Signature Verification

**Problem:** Kanban webhook consumers cannot verify payload authenticity.

**Blocks:**
- Secure integration with external systems (CRM, billing systems).
- Prevents webhook spoofing attacks.

**Workaround:** Use IP whitelist (fragile, not recommended).

**Priority:** HIGH (security requirement for production).

---

### Conversation Status Audit Trail

**Problem:** No record of who changed conversation status, when, or why.

**Blocks:**
- Compliance audits (SLA proof).
- Troubleshooting: "Who resolved this conversation?"
- Conversation history reconstruction.

**Workaround:** Parse Activity messages (if enabled), incomplete.

**Priority:** MEDIUM (compliance/enterprise feature).

---

## Test Coverage Gaps

### Kanban Webhook Job (Zero Tests)

**What's not tested:**
- Job enqueueing from `ColumnActionsService`.
- Webhook payload structure and content.
- Network timeout handling (5s open, 10s read).
- Failure logging.
- Interaction with Sidekiq job queue.

**Files:**
- `app/jobs/kanban/webhook_job.rb` (no corresponding `spec/jobs/kanban/webhook_job_spec.rb`)

**Risk:**
- Changes to webhook behavior can break production without detection.
- Cannot verify webhook payload matches consumer expectations.

**Priority:** CRITICAL (blocking feature for integrations).

---

### Kanban Column Actions (No Integration Tests)

**What's not tested:**
- Full flow: Card moved → action triggered → webhook sent.
- Auto-assign agent logic (agent availability check via kanban board).
- Team assignment side effects (conversation team update).

**Files:**
- `app/services/kanban/column_actions_service.rb` (no corresponding spec, or minimal).

**Risk:**
- Regressions in kanban auto-actions (auto_resolve, auto_assign_conversation) go undetected.

---

### RoomChannel Authorization (No Security Tests)

**What's not tested:**
- Unauthorized account subscription (User A subscribes to Account B via pubsub_token).
- Token expiration/revocation.
- Contact inbox vs. user channel separation.

**Files:**
- `app/channels/room_channel.rb` (no spec coverage visible).

**Risk:**
- WebSocket subscription bypasses can allow cross-account data leaks.

---

### Conversation Auto-Resolve Job (Snoozed Conversation Bug)

**What's not tested:**
- Auto-resolve should NOT resolve snoozed conversations.
- Edge case: Conversation moved from snoozed → open within auto-resolve window.

**Files:**
- `app/models/conversation.rb` (scope tested, but not the bug scenario).

---

## Summary by Severity

### CRITICAL (Blocks commercial use)

1. **Kanban webhook system**: Fire-and-forget, no retry, no auth, no monitoring
2. **Kanban webhook security**: Unsigned payloads (spoofing risk)
3. **Kanban webhook test coverage**: Zero tests
4. **Conversation auto-resolve**: Includes snoozed conversations (bug)

### IMPORTANT (Degrades reliability / security)

5. **ActionCable auth bypass risk**: RoomChannel account validation incomplete
6. **Encryption guards**: Secrets stored plaintext if keys not configured
7. **CSAT query performance**: Timeouts on large accounts (workaround in place)
8. **Default scopes**: Silent query behavior, masks performance issues
9. **WhatsApp Baileys complexity**: 858 lines, hard to test/modify

### NICE-TO-FIX (Technical debt, not blocking)

10. **Telegram read marking**: Business accounts not marked as read
11. **Contact avatar stale**: WhatsApp avatar not updated on profile picture change
12. **Conversation state machine**: No guards on status transitions
13. **Message timestamp precision**: Microsecond precision lost
14. **Webhook delivery observability**: No API for operators to see retry status

---

*Concerns audit: 2026-05-11*
