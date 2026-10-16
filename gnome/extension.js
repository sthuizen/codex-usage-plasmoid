import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {duration, percent, severity, friendlyTime, accountStatus, applyResult} from './format.js';

export default class CodexUsage extends Extension {
    enable() {
        this._active = true;
        this._data = null;
        this._state = 'loading';
        this._error = '';
        this._busy = false;
        this._settings = this.getSettings();
        this._button = new PanelMenu.Button(0.0, 'Codex Usage');
        this._panel = new St.BoxLayout({style_class: 'panel-status-menu-box'});
        this._button.add_child(this._panel);
        this._button.menu.actor.add_style_class_name('codex-menu');
        this._details = new PopupMenu.PopupMenuSection();
        const detailsItem = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const scroll = new St.ScrollView({
            style_class: 'codex-scroll', x_expand: true,
            hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.AUTOMATIC,
        });
        scroll.set_child(this._details.actor);
        detailsItem.add_child(scroll);
        this._button.menu.addMenuItem(detailsItem);
        this._button.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._refreshItem = this._button.menu.addAction('Refresh now', () => this._run('usage'));
        this._loginItem = this._button.menu.addAction('Sign in with ChatGPT', () => this._run('login'));
        this._installItem = this._button.menu.addAction('Install Codex…', () => {
            Gio.AppInfo.launch_default_for_uri('https://developers.openai.com/codex/cli/', null);
        });
        this._button.menu.addAction('Preferences…', () => this.openPreferences());
        this._button.menu.connect('open-state-changed', (_menu, open) => {
            if (open) this._render();
        });
        this._settingsSignal = this._settings.connect('changed', (_settings, key) => {
            if (key === 'refresh-minutes') this._schedule();
            if (key === 'codex-path') {
                this._stopProcess();
                this._data = null;
                this._run('usage');
            }
            this._render();
        });
        Main.panel.addToStatusArea(this.uuid, this._button);
        this._schedule();
        this._run('usage');
    }

    _schedule() {
        if (this._timer) GLib.Source.remove(this._timer);
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
            this._settings.get_int('refresh-minutes') * 60, () => {
                this._run('usage');
                return GLib.SOURCE_CONTINUE;
            });
    }

    _stopProcess() {
        const process = this._process;
        this._process = null;
        this._cancellable?.cancel();
        this._cancellable = null;
        // SIGTERM lets the Python bridge reap its app-server child.
        if (process) process.send_signal(15);
        if (this._deadline) GLib.Source.remove(this._deadline);
        this._deadline = 0;
        this._busy = false;
    }

    _run(action) {
        if (!this._active || this._busy) return;
        this._busy = true;
        this._action = action;
        this._render();
        let process;
        try {
            const launcher = new Gio.SubprocessLauncher({
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
            });
            const codexPath = this._settings.get_string('codex-path').trim();
            if (codexPath) launcher.setenv('CODEX_USAGE_CODEX_BIN', codexPath, true);
            process = launcher.spawnv(['python3', `${this.path}/bridge/fetch_usage.py`, action]);
            this._process = process;
            this._cancellable = new Gio.Cancellable();
            this._deadline = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
                action === 'login' ? 350 : 75, () => {
                    this._deadline = 0;
                    this._stopProcess();
                    this._accept({ok: false, state: 'error', message: 'Codex timed out. Try refreshing again.'});
                    return GLib.SOURCE_REMOVE;
                });
            process.communicate_utf8_async(null, this._cancellable, (source, result) => {
                if (!this._active || this._process !== process) return;
                if (this._deadline) GLib.Source.remove(this._deadline);
                this._deadline = 0;
                this._process = null;
                this._cancellable = null;
                this._busy = false;
                try {
                    const [, stdout] = source.communicate_utf8_finish(result);
                    const payload = JSON.parse(stdout.trim());
                    if (payload.state === 'login_complete' && payload.ok) {
                        this._run('usage');
                        return;
                    }
                    this._accept(payload);
                } catch (_error) {
                    this._accept({ok: false, state: 'error', message: 'Could not read Codex usage. Check Python and the Codex executable in Preferences.'});
                }
            });
        } catch (_error) {
            this._stopProcess();
            this._accept({ok: false, state: 'error', message: 'Could not start the usage bridge. Python 3 is required.'});
        }
    }

    _accept(payload) {
        const result = applyResult(this._data, payload);
        this._data = result.data;
        this._error = result.error;
        this._state = payload.state;
        this._render();
    }

    _line(text, className = '') {
        const item = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        const label = new St.Label({text, style_class: className, x_expand: true});
        label.clutter_text.line_wrap = true;
        item.add_child(label);
        this._details.addMenuItem(item);
    }

    _render() {
        if (!this._active) return;
        const appearance = this._settings.get_string('appearance');
        for (const target of [this._button, this._button.menu.actor]) {
            target.remove_style_class_name('codex-dark');
            target.remove_style_class_name('codex-light');
            if (appearance !== 'auto') target.add_style_class_name(`codex-${appearance}`);
        }
        this._panel.destroy_all_children();
        this._panel.add_child(new St.Icon({icon_name: 'utilities-system-monitor-symbolic', style_class: 'system-status-icon'}));
        const windows = this._data?.windows ?? [];
        for (const [index, window] of windows.slice(0, 2).entries()) {
            if (index > 0) this._panel.add_child(new St.Label({
                text: '|',
                y_align: Clutter.ActorAlign.CENTER,
                style_class: 'codex-separator',
            }));
            this._panel.add_child(new St.Label({
                text: `${duration(window.windowDurationMins)} ${percent(window.remainingPercent)}`,
                y_align: Clutter.ActorAlign.CENTER,
                style_class: `codex-${severity(window.remainingPercent)}`,
            }));
        }
        let suffix = windows.length > 2 ? `+${windows.length - 2}` : '';
        if (!windows.length) suffix = this._data ? 'No windows'
            : this._state === 'auth_required' || this._state === 'unsupported_auth' ? 'Sign in'
            : this._state === 'codex_missing' ? 'Install Codex' : 'Unavailable';
        if (this._busy) suffix = windows.length ? `${suffix} …` : this._action === 'login' ? 'Signing in…' : 'Updating…';
        else if (this._error && this._data) suffix += ' !';
        if (suffix) this._panel.add_child(new St.Label({text: suffix, y_align: Clutter.ActorAlign.CENTER}));
        this._button.accessible_name = `Codex allowance remaining: ${windows.map(w => `${duration(w.windowDurationMins)} ${percent(w.remainingPercent)}`).join(', ')} ${suffix}`;
        this._details.removeAll();
        this._line('Codex Usage', 'codex-heading');
        if (this._busy) this._line(this._action === 'login' ? 'Complete sign-in in your browser…' : 'Updating allowance…', 'codex-muted');
        for (const window of windows) {
            const title = `${window.limitName ? `${window.limitName} · ` : ''}${duration(window.windowDurationMins)} window`;
            const row = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
            const column = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL, x_expand: true, style_class: 'codex-window'});
            const heading = new St.BoxLayout({style_class: 'codex-window-heading'});
            heading.add_child(new St.Icon({icon_name: Number(window.windowDurationMins) >= 1440 ? 'x-office-calendar-symbolic' : 'preferences-system-time-symbolic', icon_size: 16}));
            heading.add_child(new St.Label({text: title, x_expand: true}));
            heading.add_child(new St.Label({text: `${percent(window.remainingPercent)} left`, style_class: `codex-${severity(window.remainingPercent)}`}));
            column.add_child(heading);
            const track = new St.Widget({style_class: 'codex-track', height: 5, x_expand: true});
            const fill = new St.Widget({style_class: `codex-fill codex-fill-${severity(window.remainingPercent)}`, height: 5});
            track.add_child(fill);
            track.connect('notify::width', () => {
                const n = Number(window.remainingPercent);
                fill.width = track.width * (Number.isFinite(n) ? Math.max(0, Math.min(100, n)) / 100 : 0);
            });
            column.add_child(track);
            column.add_child(new St.Label({text: `Resets ${friendlyTime(window.resetsAt)}`, style_class: 'codex-muted'}));
            row.add_child(column);
            this._details.addMenuItem(row);
        }
        if (this._data) {
            if (!windows.length) this._line('Codex reported no active usage windows.');
            this._details.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            const plan = this._data.planType || 'Unknown';
            this._line(`Plan: ${plan.charAt(0).toUpperCase()}${plan.slice(1)}`);
            this._line(`Additional credits: ${this._data.credits?.unlimited ? 'Unlimited' : this._data.credits?.balance ?? 'Unknown'}`);
            this._line(`Reset credits: ${this._data.resetCredits ?? 'Unknown'}`);
            this._line(`Status: ${this._error ? 'Update failed · showing last successful reading' : accountStatus(this._data)}`);
            this._line(`Last updated: ${friendlyTime(this._data.fetchedAt)}`, 'codex-muted');
        }
        if (this._error) this._line(this._error, 'codex-low');
        this._refreshItem.setSensitive(!this._busy);
        this._loginItem.visible = ['auth_required', 'unsupported_auth'].includes(this._state);
        this._loginItem.setSensitive(!this._busy);
        this._installItem.visible = this._state === 'codex_missing';
    }

    disable() {
        this._active = false;
        this._stopProcess();
        if (this._timer) GLib.Source.remove(this._timer);
        this._timer = 0;
        if (this._settingsSignal) this._settings.disconnect(this._settingsSignal);
        this._settingsSignal = 0;
        this._details?.destroy();
        this._button?.destroy();
        this._button = null;
        this._panel = null;
        this._details = null;
        this._refreshItem = null;
        this._loginItem = null;
        this._installItem = null;
        this._settings = null;
        this._data = null;
    }
}
