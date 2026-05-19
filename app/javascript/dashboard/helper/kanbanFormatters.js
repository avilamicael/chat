/**
 * Formats dwell time in seconds to human-readable string.
 * Phase 3 KAN-09 — UI-SPEC §"Column metrics header".
 *
 * Returns:
 * - null/undefined input → null (caller renders em-dash)
 * - < 60s → '< 1m'
 * - < 60m → 'Xm' (e.g. '45m')
 * - < 24h → 'Xh Ym' or 'Xh' if minutes are 0
 * - >= 24h → 'Xd'
 */
export const formatDwellTime = seconds => {
  if (seconds === null || seconds === undefined) return null;
  const s = Math.max(0, Math.floor(seconds));
  if (s < 60) return '< 1m';
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return m === 0 ? `${h}h` : `${h}h ${m}m`;
  }
  return `${Math.floor(s / 86400)}d`;
};
