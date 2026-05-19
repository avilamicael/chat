# Phase 3 AUT-10 — Sliding-window throttle por inbox WhatsApp (Baileys).
# 1 bucket por minuto (key: automation_throttle:inbox:<id>:YYYYMMDDHHMM) — INCR atômico no Redis,
# TTL 90s para cobrir borda entre minutos e prevenir vazamento de memória.
# NULL em max_automation_messages_per_minute = :acquired sempre (sem limite).
# Non-whatsapp inbox = :acquired sempre (throttle não se aplica).
class AutomationRules::ThrottleService
  pattr_initialize [:inbox!]

  # Returns :acquired OR Integer (segundos a esperar até o próximo bucket).
  def acquire
    return :acquired unless inbox.whatsapp?
    return :acquired if limit.nil?

    bucket = Time.current.strftime('%Y%m%d%H%M')
    key = format(Redis::Alfred::AUTOMATION_THROTTLE_BUCKET, inbox_id: inbox.id, bucket: bucket)

    current = Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 90) if current == 1

    return :acquired if current <= limit

    seconds_to_next_minute
  end

  private

  def limit
    inbox.channel.max_automation_messages_per_minute
  end

  def seconds_to_next_minute
    60 - Time.current.sec
  end
end
