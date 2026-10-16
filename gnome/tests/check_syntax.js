import GLib from 'gi://GLib';
for (const name of ARGV) {
    const [, bytes] = GLib.file_get_contents(name);
    Reflect.parse(new TextDecoder().decode(bytes), {target: 'module'});
    print(`Syntax OK: ${name}`);
}
