using Gtk;
using Singularity;

namespace Singularity.Apps {

    public class CalculatorApp : Singularity.Application {

        private CalculatorWindow? window = null;

        public CalculatorApp() {
            Object(application_id: "dev.sinty.calculator",
                   flags: ApplicationFlags.DEFAULT_FLAGS);
        }

        protected override void startup() {
            base.startup();
            setup_styles();

            var menu = new GLib.Menu();
            var file_menu = new GLib.Menu();
            file_menu.append(_("Quit"), "app.quit");
            menu.append_submenu(_("File"), file_menu);
            set_menubar(menu);

            var act_quit = new SimpleAction("quit", null);
            act_quit.activate.connect(() => quit());
            add_action(act_quit);
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
            return app.run(args);
        }
    }
}
