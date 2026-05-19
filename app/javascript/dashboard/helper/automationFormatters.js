export const formatTriggerSummary = run => {
  if (!run) return '—';
  switch (run.event_name) {
    case 'kanban_card_moved':
      return `Card moved (event ${run.trigger_event_id?.slice(0, 8) || '—'})`;
    case 'kanban_card_added':
      return 'Card added';
    case 'kanban_card_removed':
      return 'Card removed';
    case 'message_created':
      return 'New message';
    case 'conversation_created':
      return 'New conversation';
    case 'conversation_resolved':
      return 'Conversation resolved';
    case 'conversation_opened':
      return 'Conversation reopened';
    case 'conversation_status_changed':
      return 'Conversation status changed';
    default:
      return run.event_name || '—';
  }
};

export const formatActionResolved = entry => {
  if (!entry) return '';
  if (entry.resolved_content) return entry.resolved_content;
  if (entry.resolved_params?.url) {
    return `${entry.resolved_params.method || 'POST'} ${entry.resolved_params.url}`;
  }
  return '';
};

export const formatStatusLabel = (status, t) => {
  const map = {
    ok: t('AUTOMATION.RUNS.STATUS_OK'),
    error: t('AUTOMATION.RUNS.STATUS_ERROR'),
    partial: t('AUTOMATION.RUNS.STATUS_PARTIAL'),
    skipped: t('AUTOMATION.RUNS.STATUS_SKIPPED'),
    aborted: t('AUTOMATION.RUNS.STATUS_ABORTED'),
    started: '…',
  };
  return map[status] || status;
};

export const STATUS_ICON_MAP = {
  ok: { icon: 'i-lucide-check-circle-2', class: 'text-emerald-500' },
  error: { icon: 'i-lucide-x-circle', class: 'text-red-500' },
  partial: { icon: 'i-lucide-alert-triangle', class: 'text-amber-500' },
  skipped: { icon: 'i-lucide-minus-circle', class: 'text-n-slate-9' },
  aborted: { icon: 'i-lucide-octagon-x', class: 'text-red-500' },
  started: { icon: 'i-lucide-loader-2', class: 'text-n-slate-9' },
};

export const SUB_STATUS_ICON_MAP = {
  not_executed: { icon: 'i-lucide-skip-forward', class: 'text-n-slate-9' },
  queued: { icon: 'i-lucide-clock', class: 'text-n-slate-9' },
  blocked_24h: { icon: 'i-lucide-shield', class: 'text-amber-500' },
};
