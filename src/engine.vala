namespace Singularity.Apps {

    /**
     * Headless calculator logic: digit entry, an operator stack with real
     * precedence, parentheses, unary functions and a memory register.
     *
     * The engine deliberately depends on nothing but GObject and libm so it
     * can be exercised by a standalone test binary. In particular it never
     * calls gettext: error states are exposed as a typed {@link Status} and
     * the view is responsible for turning them into translated text.
     *
     * Every number that leaves the engine goes through {@link format}, which
     * uses g_ascii_formatd rather than printf so the decimal separator stays
     * a dot regardless of LC_NUMERIC. double.parse (g_ascii_strtod) reads it
     * back symmetrically.
     */
    public class CalculatorEngine : GLib.Object {

        public enum Status {
            OK,
            DIVIDE_BY_ZERO,
            DOMAIN_ERROR,
            FACTORIAL_RANGE,
            OVERFLOW,
            UNDEFINED
        }

        public enum Operation {
            NONE, ADD, SUBTRACT, MULTIPLY, DIVIDE, POWER
        }

        public enum Function {
            SIN, COS, TAN, LOG10, LN, SQRT, FACTORIAL, SQUARE, RECIPROCAL
        }

        public enum AngleUnit {
            DEGREES, RADIANS
        }

        private struct PendingOp {
            double value;
            Operation op;
        }

        /** Digits accepted in a single entry, so the display cannot overflow. */
        private const int MAX_DIGITS = 15;

        /** Significant digits kept when rendering a result. */
        private const string RESULT_FORMAT = "%.12g";

        /** Results closer to zero than this are snapped to zero after trig. */
        private const double TRIG_EPSILON = 1e-12;

        /** Largest n for which n! is representable as a double. */
        private const double MAX_FACTORIAL = 170;

        /** The entry buffer. Always ASCII and always double.parse-able. */
        public string display { get; private set; default = "0"; }

        /** Pending expression, e.g. "(2 x 3 + ". Symbols only, never translated. */
        public string history { get; private set; default = ""; }

        public Status status { get; private set; default = Status.OK; }

        public AngleUnit angle_unit { get; set; default = AngleUnit.DEGREES; }

        public double memory { get; private set; default = 0; }

        public bool has_error { get { return status != Status.OK; } }

        public bool has_memory { get { return memory != 0; } }

        public double current_value { get { return double.parse(display); } }

        public uint paren_depth { get { return paren_marks.length; } }

        public bool has_pending_operation { get { return ops.length > 0; } }

        private PendingOp[] ops = {};
        private int[] paren_marks = {};
        private string[] log = {};

        /** The next digit starts a new number rather than extending `display`. */
        private bool new_entry = true;

        /** An operator was just pressed and its right operand is still missing. */
        private bool awaiting_operand = false;

        /** `display` holds a number the user typed or the engine computed. */
        private bool operand_ready = false;

        // ------------------------------------------------------------------
        // Entry
        // ------------------------------------------------------------------

        public void append_digit(string digit) {
            if (has_error) return;
            if (new_entry) {
                display = "0";
                new_entry = false;
                awaiting_operand = false;
            }
            if (digit_count(display) >= MAX_DIGITS) return;

            if (display == "0")       display = digit;
            else if (display == "-0") display = "-" + digit;
            else                      display = display + digit;
            operand_ready = true;
        }

        public void append_dot() {
            if (has_error) return;
            if (new_entry) {
                display = "0.";
                new_entry = false;
                awaiting_operand = false;
            } else if (!("." in display)) {
                display = display + ".";
            }
            operand_ready = true;
        }

        public void append_pi() {
            if (has_error) return;
            commit(Math.PI);
        }

        public void append_e() {
            if (has_error) return;
            commit(Math.E);
        }

        public void backspace() {
            if (has_error || new_entry) return;

            string s = display.substring(0, display.length - 1);
            if (s == "" || s == "-") {
                s = "0";
                new_entry = true;
                operand_ready = false;
            }
            display = s;
        }

        public void negate() {
            if (has_error) return;

            // Right after an operator the entry buffer still shows the *left*
            // operand, which is already on the stack. Start a signed new
            // number instead of lying about what will be computed.
            if (awaiting_operand) {
                display = "-0";
                new_entry = false;
                awaiting_operand = false;
                operand_ready = true;
                return;
            }
            if (new_entry) {
                if (current_value == 0) return;
                display = format(-current_value);
                return;
            }
            if (display == "0") {
                display = "-0";
                return;
            }
            display = display.has_prefix("-")
                ? display.substring(1)
                : "-" + display;
        }

        public void clear() {
            display = "0";
            history = "";
            status = Status.OK;
            ops = {};
            paren_marks = {};
            new_entry = true;
            awaiting_operand = false;
            operand_ready = false;
            notify_property("has-error");
            notify_property("paren-depth");
            notify_property("has-pending-operation");
        }

        // ------------------------------------------------------------------
        // Arithmetic
        // ------------------------------------------------------------------

        public void percent() {
            if (has_error) return;

            double v = current_value;
            // "200 + 10 %" means 10% *of 200*; for x and / it is a plain /100.
            if (ops.length > 0) {
                Operation top = ops[ops.length - 1].op;
                if (top == Operation.ADD || top == Operation.SUBTRACT) {
                    commit(ops[ops.length - 1].value * v / 100.0);
                    return;
                }
            }
            commit(v / 100.0);
        }

        public void set_operation(Operation op) {
            if (has_error || op == Operation.NONE) return;

            // Pressing a second operator replaces the pending one.
            if (awaiting_operand && ops.length > 0) {
                ops[ops.length - 1].op = op;
                history = build_expression();
                return;
            }

            // `^` is right-associative, so an equal-precedence operator on the
            // stack must *not* be folded: 2^3^2 is 2^(3^2).
            int min_prec = op == Operation.POWER
                ? precedence(op) + 1
                : precedence(op);
            reduce_to(current_barrier(), min_prec);
            if (has_error) return;

            ops += PendingOp() { value = current_value, op = op };
            new_entry = true;
            awaiting_operand = true;
            operand_ready = false;
            history = build_expression();
            notify_property("has-pending-operation");
        }

        public void equals() {
            if (has_error || ops.length == 0) return;

            string expression = build_expression() + display;
            paren_marks = {};
            reduce_to(0, 1);
            if (has_error) return;

            history = expression + " =";
            log += expression + " = " + display;
            new_entry = true;
            awaiting_operand = false;
            operand_ready = true;
            notify_property("has-pending-operation");
            notify_property("paren-depth");
        }

        public void apply_function(Function func) {
            if (has_error) return;

            double v = current_value;
            double res = 0;

            switch (func) {
                case Function.SIN:
                    res = snap(Math.sin(to_radians(v)));
                    break;
                case Function.COS:
                    res = snap(Math.cos(to_radians(v)));
                    break;
                case Function.TAN:
                    // tan(90 deg) is 1.6e16 in IEEE, not an infinity, so the
                    // asymptote has to be recognised before computing.
                    if (angle_unit == AngleUnit.DEGREES
                        && Math.fmod(v.abs(), 180.0) == 90.0) {
                        fail(Status.UNDEFINED);
                        return;
                    }
                    res = snap(Math.tan(to_radians(v)));
                    break;
                case Function.LOG10:
                    if (v <= 0) { fail(Status.DOMAIN_ERROR); return; }
                    res = Math.log10(v);
                    break;
                case Function.LN:
                    if (v <= 0) { fail(Status.DOMAIN_ERROR); return; }
                    res = Math.log(v);
                    break;
                case Function.SQRT:
                    if (v < 0) { fail(Status.DOMAIN_ERROR); return; }
                    res = Math.sqrt(v);
                    break;
                case Function.SQUARE:
                    res = v * v;
                    break;
                case Function.RECIPROCAL:
                    if (v == 0) { fail(Status.DIVIDE_BY_ZERO); return; }
                    res = 1.0 / v;
                    break;
                case Function.FACTORIAL:
                    if (v < 0 || v > MAX_FACTORIAL || v != Math.floor(v)) {
                        fail(Status.FACTORIAL_RANGE);
                        return;
                    }
                    res = 1;
                    for (int i = 2; i <= (int) v; i++) res *= i;
                    break;
            }
            commit(res);
        }

        // ------------------------------------------------------------------
        // Parentheses
        // ------------------------------------------------------------------

        public void open_paren() {
            if (has_error) return;

            // "5 (" reads as an implicit multiplication rather than silently
            // discarding the 5.
            if (operand_ready) {
                set_operation(Operation.MULTIPLY);
                if (has_error) return;
            }
            paren_marks += ops.length;
            display = "0";
            new_entry = true;
            awaiting_operand = false;
            operand_ready = false;
            history = build_expression();
            notify_property("paren-depth");
        }

        public void close_paren() {
            if (has_error || paren_marks.length == 0) return;

            reduce_to(paren_marks[paren_marks.length - 1], 1);
            if (has_error) return;

            paren_marks.resize(paren_marks.length - 1);
            new_entry = true;
            awaiting_operand = false;
            operand_ready = true;
            history = build_expression();
            notify_property("paren-depth");
            notify_property("has-pending-operation");
        }

        // ------------------------------------------------------------------
        // Memory
        // ------------------------------------------------------------------

        public void memory_add() {
            if (has_error) return;
            memory = memory + current_value;
            notify_property("has-memory");
        }

        public void memory_subtract() {
            if (has_error) return;
            memory = memory - current_value;
            notify_property("has-memory");
        }

        public void memory_recall() {
            if (has_error) return;
            commit(memory);
        }

        /** Replace the entry buffer with a value (clipboard paste, log replay). */
        public void set_value(double v) {
            if (has_error) return;
            commit(v);
        }

        public void memory_clear() {
            memory = 0;
            notify_property("has-memory");
        }

        // ------------------------------------------------------------------
        // Calculation log
        // ------------------------------------------------------------------

        /** Past "expression = result" lines, oldest first. */
        public string[] get_log() {
            return log;
        }

        public void clear_log() {
            log = {};
        }

        // ------------------------------------------------------------------
        // Internals
        // ------------------------------------------------------------------

        private int current_barrier() {
            return paren_marks.length > 0
                ? paren_marks[paren_marks.length - 1]
                : 0;
        }

        /** Fold the operator stack down to `barrier` while precedence allows. */
        private void reduce_to(int barrier, int min_prec) {
            while (ops.length > barrier
                   && precedence(ops[ops.length - 1].op) >= min_prec) {
                PendingOp top = ops[ops.length - 1];
                ops.resize(ops.length - 1);

                double res = apply(top.value, top.op, current_value);
                if (has_error) return;
                commit(res);
            }
        }

        private double apply(double a, Operation op, double b) {
            switch (op) {
                case Operation.ADD:      return a + b;
                case Operation.SUBTRACT: return a - b;
                case Operation.MULTIPLY: return a * b;
                case Operation.DIVIDE:
                    if (b == 0) {
                        fail(a == 0 ? Status.UNDEFINED : Status.DIVIDE_BY_ZERO);
                        return 0;
                    }
                    return a / b;
                case Operation.POWER:
                    double r = Math.pow(a, b);
                    if (r.is_nan()) { fail(Status.DOMAIN_ERROR); return 0; }
                    return r;
                default:
                    return b;
            }
        }

        /** Single funnel for every computed value. */
        private void commit(double v) {
            if (v.is_nan())            { fail(Status.UNDEFINED); return; }
            if (v.is_infinity() != 0)  { fail(Status.OVERFLOW);  return; }

            display = format(v);
            new_entry = true;
            awaiting_operand = false;
            operand_ready = true;
        }

        /**
         * Errors are sticky: every public entry point bails out while one is
         * set, so a division by zero can never be silently parsed back to 0.
         * Only clear() recovers.
         */
        private void fail(Status s) {
            display = "0";
            history = "";
            ops = {};
            paren_marks = {};
            new_entry = true;
            awaiting_operand = false;
            operand_ready = false;
            status = s;
            notify_property("has-error");
            notify_property("paren-depth");
            notify_property("has-pending-operation");
        }

        private double to_radians(double v) {
            return angle_unit == AngleUnit.DEGREES ? v * Math.PI / 180.0 : v;
        }

        private static double snap(double v) {
            return v.abs() < TRIG_EPSILON ? 0.0 : v;
        }

        private static int precedence(Operation op) {
            switch (op) {
                case Operation.ADD:
                case Operation.SUBTRACT: return 1;
                case Operation.MULTIPLY:
                case Operation.DIVIDE:   return 2;
                case Operation.POWER:    return 3;
                default:                 return 0;
            }
        }

        public static string symbol(Operation op) {
            switch (op) {
                case Operation.ADD:      return "+";
                case Operation.SUBTRACT: return "\xe2\x88\x92";
                case Operation.MULTIPLY: return "\xc3\x97";
                case Operation.DIVIDE:   return "\xc3\xb7";
                case Operation.POWER:    return "^";
                default:                 return "";
            }
        }

        private static int digit_count(string s) {
            int n = 0;
            for (int i = 0; i < s.length; i++) {
                if (s[i] >= '0' && s[i] <= '9') n++;
            }
            return n;
        }

        /**
         * Locale-independent rendering. printf("%g") honours LC_NUMERIC and
         * would emit "3,14" in fr_FR, which double.parse (g_ascii_strtod)
         * then truncates to 3. g_ascii_formatd always writes a dot.
         */
        public static string format(double v) {
            string s = v.format(new char[double.DTOSTR_BUF_SIZE], RESULT_FORMAT);
            if ("." in s && !("e" in s) && !("E" in s)) {
                while (s.has_suffix("0")) s = s.substring(0, s.length - 1);
                if (s.has_suffix(".")) s = s.substring(0, s.length - 1);
            }
            return s == "-0" ? "0" : s;
        }

        private string build_expression() {
            var sb = new StringBuilder();
            int mark = 0;
            for (int i = 0; i <= ops.length; i++) {
                while (mark < paren_marks.length && paren_marks[mark] == i) {
                    sb.append("(");
                    mark++;
                }
                if (i < ops.length) {
                    sb.append(format(ops[i].value));
                    sb.append(" ");
                    sb.append(symbol(ops[i].op));
                    sb.append(" ");
                }
            }
            return sb.str;
        }
    }
}
