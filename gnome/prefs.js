import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class CodexUsagePreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        const page = new Adw.PreferencesPage({title: 'Codex Usage', icon_name: 'utilities-system-monitor-symbolic'});
        window.add(page);
        const group = new Adw.PreferencesGroup({title: 'Allowance indicator', description: 'Shows Codex subscription usage reported by your local Codex login.'});
        page.add(group);
        const interval = new Adw.SpinRow({
            title: 'Refresh interval', subtitle: 'Minutes between updates',
            adjustment: new Gtk.Adjustment({lower: 1, upper: 1440, step_increment: 1, page_increment: 5}),
        });
        settings.bind('refresh-minutes', interval, 'value', Gio.SettingsBindFlags.DEFAULT);
        group.add(interval);
        const modes = ['auto', 'dark', 'light'];
        const appearance = new Adw.ComboRow({title: 'Appearance', model: Gtk.StringList.new(['Follow GNOME Shell', 'Dark', 'Light']), selected: modes.indexOf(settings.get_string('appearance'))});
        appearance.connect('notify::selected', () => settings.set_string('appearance', modes[appearance.selected]));
        group.add(appearance);
        const path = new Adw.EntryRow({title: 'Codex executable (blank for automatic)', text: settings.get_string('codex-path'), show_apply_button: true});
        path.connect('apply', () => settings.set_string('codex-path', path.text.trim()));
        group.add(path);
        const about = new Adw.PreferencesGroup({title: 'Account and privacy', description: 'Sign in from the top-bar menu. Codex handles credentials; this extension does not read or store tokens. Allowance is for Codex, not general ChatGPT messages or API billing.'});
        page.add(about);
    }
}
