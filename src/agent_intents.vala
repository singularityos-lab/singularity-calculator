namespace Singularity.Apps {

    internal class CalculatorIntents : Object {

        private static string text(Json.Object args, string key) {
            return args.has_member(key) ? args.get_string_member(key).strip() : "";
        }

        private static CalculatorEngine.AngleUnit unit_of(Json.Object args) {
            return text(args, "angle") == "radians" ? CalculatorEngine.AngleUnit.RADIANS : CalculatorEngine.AngleUnit.DEGREES;
        }

        private static CalculatorWindow? window_of(CalculatorApp app) {
            foreach (var w in app.get_windows()) {
                if (w is CalculatorWindow) return (CalculatorWindow) w;
            }
            return null;
        }

        internal static void install(CalculatorApp app) {
            var agent = app.agent;
            agent.add_intent("calculator_evaluate",
                "Compute an arithmetic expression exactly as Calculator does: + - * / ^, parentheses, %, !, sin cos tan (degrees unless angle is radians), log, ln, sqrt, pi and e.",
                "{\"type\":\"object\",\"properties\":{\"expression\":{\"type\":\"string\"},\"angle\":{\"type\":\"string\",\"enum\":[\"degrees\",\"radians\"]}},\"required\":[\"expression\"]}",
                Singularity.AppIntentRisk.READ, (args) => {
                    string expression = text(args, "expression");
                    string line;
                    double v = ExpressionEvaluator.evaluate(expression, unit_of(args), out line);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("expression").add_string_value(expression);
                    b.set_member_name("result").add_string_value(CalculatorEngine.format(v));
                    b.set_member_name("value").add_double_value(v);
                    b.end_object();
                    return b.get_root();
                });
            agent.add_intent("calculator_convert",
                "Convert a quantity between units of length, mass, temperature, volume, area, speed, time, data, energy or pressure.",
                "{\"type\":\"object\",\"properties\":{\"value\":{\"type\":\"number\"},\"from\":{\"type\":\"string\"},\"to\":{\"type\":\"string\"}},\"required\":[\"value\",\"from\",\"to\"]}",
                Singularity.AppIntentRisk.READ, (args) => {
                    double value = args.has_member("value") ? args.get_double_member("value") : 0;
                    string from = text(args, "from");
                    string to = text(args, "to");
                    var conv = new UnitConverter();
                    string query = "%s %s to %s".printf(CalculatorEngine.format(value), from, to);
                    if (!conv.parse(query)) throw new IOError.INVALID_ARGUMENT("cannot convert %s to %s", from, to);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("value").add_double_value(conv.value);
                    b.set_member_name("from").add_string_value(conv.from_symbol);
                    b.set_member_name("result").add_double_value(conv.result);
                    b.set_member_name("to").add_string_value(conv.to_symbol);
                    b.set_member_name("text").add_string_value("%s %s = %s %s".printf(UnitConverter.format_number(conv.value), conv.from_symbol,
                        UnitConverter.format_number(conv.result), conv.to_symbol));
                    b.end_object();
                    return b.get_root();
                });
            agent.add_intent("calculator_history",
                "The calculations done in the open Calculator window, oldest first, and what its display shows.",
                "{\"type\":\"object\",\"properties\":{}}",
                Singularity.AppIntentRisk.READ, (args) => {
                    var window = window_of(app);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("open").add_boolean_value(window != null);
                    b.set_member_name("lines").begin_array();
                    if (window != null) foreach (string line in window.engine.get_log()) b.add_string_value(line);
                    b.end_array();
                    if (window != null) {
                        b.set_member_name("display").add_string_value(window.engine.has_error ? ExpressionEvaluator.status_name(window.engine.status) : window.engine.display);
                        b.set_member_name("memory").add_double_value(window.engine.memory);
                    }
                    b.end_object();
                    return b.get_root();
                });
            agent.add_intent("calculator_show",
                "Compute an expression and put the result on the Calculator display, opening the window if needed.",
                "{\"type\":\"object\",\"properties\":{\"expression\":{\"type\":\"string\"},\"angle\":{\"type\":\"string\",\"enum\":[\"degrees\",\"radians\"]}},\"required\":[\"expression\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    string line;
                    double v = ExpressionEvaluator.evaluate(text(args, "expression"), unit_of(args), out line);
                    app.activate();
                    var window = window_of(app);
                    if (window == null) throw new IOError.FAILED("the Calculator window did not open");
                    window.engine.clear();
                    window.engine.set_value(v);
                    var b = new Json.Builder();
                    b.begin_object();
                    b.set_member_name("display").add_string_value(window.engine.display);
                    b.set_member_name("verified").add_boolean_value(window.engine.display == CalculatorEngine.format(v));
                    b.end_object();
                    return b.get_root();
                });
        }
    }
}
