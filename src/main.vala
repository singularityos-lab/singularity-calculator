using Gtk;
using Singularity;

namespace Singularity.Apps {

    public class CalculatorApp : Singularity.Application {

        private CalculatorWindow? window = null;
        private bool start_advanced = false;

        public CalculatorApp() {
            Object(application_id: "dev.sinty.calculator",
                   flags: ApplicationFlags.DEFAULT_FLAGS);
            add_main_option("advanced", 0, OptionFlags.NONE, OptionArg.NONE, _("Open in advanced mode"), null);
        }

        protected override int handle_local_options(VariantDict options) {
            if (!options.contains("advanced")) return -1;
            try {
                register();
            } catch (Error e) {
                warning("Calculator registration error: %s", e.message);
                return 1;
            }
            if (!get_is_remote()) {
                start_advanced = true;
                return -1;
            }
            activate();
            activate_action("advanced-mode", null);
            return 0;
        }

        protected override void startup() {
            base.startup();
            setup_styles();

            var menu = new GLib.Menu();
            var file_menu = new GLib.Menu();
            file_menu.append(_("Close Window"), "win.close");
            file_menu.append(_("Quit"), "app.quit");
            menu.append_submenu(_("File"), file_menu);
            var edit_menu = new GLib.Menu();
            var clipboard_section = new GLib.Menu();
            clipboard_section.append(_("Copy"), "win.copy");
            clipboard_section.append(_("Paste"), "win.paste");
            edit_menu.append_section(null, clipboard_section);
            var clear_section = new GLib.Menu();
            clear_section.append(_("Clear All"), "win.clear");
            edit_menu.append_section(null, clear_section);
            var settings_section = new GLib.Menu();
            settings_section.append(_("Settings"), "app.settings");
            edit_menu.append_section(null, settings_section);
            menu.append_submenu(_("Edit"), edit_menu);
            var view_menu = new GLib.Menu();
            var mode_section = new GLib.Menu();
            mode_section.append(_("Basic"), "win.mode::basic");
            mode_section.append(_("Advanced"), "win.mode::advanced");
            view_menu.append_section(null, mode_section);
            var angle_section = new GLib.Menu();
            angle_section.append(_("Degrees"), "win.angle::degrees");
            angle_section.append(_("Radians"), "win.angle::radians");
            view_menu.append_section(null, angle_section);
            menu.append_submenu(_("View"), view_menu);
            set_menubar(menu);

            var act_quit = new SimpleAction("quit", null);
            act_quit.activate.connect(() => quit());
            add_action(act_quit);
            var act_advanced = new SimpleAction("advanced-mode", null);
            act_advanced.activate.connect(() => {
                activate();
                window.activate_action_variant("win.mode", new Variant.string("advanced"));
            });
            add_action(act_advanced);
            var act_settings = new SimpleAction("settings", null);
            act_settings.activate.connect(() => {
                try {
                    Singularity.Shell.ShellService shell = Bus.get_proxy_sync(BusType.SESSION, "dev.sinty.desktop", "/dev/sinty/Shell");
                    shell.open_app_settings("dev.sinty.calculator");
                } catch (Error e) {
                    warning("Failed to open settings: %s", e.message);
                }
            });
            add_action(act_settings);
            set_accels_for_action("app.settings", {"<Control>comma"});
            set_accels_for_action("win.close", {"<Control>w"});
            set_accels_for_action("win.copy", {"<Control>c"});
            set_accels_for_action("win.paste", {"<Control>v"});
            set_accels_for_action("win.mode::basic", {"<Control>b"});
            set_accels_for_action("win.mode::advanced", {"<Control>m"});
        }

        protected override void activate() {
            if (window != null) {
                window.present();
                return;
            }
            window = new CalculatorWindow(this);
            // Without this the reference outlives the widget and a second
            // activation would present a destroyed window.
            window.close_request.connect(() => {
                window = null;
                return false;
            });
            window.present();
            if (start_advanced) {
                start_advanced = false;
                activate_action("advanced-mode", null);
            }
        }

        private void setup_styles() {
            var provider = new Gtk.CssProvider();
            provider.load_from_resource("/dev/sinty/calculator/style.css");
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), provider,
                Gtk.STYLE_PROVIDER_PRIORITY_USER + 2);
        }

        public static int main(string[] args) {
            Intl.setlocale(GLib.LocaleCategory.ALL, "");

            string locale_dir = "/usr/share/locale";
            try {
                string exe = GLib.FileUtils.read_link("/proc/self/exe");
                locale_dir = GLib.Path.build_filename(
                    GLib.Path.get_dirname(GLib.Path.get_dirname(exe)),
                    "share", "locale");
            } catch (GLib.Error e) {
                // Fall back to the system-wide location.
            }
            Intl.bindtextdomain("singularity-calculator", locale_dir);
            Intl.bind_textdomain_codeset("singularity-calculator", "UTF-8");
            Intl.textdomain("singularity-calculator");

            var app = new CalculatorApp();
            new ConversionSearchProvider().export(app);
            return app.run(args);
        }
    }
}
