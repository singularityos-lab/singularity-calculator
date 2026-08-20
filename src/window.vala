using Gtk;
using Singularity;
using Singularity.Widgets;

namespace Singularity.Apps {

    /**
     * The calculator view. It owns no arithmetic of its own: every key routes
     * into {@link CalculatorEngine} and the display is rebuilt from the
     * engine's notifications, so no code path can forget to refresh.
     */
    [GtkTemplate(ui = "/dev/sinty/calculator/ui/main.ui")]
    public class CalculatorWindow : Singularity.Widgets.Window {

        [GtkChild] unowned Box   main_box;
        [GtkChild] unowned Label display_label;
        [GtkChild] unowned Label history_label;
        [GtkChild] unowned Grid  basic_keypad;
        [GtkChild] unowned Grid  advanced_keypad;

        private CalculatorEngine engine = new CalculatorEngine();

        private bool is_advanced = false;

        private Button mode_bubble;
        private Label  memory_bubble;
        private Label  deg_rad_label;
        private ListBox log_list;
        private Popover log_popover;

        public CalculatorWindow(Gtk.Application app) {
            Object(application: app);

            set_title(_("Calculator"));
            set_default_size(380, 680);

            mode_bubble = add_bubble_text(_("Basic"), () => toggle_mode());
            add_bubble_menu("document-open-recent-symbolic",
                            _("Calculation history"),
                            build_log_popover());
            memory_bubble = add_bubble_label("M", true);
            memory_bubble.visible = false;

            main_box.add_css_class("calculator-app");
            populate_basic_keypad();
            populate_advanced_keypad();
            main_box.remove(advanced_keypad);

            set_content(main_box);

            engine.notify.connect(() => update_display());
            update_display();

            ((Gtk.Widget) this).add_controller(build_key_controller());
        }

        // ------------------------------------------------------------------
        // Display
        // ------------------------------------------------------------------

        private void update_display() {
            if (engine.has_error) {
                display_label.label = status_text(engine.status);
                display_label.add_css_class("error-text");
            } else {
                display_label.label = engine.display;
                display_label.remove_css_class("error-text");
            }
            history_label.label = engine.history;
            memory_bubble.visible = engine.has_memory;
        }

        /**
         * The engine stays free of gettext so it can be unit-tested without a
         * translation domain; turning its status into words happens here.
         */
        private string status_text(CalculatorEngine.Status status) {
            switch (status) {
                case CalculatorEngine.Status.DIVIDE_BY_ZERO:
                    return _("Cannot divide by zero");
                case CalculatorEngine.Status.DOMAIN_ERROR:
                    return _("Undefined for this value");
                case CalculatorEngine.Status.FACTORIAL_RANGE:
                    return _("Factorial out of range");
                case CalculatorEngine.Status.OVERFLOW:
                    return _("Number too large");
                default:
                    return _("Error");
            }
        }

        private void toggle_mode() {
            is_advanced = !is_advanced;
            if (is_advanced) {
                mode_bubble.label = _("Advanced");
                main_box.remove(basic_keypad);
                main_box.append(advanced_keypad);
            } else {
                mode_bubble.label = _("Basic");
                main_box.remove(advanced_keypad);
                main_box.append(basic_keypad);
            }
        }

        // ------------------------------------------------------------------
        // Calculation log
        // ------------------------------------------------------------------

        private Popover build_log_popover() {
            log_list = new ListBox();
            log_list.selection_mode = SelectionMode.NONE;
            log_list.add_css_class("boxed-list");
            log_list.row_activated.connect((row) => {
                var label = row.get_child() as Label;
                if (label == null) return;
                engine.set_value(result_of(label.label));
                log_popover.popdown();
            });

            var scroller = new ScrolledWindow();
            scroller.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scroller.set_child(log_list);
            scroller.set_size_request(280, 240);

            log_popover = new Popover();
            log_popover.set_child(scroller);
            log_popover.notify["visible"].connect(() => {
                if (log_popover.visible) refresh_log();
            });
            return log_popover;
        }

        private void refresh_log() {
            Widget? child = log_list.get_first_child();
            while (child != null) {
                Widget? next = child.get_next_sibling();
                log_list.remove(child);
                child = next;
            }

            string[] entries = engine.get_log();
            if (entries.length == 0) {
                var empty = new Label(_("No calculations yet"));
                empty.add_css_class("dim-label");
                empty.margin_top = 12;
                empty.margin_bottom = 12;
                log_list.append(empty);
                return;
            }
            // Newest first: the last thing computed is what you want to reuse.
            for (int i = entries.length - 1; i >= 0; i--) {
                var label = new Label(entries[i]);
                label.halign = Align.END;
                label.margin_top = 6;
                label.margin_bottom = 6;
                label.margin_start = 12;
                label.margin_end = 12;
                log_list.append(label);
            }
        }

        private static double result_of(string log_entry) {
            int sep = log_entry.last_index_of(" = ");
            if (sep < 0) return 0;
            return double.parse(log_entry.substring(sep + 3));
        }

        // ------------------------------------------------------------------
        // Clipboard
        // ------------------------------------------------------------------

        private void copy_result() {
            ((Gtk.Widget) this).get_clipboard().set_text(display_label.label);
        }

        private void paste_number() {
            var clipboard = ((Gtk.Widget) this).get_clipboard();
            clipboard.read_text_async.begin(null, (obj, res) => {
                try {
                    string? text = clipboard.read_text_async.end(res);
                    if (text == null) return;
                    double value;
                    if (parse_pasted(text, out value)) engine.set_value(value);
                } catch (GLib.Error e) {
                    // A clipboard without text is not worth reporting.
                }
            });
        }

        /**
         * Accepts what a user is likely to have copied from elsewhere: a
         * locale-formatted number with a comma separator and/or thousands
         * spacing. The engine itself only ever speaks ASCII with a dot.
         */
        private static bool parse_pasted(string text, out double value) {
            value = 0;
            var sb = new StringBuilder();
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                if (c == ',') {
                    sb.append_c('.');
                } else if ((c >= '0' && c <= '9')
                           || c == '.' || c == '-' || c == '+'
                           || c == 'e' || c == 'E') {
                    sb.append_c(c);
                }
                // Anything else (spaces, thin spaces, apostrophes, currency
                // symbols) is grouping noise and is dropped.
            }
            return double.try_parse(sb.str, out value);
        }

        // ------------------------------------------------------------------
        // Keyboard
        // ------------------------------------------------------------------

        private EventControllerKey build_key_controller() {
            var controller = new EventControllerKey();
            controller.key_pressed.connect((keyval, keycode, state) => {
                if (Gdk.ModifierType.CONTROL_MASK in state) {
                    switch (keyval) {
                        case Gdk.Key.c: case Gdk.Key.C: copy_result();  return true;
                        case Gdk.Key.v: case Gdk.Key.V: paste_number(); return true;
                    }
                    return false;
                }

                switch (keyval) {
                    case Gdk.Key.@0: case Gdk.Key.KP_0: engine.append_digit("0"); return true;
                    case Gdk.Key.@1: case Gdk.Key.KP_1: engine.append_digit("1"); return true;
                    case Gdk.Key.@2: case Gdk.Key.KP_2: engine.append_digit("2"); return true;
                    case Gdk.Key.@3: case Gdk.Key.KP_3: engine.append_digit("3"); return true;
                    case Gdk.Key.@4: case Gdk.Key.KP_4: engine.append_digit("4"); return true;
                    case Gdk.Key.@5: case Gdk.Key.KP_5: engine.append_digit("5"); return true;
                    case Gdk.Key.@6: case Gdk.Key.KP_6: engine.append_digit("6"); return true;
                    case Gdk.Key.@7: case Gdk.Key.KP_7: engine.append_digit("7"); return true;
                    case Gdk.Key.@8: case Gdk.Key.KP_8: engine.append_digit("8"); return true;
                    case Gdk.Key.@9: case Gdk.Key.KP_9: engine.append_digit("9"); return true;

                    // Comma too: French and German keypads emit it for the
                    // decimal key, and the engine normalises to a dot anyway.
                    case Gdk.Key.period: case Gdk.Key.KP_Decimal:
                    case Gdk.Key.comma:  case Gdk.Key.KP_Separator:
                        engine.append_dot(); return true;

                    case Gdk.Key.plus: case Gdk.Key.KP_Add:
                        engine.set_operation(CalculatorEngine.Operation.ADD); return true;
                    case Gdk.Key.minus: case Gdk.Key.KP_Subtract:
                        engine.set_operation(CalculatorEngine.Operation.SUBTRACT); return true;
                    case Gdk.Key.asterisk: case Gdk.Key.KP_Multiply:
                        engine.set_operation(CalculatorEngine.Operation.MULTIPLY); return true;
                    case Gdk.Key.slash: case Gdk.Key.KP_Divide:
                        engine.set_operation(CalculatorEngine.Operation.DIVIDE); return true;
                    case Gdk.Key.asciicircum:
                        engine.set_operation(CalculatorEngine.Operation.POWER); return true;

                    case Gdk.Key.parenleft:  engine.open_paren();  return true;
                    case Gdk.Key.parenright: engine.close_paren(); return true;

                    case Gdk.Key.Return: case Gdk.Key.KP_Enter:
                    case Gdk.Key.equal:  case Gdk.Key.KP_Equal:
                        engine.equals(); return true;

                    case Gdk.Key.Escape: case Gdk.Key.Delete:
                        engine.clear(); return true;
                    case Gdk.Key.BackSpace:
                        engine.backspace(); return true;
                    case Gdk.Key.percent:
                        engine.percent(); return true;
                    case Gdk.Key.exclam:
                        engine.apply_function(CalculatorEngine.Function.FACTORIAL); return true;
                }
                return false;
            });
            return controller;
        }

        // ------------------------------------------------------------------
        // Keypads
        // ------------------------------------------------------------------

        private void populate_basic_keypad() {
            add_key(basic_keypad, "C",  _("Clear"),      0, 0, "func-btn", () => engine.clear());
            add_key(basic_keypad, "⌫", _("Backspace"), 1, 0, "func-btn", () => engine.backspace());
            add_key(basic_keypad, "%",  _("Percent"),    2, 0, "func-btn", () => engine.percent());
            add_key(basic_keypad, "÷", _("Divide"), 3, 0, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.DIVIDE));

            add_digit_row(basic_keypad, "7", "8", "9", 1);
            add_key(basic_keypad, "×", _("Multiply"), 3, 1, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.MULTIPLY));

            add_digit_row(basic_keypad, "4", "5", "6", 2);
            add_key(basic_keypad, "−", _("Subtract"), 3, 2, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.SUBTRACT));

            add_digit_row(basic_keypad, "1", "2", "3", 3);
            add_key(basic_keypad, "+", _("Add"), 3, 3, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.ADD));

            add_key(basic_keypad, "0", _("Zero"), 0, 4, "num-btn", () => engine.append_digit("0"));
            add_key(basic_keypad, ".", _("Decimal point"), 1, 4, "num-btn", () => engine.append_dot());
            add_key(basic_keypad, "±", _("Negate"), 2, 4, "func-btn", () => engine.negate());
            add_key(basic_keypad, "=", _("Equals"), 3, 4, "suggested-action", () => engine.equals());
        }

        private void populate_advanced_keypad() {
            add_key(advanced_keypad, "MC", _("Memory clear"), 0, 0, "func-btn", () => engine.memory_clear());
            add_key(advanced_keypad, "MR", _("Memory recall"), 1, 0, "func-btn", () => engine.memory_recall());
            add_key(advanced_keypad, "M+", _("Memory add"), 2, 0, "func-btn", () => engine.memory_add());
            add_key(advanced_keypad, "M−", _("Memory subtract"), 3, 0, "func-btn", () => engine.memory_subtract());
            advanced_keypad.attach(build_angle_button(), 4, 0, 1, 1);

            add_key(advanced_keypad, "sin", _("Sine"), 0, 1, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.SIN));
            add_key(advanced_keypad, "cos", _("Cosine"), 1, 1, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.COS));
            add_key(advanced_keypad, "tan", _("Tangent"), 2, 1, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.TAN));
            add_key(advanced_keypad, "log", _("Base 10 logarithm"), 3, 1, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.LOG10));
            add_key(advanced_keypad, "ln", _("Natural logarithm"), 4, 1, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.LN));

            add_key(advanced_keypad, "(", _("Open parenthesis"), 0, 2, "func-btn", () => engine.open_paren());
            add_key(advanced_keypad, ")", _("Close parenthesis"), 1, 2, "func-btn", () => engine.close_paren());
            add_key(advanced_keypad, "^", _("Power"), 2, 2, "func-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.POWER));
            add_key(advanced_keypad, "√", _("Square root"), 3, 2, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.SQRT));
            add_key(advanced_keypad, "!", _("Factorial"), 4, 2, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.FACTORIAL));

            add_key(advanced_keypad, "x²", _("Square"), 0, 3, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.SQUARE));
            add_key(advanced_keypad, "1÷x", _("Reciprocal"), 1, 3, "func-btn",
                    () => engine.apply_function(CalculatorEngine.Function.RECIPROCAL));
            add_key(advanced_keypad, "e", _("Euler's number"), 2, 3, "func-btn", () => engine.append_e());
            add_key(advanced_keypad, "π", _("Pi"), 3, 3, "func-btn", () => engine.append_pi());
            add_key(advanced_keypad, "%", _("Percent"), 4, 3, "func-btn", () => engine.percent());

            add_digit_row(advanced_keypad, "7", "8", "9", 4);
            add_key(advanced_keypad, "÷", _("Divide"), 3, 4, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.DIVIDE));
            add_key(advanced_keypad, "C", _("Clear"), 4, 4, "func-btn", () => engine.clear());

            add_digit_row(advanced_keypad, "4", "5", "6", 5);
            add_key(advanced_keypad, "×", _("Multiply"), 3, 5, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.MULTIPLY));
            add_key(advanced_keypad, "⌫", _("Backspace"), 4, 5, "func-btn", () => engine.backspace());

            add_digit_row(advanced_keypad, "1", "2", "3", 6);
            add_key(advanced_keypad, "−", _("Subtract"), 3, 6, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.SUBTRACT));
            add_key(advanced_keypad, "±", _("Negate"), 4, 6, "func-btn", () => engine.negate());

            add_key(advanced_keypad, "0", _("Zero"), 0, 7, "num-btn", () => engine.append_digit("0"));
            add_key(advanced_keypad, ".", _("Decimal point"), 1, 7, "num-btn", () => engine.append_dot());
            add_key(advanced_keypad, "+", _("Add"), 2, 7, "op-btn",
                    () => engine.set_operation(CalculatorEngine.Operation.ADD));
            add_key(advanced_keypad, "=", _("Equals"), 3, 7, "suggested-action", () => engine.equals());
            add_key(advanced_keypad, "AC", _("All clear"), 4, 7, "func-btn", () => {
                engine.clear();
                engine.memory_clear();
                engine.clear_log();
            });
        }

        private Button build_angle_button() {
            var btn = new Button();
            btn.add_css_class("calc-btn");
            btn.add_css_class("func-btn");
            deg_rad_label = new Label(_("Deg"));
            btn.set_child(deg_rad_label);
            btn.update_property(Gtk.AccessibleProperty.LABEL, _("Toggle degrees or radians"));
            btn.clicked.connect(() => {
                bool degrees = engine.angle_unit == CalculatorEngine.AngleUnit.DEGREES;
                engine.angle_unit = degrees
                    ? CalculatorEngine.AngleUnit.RADIANS
                    : CalculatorEngine.AngleUnit.DEGREES;
                deg_rad_label.label = degrees ? _("Rad") : _("Deg");
            });
            return btn;
        }

        private void add_digit_row(Grid grid, string a, string b, string c, int row) {
            add_key(grid, a, a, 0, row, "num-btn", () => engine.append_digit(a));
            add_key(grid, b, b, 1, row, "num-btn", () => engine.append_digit(b));
            add_key(grid, c, c, 2, row, "num-btn", () => engine.append_digit(c));
        }

        private delegate void ClickedCallback();

        /**
         * `callback` must be `owned`: it outlives this call inside the clicked
         * handler, and a borrowed delegate would dangle there.
         */
        private void add_key(Grid grid, string label, string description,
                             int col, int row, string css_class,
                             owned ClickedCallback callback) {
            var btn = new Button.with_label(label);
            btn.add_css_class("calc-btn");
            btn.add_css_class(css_class);
            btn.update_property(Gtk.AccessibleProperty.LABEL, description);
            btn.clicked.connect(() => callback());
            grid.attach(btn, col, row);
        }
    }
}
