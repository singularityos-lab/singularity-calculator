using Gtk;
using Singularity;
using Singularity.Widgets;

namespace Singularity.Apps {

    [GtkTemplate(ui = "/dev/sinty/calculator/ui/main.ui")]
    public class CalculatorWindow : Singularity.Widgets.Window {

        [GtkChild] unowned Button mode_btn;
        [GtkChild] unowned Label  mode_label;
        [GtkChild] unowned Box    main_box;
        [GtkChild] unowned Label  display_label;
        [GtkChild] unowned Label  history_label;
        [GtkChild] unowned Grid   basic_keypad;
        [GtkChild] unowned Grid   advanced_keypad;

        private string current_input = "0";
        private string previous_input = "";
        private string operation = "";
        private bool   new_input = true;
        private bool   is_advanced = false;
        private bool   use_degrees = true;

        private GLib.List<string> paren_prev_stack = new GLib.List<string>();
        private GLib.List<string> paren_op_stack   = new GLib.List<string>();

        private Label deg_rad_label;

        public CalculatorWindow(Gtk.Application app) {
            Object(application: app);

            set_title("Calculator");
            set_default_size(360, 580);

            mode_btn.add_css_class("flat");
            mode_btn.clicked.connect(toggle_mode);
            toolbar.set_title_widget(mode_btn);
            toolbar.is_static = false;

            main_box.add_css_class("calculator-app");
            populate_basic_keypad();
            populate_advanced_keypad();
            main_box.remove(advanced_keypad);

            set_content(main_box);

            var key_ctrl = new EventControllerKey();
            key_ctrl.key_pressed.connect((keyval, keycode, state) => {
                switch (keyval) {
                    case Gdk.Key.@0: case Gdk.Key.KP_0: append_digit("0"); return true;
                    case Gdk.Key.@1: case Gdk.Key.KP_1: append_digit("1"); return true;
                    case Gdk.Key.@2: case Gdk.Key.KP_2: append_digit("2"); return true;
                    case Gdk.Key.@3: case Gdk.Key.KP_3: append_digit("3"); return true;
                    case Gdk.Key.@4: case Gdk.Key.KP_4: append_digit("4"); return true;
                    case Gdk.Key.@5: case Gdk.Key.KP_5: append_digit("5"); return true;
                    case Gdk.Key.@6: case Gdk.Key.KP_6: append_digit("6"); return true;
                    case Gdk.Key.@7: case Gdk.Key.KP_7: append_digit("7"); return true;
                    case Gdk.Key.@8: case Gdk.Key.KP_8: append_digit("8"); return true;
                    case Gdk.Key.@9: case Gdk.Key.KP_9: append_digit("9"); return true;
                    case Gdk.Key.period: case Gdk.Key.KP_Decimal: append_dot(); return true;
                    case Gdk.Key.plus: case Gdk.Key.KP_Add: set_op("+"); return true;
                    case Gdk.Key.minus: case Gdk.Key.KP_Subtract: set_op("-"); return true;
                    case Gdk.Key.asterisk: case Gdk.Key.KP_Multiply: set_op("*"); return true;
                    case Gdk.Key.slash: case Gdk.Key.KP_Divide: set_op("/"); return true;
                    case Gdk.Key.Return: case Gdk.Key.KP_Enter: case Gdk.Key.equal: case Gdk.Key.KP_Equal: calculate(); return true;
                    case Gdk.Key.Escape: case Gdk.Key.Delete: clear_all(); return true;
                    case Gdk.Key.percent: percent(); return true;
                    case Gdk.Key.BackSpace:
                        if (!new_input && current_input.length > 1)
                            current_input = current_input.substring(0, current_input.length - 1);
                        else { current_input = "0"; new_input = true; }
                        update_display();
                        return true;
                }
                return false;
            });
            ((Gtk.Widget) this).add_controller (key_ctrl);
        }

        private void toggle_mode() {
            is_advanced = !is_advanced;
            if (is_advanced) {
                mode_label.label = "Advanced";
                main_box.remove(basic_keypad);
                main_box.append(advanced_keypad);
            } else {
                mode_label.label = "Basic";
                main_box.remove(advanced_keypad);
                main_box.append(basic_keypad);
            }
        }

        private void populate_basic_keypad() {
            add_key(basic_keypad, "C", 0, 0, "func-btn", () => clear_all());
            add_key(basic_keypad, "±", 1, 0, "func-btn", () => negate());
            add_key(basic_keypad, "%", 2, 0, "func-btn", () => percent());
            add_key(basic_keypad, "÷", 3, 0, "op-btn", () => set_op("/"));
            add_key(basic_keypad, "7", 0, 1, "num-btn", () => append_digit("7"));
            add_key(basic_keypad, "8", 1, 1, "num-btn", () => append_digit("8"));
            add_key(basic_keypad, "9", 2, 1, "num-btn", () => append_digit("9"));
            add_key(basic_keypad, "×", 3, 1, "op-btn", () => set_op("*"));
            add_key(basic_keypad, "4", 0, 2, "num-btn", () => append_digit("4"));
            add_key(basic_keypad, "5", 1, 2, "num-btn", () => append_digit("5"));
            add_key(basic_keypad, "6", 2, 2, "num-btn", () => append_digit("6"));
            add_key(basic_keypad, "−", 3, 2, "op-btn", () => set_op("-"));
            add_key(basic_keypad, "1", 0, 3, "num-btn", () => append_digit("1"));
            add_key(basic_keypad, "2", 1, 3, "num-btn", () => append_digit("2"));
            add_key(basic_keypad, "3", 2, 3, "num-btn", () => append_digit("3"));
            add_key(basic_keypad, "+", 3, 3, "op-btn", () => set_op("+"));
            add_key(basic_keypad, "0", 0, 4, "num-btn", () => append_digit("0"));
            add_key(basic_keypad, ".", 1, 4, "num-btn", () => append_dot());
            add_key(basic_keypad, "π", 2, 4, "func-btn", () => append_pi());
            add_key(basic_keypad, "=", 3, 4, "accent-btn", () => calculate());
        }

        private void populate_advanced_keypad() {
            add_key(advanced_keypad, "sin", 0, 0, "func-btn", () => func_op("sin"));
            add_key(advanced_keypad, "cos", 1, 0, "func-btn", () => func_op("cos"));
            add_key(advanced_keypad, "tan", 2, 0, "func-btn", () => func_op("tan"));
            add_key(advanced_keypad, "log", 3, 0, "func-btn", () => func_op("log"));
            var deg_btn = new Button();
            deg_btn.add_css_class("calc-btn");
            deg_btn.add_css_class("func-btn");
            deg_rad_label = new Label("Deg");
            deg_btn.set_child(deg_rad_label);
            deg_btn.clicked.connect(() => {
                use_degrees = !use_degrees;
                deg_rad_label.label = use_degrees ? "Deg" : "Rad";
            });
            advanced_keypad.attach(deg_btn, 4, 0, 1, 1);
            add_key(advanced_keypad, "(", 0, 1, "func-btn", () => open_paren());
            add_key(advanced_keypad, ")", 1, 1, "func-btn", () => close_paren());
            add_key(advanced_keypad, "^", 2, 1, "func-btn", () => set_op("^"));
            add_key(advanced_keypad, "√", 3, 1, "func-btn", () => func_op("sqrt"));
            add_key(advanced_keypad, "!", 4, 1, "func-btn", () => func_op("fact"));
            add_key(advanced_keypad, "7", 0, 2, "num-btn", () => append_digit("7"));
            add_key(advanced_keypad, "8", 1, 2, "num-btn", () => append_digit("8"));
            add_key(advanced_keypad, "9", 2, 2, "num-btn", () => append_digit("9"));
            add_key(advanced_keypad, "÷", 3, 2, "op-btn", () => set_op("/"));
            add_key(advanced_keypad, "C", 4, 2, "func-btn", () => clear_all());
            add_key(advanced_keypad, "4", 0, 3, "num-btn", () => append_digit("4"));
            add_key(advanced_keypad, "5", 1, 3, "num-btn", () => append_digit("5"));
            add_key(advanced_keypad, "6", 2, 3, "num-btn", () => append_digit("6"));
            add_key(advanced_keypad, "×", 3, 3, "op-btn", () => set_op("*"));
            add_key(advanced_keypad, "AC", 4, 3, "func-btn", () => clear_all());
            add_key(advanced_keypad, "1", 0, 4, "num-btn", () => append_digit("1"));
            add_key(advanced_keypad, "2", 1, 4, "num-btn", () => append_digit("2"));
            add_key(advanced_keypad, "3", 2, 4, "num-btn", () => append_digit("3"));
            add_key(advanced_keypad, "−", 3, 4, "op-btn", () => set_op("-"));
            add_key(advanced_keypad, "±", 4, 4, "func-btn", () => negate());
            add_key(advanced_keypad, "0", 0, 5, "num-btn", () => append_digit("0"));
            add_key(advanced_keypad, ".", 1, 5, "num-btn", () => append_dot());
            add_key(advanced_keypad, "π", 2, 5, "func-btn", () => append_pi());
            add_key(advanced_keypad, "+", 3, 5, "op-btn", () => set_op("+"));
            add_key(advanced_keypad, "=", 4, 5, "accent-btn", () => calculate());
        }

        private delegate void ClickedCallback();

        private void add_key(Grid grid, string lbl, int col, int row,
                             string css_class, ClickedCallback? callback) {
            var btn = new Button.with_label(lbl);
            btn.add_css_class("calc-btn");
            btn.add_css_class(css_class);
            btn.accessible_role = AccessibleRole.BUTTON;
            string desc = lbl;
            if (lbl == "C") desc = "Clear";
            if (lbl == "AC") desc = "All Clear";
            if (lbl == "±") desc = "Negate";
            if (lbl == "÷") desc = "Divide";
            if (lbl == "×") desc = "Multiply";
            if (lbl == "−") desc = "Subtract";
            if (lbl == "+") desc = "Add";
            if (lbl == "=") desc = "Equals";
            if (lbl == ".") desc = "Decimal point";
            btn.update_property(Gtk.AccessibleProperty.LABEL, desc);
            if (callback != null) {
                btn.clicked.connect(() => callback());
            }
            grid.attach(btn, col, row);
        }

        private void append_digit(string digit) {
            if (new_input) {
                current_input = digit;
                new_input = false;
            } else {
                current_input = current_input == "0" ? digit : current_input + digit;
            }
            update_display();
        }

        private void append_dot() {
            if (new_input) {
                current_input = "0.";
                new_input = false;
            } else if (!current_input.contains(".")) {
                current_input += ".";
            }
            update_display();
        }

        private void append_pi() {
            current_input = Math.PI.to_string();
            new_input = true;
            update_display();
        }

        private void clear_all() {
            current_input = "0";
            previous_input = "";
            operation = "";
            new_input = true;
            paren_prev_stack = new GLib.List<string>();
            paren_op_stack   = new GLib.List<string>();
            history_label.label = "";
            update_display();
        }

        private void open_paren() {
            if (operation != "" && !new_input) calculate();
            paren_prev_stack.append(previous_input);
            paren_op_stack.append(operation);
            previous_input = "";
            operation = "";
            current_input = "0";
            new_input = true;
            update_display();
        }

        private void close_paren() {
            if (paren_prev_stack.length() == 0) return;
            if (operation != "" && !new_input) calculate();
            string paren_result = current_input;
            previous_input = paren_prev_stack.last().data;
            operation = paren_op_stack.last().data;
            paren_prev_stack.delete_link(paren_prev_stack.last());
            paren_op_stack.delete_link(paren_op_stack.last());
            current_input = paren_result;
            new_input = false;
            update_display();
        }

        private void negate() {
            if (current_input == "0") return;
            current_input = current_input.has_prefix("-")
                ? current_input.substring(1)
                : "-" + current_input;
            update_display();
        }

        private void percent() {
            double val = double.parse(current_input);
            current_input = format_double(val / 100.0);
            new_input = true;
            update_display();
        }

        private double to_rad(double val) {
            return use_degrees ? val * Math.PI / 180.0 : val;
        }

        private void func_op(string func) {
            double val = double.parse(current_input);
            double res = 0;
            if (func == "sin")       res = Math.sin(to_rad(val));
            else if (func == "cos")  res = Math.cos(to_rad(val));
            else if (func == "tan")  res = Math.tan(to_rad(val));
            else if (func == "log")  res = Math.log10(val);
            else if (func == "ln")   res = Math.log(val);
            else if (func == "sqrt") res = Math.sqrt(val);
            else if (func == "fact") {
                if (val >= 0 && val <= 170 && val == Math.floor(val)) {
                    res = 1;
                    for (int i = 1; i <= (int)val; i++) res *= i;
                } else {
                    res = double.NAN;
                }
            }
            current_input = format_double(res);
            new_input = true;
            update_display();
        }

        private void set_op(string op) {
            if (operation != "" && !new_input) calculate();
            previous_input = current_input;
            operation = op;
            new_input = true;
            string sym = op;
            if (op == "*") sym = "×";
            if (op == "/") sym = "÷";
            if (op == "-") sym = "−";
            history_label.label = previous_input + " " + sym;
        }

        private void calculate() {
            if (operation == "") return;
            double v1 = double.parse(previous_input);
            double v2 = double.parse(current_input);
            double res = 0;
            switch (operation) {
                case "+": res = v1 + v2; break;
                case "-": res = v1 - v2; break;
                case "*": res = v1 * v2; break;
                case "/": res = v1 / v2; break;
                case "^": res = Math.pow(v1, v2); break;
            }
            current_input = format_double(res);
            history_label.label = "";
            operation = "";
            new_input = true;
            update_display();
        }

        private string format_double(double val) {
            if (val.is_nan()) return "Error";
            if (val.is_infinity() != 0) return val > 0 ? "∞" : "-∞";
            string s = "%.12g".printf(val);
            if ("." in s && !("e" in s)) {
                while (s.has_suffix("0")) s = s.substring(0, s.length - 1);
                if (s.has_suffix(".")) s = s.substring(0, s.length - 1);
            }
            return s;
        }

        private void update_display() {
            display_label.label = current_input;
        }
    }

    public class CalculatorApp : Singularity.Application {

        public CalculatorApp() {
            Object(application_id: "dev.sinty.calculator",
                   flags: ApplicationFlags.FLAGS_NONE);
        }

        private CalculatorWindow window;

        protected override void startup() {
            base.startup();
            setup_styles();
            var menu = new GLib.Menu();
            var file_menu = new GLib.Menu();
            file_menu.append("Quit", "app.quit");
            menu.append_submenu("File", file_menu);
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
            window.present();
        }

        public static int main(string[] args) {
            var app = new CalculatorApp();
            return app.run(args);
        }

        private void setup_styles() {
            var provider = new Gtk.CssProvider();
            provider.load_from_data(CALC_CSS.data);
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        private const string CALC_CSS = """
.calculator-app {
    background-color: @surface_raised;
}

.calculator-display {
    background-color: @surface_raised;
    padding: 24px;
    padding-top: 60px;
}

.history-text {
    font-size: 16px;
    color: alpha(@text_color, 0.5);
}

.display-text {
    font-size: 48px;
    font-weight: 300;
    color: @text_color;
}

.input-row {
    padding: 0 24px;
    margin-bottom: 12px;
}

.cursor {
    color: @link_color;
    font-size: 24px;
    animation: blink 1s infinite;
}

@keyframes blink {
    0% {
        opacity: 1;
    }

    50% {
        opacity: 0;
    }

    100% {
        opacity: 1;
    }
}

.backspace-btn {
    color: @text_color;
    min-height: 32px;
    min-width: 32px;
    border-radius: 50%;
}

.calculator-keypad {
    background-color: @surface_dim;
    padding: 16px;
    border-top-left-radius: 16px;
    border-top-right-radius: 16px;
}

.calc-btn {
    border-radius: 12px;
    font-size: 20px;
    font-weight: 500;
    min-height: 54px;
    border: none;
    box-shadow: none;
    padding: 0;
}

.num-btn {
    background-color: @surface_bright;
    color: @text_color;
}

.num-btn:hover {
    background-color: @surface_bright;
}

.num-btn:active {
    background-color: @surface_alt;
}

.op-btn {
    background-color: @surface_alt;
    color: @text_color;
}

.op-btn:hover {
    background-color: @surface_bright;
}

.func-btn {
    background-color: @surface_alt;
    color: @text_color;
}

.func-btn:hover {
    background-color: @surface_bright;
}

.accent-btn {
    background-color: @accent_color;
    color: @accent_fg;
    font-size: 28px;
}

.accent-btn:hover {
    background-color: mix(@accent_color, white, 0.15);
}

.accent-btn:active {
    background-color: mix(@accent_color, black, 0.15);
}
""";
    }
}
