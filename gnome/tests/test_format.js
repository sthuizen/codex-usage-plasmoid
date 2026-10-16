import {duration, percent, severity, friendlyTime, applyResult} from '../format.js';
function equal(actual, expected) {
    if (actual !== expected) throw new Error(`Expected ${expected}; got ${actual}`);
}
equal(duration(300), '5h');
equal(duration(10080), '1w');
equal(duration(20160), '2w');
equal(duration(90), '90m');
equal(duration(null), 'Window');
equal(percent(null), '—');
equal(percent(NaN), '—');
equal(percent(110), '100%');
equal(severity(20), 'low');
equal(severity(50), 'warning');
equal(severity(51), 'healthy');
equal(severity(null), 'unknown');
equal(friendlyTime(null), 'Unavailable');
const now = new Date(2026, 9, 4, 12);
equal(friendlyTime(now.getTime() / 1000, now).startsWith('Today at'), true);
const tomorrow = new Date(2026, 9, 5, 12);
equal(friendlyTime(tomorrow.getTime() / 1000, now).startsWith('Tomorrow at'), true);
const previous = {windows: [{remainingPercent: 42}]};
equal(applyResult(previous, {state: 'error', message: 'Offline'}).data, previous);
equal(applyResult(previous, {state: 'auth_required'}).data, null);
equal(applyResult(previous, {state: 'unsupported_auth'}).data, null);
equal(applyResult(previous, {state: 'codex_missing'}).data, null);
const next = {ok: true, state: 'ready', windows: []};
equal(applyResult(previous, next).data, next);
print('20 formatting and state assertions passed');
