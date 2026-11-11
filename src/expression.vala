namespace Singularity.Apps {

    public errordomain ExpressionError {
        SYNTAX,
        MATH
    }

    public class ExpressionEvaluator : GLib.Object {

        private struct Frame {
            bool negate;
            bool has_function;
            CalculatorEngine.Function function;
        }

        public static string status_name(CalculatorEngine.Status status) {
            switch (status) {
                case CalculatorEngine.Status.DIVIDE_BY_ZERO: return "division by zero";
                case CalculatorEngine.Status.DOMAIN_ERROR: return "outside the domain of the function";
                case CalculatorEngine.Status.FACTORIAL_RANGE: return "factorial needs a whole number from 0 to 170";
                case CalculatorEngine.Status.OVERFLOW: return "the result is too large";
                case CalculatorEngine.Status.UNDEFINED: return "the result is undefined";
                default: return "";
            }
        }

        private static bool function_named(string name, out CalculatorEngine.Function f) {
            switch (name) {
                case "sin": f = CalculatorEngine.Function.SIN; return true;
                case "cos": f = CalculatorEngine.Function.COS; return true;
                case "tan": f = CalculatorEngine.Function.TAN; return true;
                case "log": f = CalculatorEngine.Function.LOG10; return true;
                case "ln": f = CalculatorEngine.Function.LN; return true;
                case "sqrt": f = CalculatorEngine.Function.SQRT; return true;
                default: f = CalculatorEngine.Function.SIN; return false;
            }
        }

        private static CalculatorEngine.Operation operation_for(unichar c) {
            switch (c) {
                case '+': return CalculatorEngine.Operation.ADD;
                case '-': case 0x2212: return CalculatorEngine.Operation.SUBTRACT;
                case '*': case 0xd7: case 'x': return CalculatorEngine.Operation.MULTIPLY;
                case '/': case 0xf7: case ':': return CalculatorEngine.Operation.DIVIDE;
                case '^': return CalculatorEngine.Operation.POWER;
                default: return CalculatorEngine.Operation.NONE;
            }
        }

        public static double evaluate(string expression, CalculatorEngine.AngleUnit unit, out string line) throws ExpressionError {
            var engine = new CalculatorEngine();
            engine.angle_unit = unit;
            Frame[] frames = {};
            bool operand = false;
            bool negate_next = false;
            bool any = false;
            string text = expression.strip().replace("**", "^").replace("\xcf\x80", "pi").replace("\xe2\x88\x9a", "sqrt");
            int i = 0;
            while (i < text.length) {
                unichar c = text.get_char(i);
                int next = i + c.to_string().length;
                if (c.isspace() || c == '_') {
                    i = next;
                    continue;
                }
                if (c.isdigit() || c == '.' || c == ',') {
                    if (operand) throw new ExpressionError.SYNTAX("a number follows a value at %d", i);
                    int j = i;
                    while (j < text.length && (text[j].isdigit() || text[j] == '.' || text[j] == ',')) j++;
                    if (j < text.length && (text[j] == 'e' || text[j] == 'E') && j + 1 < text.length
                        && (text[j + 1].isdigit() || ((text[j + 1] == '-' || text[j + 1] == '+') && j + 2 < text.length && text[j + 2].isdigit()))) {
                        j += 2;
                        while (j < text.length && text[j].isdigit()) j++;
                    }
                    string literal = text.substring(i, j - i).replace(",", ".");
                    double v;
                    if (!double.try_parse(literal, out v)) throw new ExpressionError.SYNTAX("%s is not a number", literal);
                    int k = j;
                    while (k < text.length && text[k].isspace()) k++;
                    if (negate_next && k < text.length && text[k] == '^') {
                        engine.set_value(-1);
                        engine.set_operation(CalculatorEngine.Operation.MULTIPLY);
                        engine.set_value(v);
                    } else {
                        engine.set_value(negate_next ? -v : v);
                    }
                    negate_next = false;
                    operand = true;
                    any = true;
                    i = j;
                    continue;
                }
                if (c.isalpha() && !(operand && c == 'x')) {
                    int j = i;
                    while (j < text.length && text[j].isalpha()) j++;
                    string word = text.substring(i, j - i).down();
                    if (word == "pi" || word == "e") {
                        if (operand) engine.set_operation(CalculatorEngine.Operation.MULTIPLY);
                        engine.set_value(negate_next ? -(word == "pi" ? Math.PI : Math.E) : (word == "pi" ? Math.PI : Math.E));
                        negate_next = false;
                        operand = true;
                        any = true;
                        i = j;
                        continue;
                    }
                    CalculatorEngine.Function f;
                    if (!function_named(word, out f)) throw new ExpressionError.SYNTAX("unknown name %s", word);
                    while (j < text.length && text[j].isspace()) j++;
                    if (j >= text.length || text[j] != '(') throw new ExpressionError.SYNTAX("%s needs parentheses", word);
                    if (operand) engine.set_operation(CalculatorEngine.Operation.MULTIPLY);
                    engine.open_paren();
                    frames += Frame() { negate = negate_next, has_function = true, function = f };
                    negate_next = false;
                    operand = false;
                    i = j + 1;
                    continue;
                }
                if (c == '(') {
                    engine.open_paren();
                    frames += Frame() { negate = negate_next, has_function = false };
                    negate_next = false;
                    operand = false;
                    i = next;
                    continue;
                }
                if (c == ')') {
                    if (frames.length == 0) throw new ExpressionError.SYNTAX("a ) has no matching (");
                    if (!operand) throw new ExpressionError.SYNTAX("empty parentheses");
                    engine.close_paren();
                    var frame = frames[frames.length - 1];
                    frames.resize(frames.length - 1);
                    if (frame.has_function) engine.apply_function(frame.function);
                    if (frame.negate) engine.set_value(-engine.current_value);
                    operand = true;
                    i = next;
                    continue;
                }
                if (c == '!') {
                    if (!operand) throw new ExpressionError.SYNTAX("! needs a value before it");
                    engine.apply_function(CalculatorEngine.Function.FACTORIAL);
                    i = next;
                    continue;
                }
                if (c == '%') {
                    if (!operand) throw new ExpressionError.SYNTAX("%% needs a value before it");
                    engine.percent();
                    i = next;
                    continue;
                }
                var op = operation_for(c);
                if (op != CalculatorEngine.Operation.NONE) {
                    if (!operand) {
                        if (op == CalculatorEngine.Operation.SUBTRACT) {
                            negate_next = !negate_next;
                            i = next;
                            continue;
                        }
                        if (op == CalculatorEngine.Operation.ADD) {
                            i = next;
                            continue;
                        }
                        throw new ExpressionError.SYNTAX("%s needs a value before it", c.to_string());
                    }
                    engine.set_operation(op);
                    operand = false;
                    i = next;
                    continue;
                }
                throw new ExpressionError.SYNTAX("unexpected %s", c.to_string());
            }
            if (!any) throw new ExpressionError.SYNTAX("the expression is empty");
            if (!operand) throw new ExpressionError.SYNTAX("the expression ends without a value");
            while (frames.length > 0) {
                engine.close_paren();
                var frame = frames[frames.length - 1];
                frames.resize(frames.length - 1);
                if (frame.has_function) engine.apply_function(frame.function);
                if (frame.negate) engine.set_value(-engine.current_value);
            }
            engine.equals();
            if (engine.has_error) throw new ExpressionError.MATH(status_name(engine.status));
            line = expression.strip() + " = " + engine.display;
            return engine.current_value;
        }
    }
}
