export function duration(minutes) {
    const n = Number(minutes);
    if (!Number.isFinite(n) || n <= 0) return 'Window';
    for (const [size, unit] of [[10080, 'w'], [1440, 'd'], [60, 'h']]) {
        if (n % size === 0) return `${n / size}${unit}`;
    }
    return `${n}m`;
}

export function percent(value) {
    return typeof value === 'number' && Number.isFinite(value)
        ? `${Math.round(Math.max(0, Math.min(100, value)))}%` : '—';
}

export function severity(value) {
    if (typeof value !== 'number' || !Number.isFinite(value)) return 'unknown';
    return value <= 20 ? 'low' : value <= 50 ? 'warning' : 'healthy';
}

export function friendlyTime(epoch, now = new Date()) {
    if (!epoch || !Number.isFinite(Number(epoch))) return 'Unavailable';
    const date = new Date(Number(epoch) * 1000);
    if (Number.isNaN(date.getTime())) return 'Unavailable';
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);
    const day = date.toDateString() === now.toDateString() ? 'Today'
        : date.toDateString() === tomorrow.toDateString() ? 'Tomorrow'
        : date.toLocaleDateString(undefined, {year: 'numeric', month: 'short', day: 'numeric'});
    return `${day} at ${date.toLocaleTimeString(undefined, {hour: '2-digit', minute: '2-digit'})}`;
}

export function accountStatus(data) {
    return data.spendControlReached ? 'Spending control reached'
        : data.rateLimitReachedType ? 'Rate limit reached' : 'Usage available';
}

export function applyResult(previous, payload) {
    if (payload.ok && payload.state === 'ready') return {data: payload, error: ''};
    // Never display another signed-out account's cached allowance.
    const keep = payload.state === 'error';
    return {data: keep ? previous : null, error: payload.message || 'Usage is unavailable'};
}
