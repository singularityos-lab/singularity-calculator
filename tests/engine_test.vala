using GLib;
using Singularity.Apps;

private CalculatorEngine engine() {
    return new CalculatorEngine();
}

/** Type a literal number, digit by digit, through the public entry API. */
private void feed(CalculatorEngine e, string number) {
    for (int i = 0; i < number.length; i++) {
        string c = number.substring(i, 1);
        if (c == ".") e.append_dot();
        else if (c == "-") e.negate();
        else e.append_digit(c);
    }
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

private void test_entry_replaces_leading_zero() {
    var e = engine();
    assert(e.display == "0");
    e.append_digit("7");
    assert(e.display == "7");
    e.append_digit("0");
    assert(e.display == "70");
}

private void test_entry_appends_digits() {
    var e = engine();
    feed(e, "123");
    assert(e.display == "123");
    assert(e.current_value == 123);
}

private void test_entry_after_result_starts_a_new_number() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "3");
    e.equals();
    assert(e.display == "5");
    e.append_digit("7");
    assert(e.display == "7");
}

private void test_entry_after_operator_starts_a_new_number() {
    var e = engine();
    feed(e, "42");
    e.set_operation(CalculatorEngine.Operation.ADD);
    assert(e.display == "42");
    e.append_digit("9");
    assert(e.display == "9");
}

private void test_entry_is_length_capped() {
    var e = engine();
    feed(e, "12345678901234567890");
    assert(e.display == "123456789012345");
}

private void test_decimal_point() {
    var e = engine();
    e.append_dot();
    assert(e.display == "0.");
    e.append_dot();
    assert(e.display == "0.");
    feed(e, "5");
    assert(e.display == "0.5");

    var f = engine();
    feed(f, "1.5");
    assert(f.display == "1.5");
    assert(f.current_value == 1.5);
}

private void test_constants() {
    var e = engine();
    e.append_pi();
    assert(e.display == "3.14159265359");
    e.append_digit("4");
    assert(e.display == "4");

    var f = engine();
    f.append_e();
    assert(f.display == "2.71828182846");
}

private void test_negate() {
    var e = engine();
    e.negate();
    assert(e.display == "0");

    feed(e, "5");
    e.negate();
    assert(e.display == "-5");
    e.negate();
    assert(e.display == "5");

    // A result can be negated too.
    var f = engine();
    feed(f, "2");
    f.set_operation(CalculatorEngine.Operation.ADD);
    feed(f, "3");
    f.equals();
    f.negate();
    assert(f.display == "-5");
}

private void test_negate_after_operator_signs_the_next_operand() {
    var e = engine();
    feed(e, "5");
    e.set_operation(CalculatorEngine.Operation.ADD);
    e.negate();
    assert(e.display == "-0");
    e.append_digit("3");
    assert(e.display == "-3");
    e.equals();
    assert(e.display == "2");
}

private void test_backspace() {
    var e = engine();
    feed(e, "123");
    e.backspace();
    assert(e.display == "12");
    e.backspace();
    e.backspace();
    assert(e.display == "0");

    // No-op once the entry buffer is fresh again.
    e.backspace();
    assert(e.display == "0");

    var f = engine();
    feed(f, "3.");
    f.backspace();
    assert(f.display == "3");

    // A signed number must not collapse to a lone "-", which parses as 0.
    var g = engine();
    feed(g, "5");
    g.negate();
    g.backspace();
    assert(g.display == "0");
}

// ---------------------------------------------------------------------------
// Operators
// ---------------------------------------------------------------------------

private void test_basic_operations() {
    var add = engine();
    feed(add, "2");
    add.set_operation(CalculatorEngine.Operation.ADD);
    feed(add, "3");
    add.equals();
    assert(add.display == "5");

    var sub = engine();
    feed(sub, "10");
    sub.set_operation(CalculatorEngine.Operation.SUBTRACT);
    feed(sub, "4");
    sub.equals();
    assert(sub.display == "6");

    var mul = engine();
    feed(mul, "6");
    mul.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(mul, "7");
    mul.equals();
    assert(mul.display == "42");

    var div = engine();
    feed(div, "9");
    div.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(div, "3");
    div.equals();
    assert(div.display == "3");
}

private void test_operator_precedence() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "3");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "4");
    e.equals();
    assert(e.display == "14");
}

private void test_lower_precedence_folds_the_stack() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "3");
    e.set_operation(CalculatorEngine.Operation.ADD);
    // The multiplication is resolved as soon as "+" arrives.
    assert(e.display == "6");
    feed(e, "4");
    e.equals();
    assert(e.display == "10");
}

private void test_repeated_operator_replaces_the_pending_one() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.ADD);
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "3");
    e.equals();
    assert(e.display == "6");
}

private void test_power_is_right_associative() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.POWER);
    feed(e, "3");
    e.set_operation(CalculatorEngine.Operation.POWER);
    feed(e, "2");
    e.equals();
    assert(e.display == "512");
}

private void test_power() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.POWER);
    feed(e, "10");
    e.equals();
    assert(e.display == "1024");
}

private void test_equals_without_pending_operation_is_a_noop() {
    var e = engine();
    feed(e, "7");
    e.equals();
    assert(e.display == "7");
    assert(!e.has_error);
}

private void test_history_tracks_the_expression() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    assert(e.history == "2 \xc3\x97 ");
    feed(e, "9");
    e.equals();
    assert(e.history == "2 \xc3\x97 9 =");
    assert(e.get_log().length == 1);
    assert(e.get_log()[0] == "2 \xc3\x97 9 = 18");
}

// ---------------------------------------------------------------------------
// Percent
// ---------------------------------------------------------------------------

private void test_percent_standalone() {
    var e = engine();
    feed(e, "50");
    e.percent();
    assert(e.display == "0.5");
}

private void test_percent_of_the_pending_operand() {
    var e = engine();
    feed(e, "200");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "10");
    e.percent();
    assert(e.display == "20");
    e.equals();
    assert(e.display == "220");
}

private void test_percent_with_multiplication_is_a_plain_division() {
    var e = engine();
    feed(e, "200");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "10");
    e.percent();
    assert(e.display == "0.1");
    e.equals();
    assert(e.display == "20");
}

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

private void test_trig_in_degrees() {
    var e = engine();
    feed(e, "30");
    e.apply_function(CalculatorEngine.Function.SIN);
    assert(e.display == "0.5");

    // The classic artefact: sin(180 deg) must read 0, not 1.22e-16.
    var f = engine();
    feed(f, "180");
    f.apply_function(CalculatorEngine.Function.SIN);
    assert(f.display == "0");

    var g = engine();
    feed(g, "90");
    g.apply_function(CalculatorEngine.Function.COS);
    assert(g.display == "0");

    var h = engine();
    feed(h, "45");
    h.apply_function(CalculatorEngine.Function.TAN);
    assert(h.display == "1");
}

private void test_tangent_asymptote_is_an_error() {
    var e = engine();
    feed(e, "90");
    e.apply_function(CalculatorEngine.Function.TAN);
    assert(e.has_error);
    assert(e.status == CalculatorEngine.Status.UNDEFINED);
}

private void test_trig_in_radians() {
    var e = engine();
    e.angle_unit = CalculatorEngine.AngleUnit.RADIANS;
    feed(e, "0");
    e.apply_function(CalculatorEngine.Function.SIN);
    assert(e.display == "0");

    var f = engine();
    f.angle_unit = CalculatorEngine.AngleUnit.RADIANS;
    feed(f, "0");
    f.apply_function(CalculatorEngine.Function.COS);
    assert(f.display == "1");

    var g = engine();
    g.angle_unit = CalculatorEngine.AngleUnit.RADIANS;
    g.append_pi();
    g.apply_function(CalculatorEngine.Function.SIN);
    assert(g.current_value.abs() < 1e-9);
}

private void test_logarithms() {
    var e = engine();
    feed(e, "1000");
    e.apply_function(CalculatorEngine.Function.LOG10);
    assert(e.display == "3");

    var f = engine();
    feed(f, "1");
    f.apply_function(CalculatorEngine.Function.LN);
    assert(f.display == "0");
}

private void test_logarithm_domain() {
    var e = engine();
    feed(e, "5");
    e.negate();
    e.apply_function(CalculatorEngine.Function.LOG10);
    assert(e.status == CalculatorEngine.Status.DOMAIN_ERROR);

    var f = engine();
    f.apply_function(CalculatorEngine.Function.LN);
    assert(f.status == CalculatorEngine.Status.DOMAIN_ERROR);
}

private void test_square_root() {
    var e = engine();
    feed(e, "16");
    e.apply_function(CalculatorEngine.Function.SQRT);
    assert(e.display == "4");

    var f = engine();
    feed(f, "1");
    f.negate();
    f.apply_function(CalculatorEngine.Function.SQRT);
    assert(f.status == CalculatorEngine.Status.DOMAIN_ERROR);
}

private void test_square_and_reciprocal() {
    var e = engine();
    feed(e, "5");
    e.apply_function(CalculatorEngine.Function.SQUARE);
    assert(e.display == "25");

    var f = engine();
    feed(f, "4");
    f.apply_function(CalculatorEngine.Function.RECIPROCAL);
    assert(f.display == "0.25");

    var g = engine();
    g.apply_function(CalculatorEngine.Function.RECIPROCAL);
    assert(g.status == CalculatorEngine.Status.DIVIDE_BY_ZERO);
}

private void test_factorial() {
    var e = engine();
    feed(e, "5");
    e.apply_function(CalculatorEngine.Function.FACTORIAL);
    assert(e.display == "120");

    var zero = engine();
    zero.apply_function(CalculatorEngine.Function.FACTORIAL);
    assert(zero.display == "1");
}

private void test_factorial_out_of_range() {
    var big = engine();
    feed(big, "171");
    big.apply_function(CalculatorEngine.Function.FACTORIAL);
    assert(big.status == CalculatorEngine.Status.FACTORIAL_RANGE);

    var frac = engine();
    feed(frac, "2.5");
    frac.apply_function(CalculatorEngine.Function.FACTORIAL);
    assert(frac.status == CalculatorEngine.Status.FACTORIAL_RANGE);

    var neg = engine();
    feed(neg, "3");
    neg.negate();
    neg.apply_function(CalculatorEngine.Function.FACTORIAL);
    assert(neg.status == CalculatorEngine.Status.FACTORIAL_RANGE);
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

private void test_division_by_zero() {
    var e = engine();
    feed(e, "5");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "0");
    e.equals();
    assert(e.has_error);
    assert(e.status == CalculatorEngine.Status.DIVIDE_BY_ZERO);
}

private void test_zero_over_zero_is_undefined() {
    var e = engine();
    feed(e, "0");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "0");
    e.equals();
    assert(e.status == CalculatorEngine.Status.UNDEFINED);
}

private void test_overflow() {
    var e = engine();
    feed(e, "9");
    e.set_operation(CalculatorEngine.Operation.POWER);
    feed(e, "999");
    e.equals();
    assert(e.status == CalculatorEngine.Status.OVERFLOW);
}

private void test_errors_are_sticky() {
    var e = engine();
    feed(e, "5");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "0");
    e.equals();
    assert(e.has_error);

    // The old code parsed "Error" back to 0 and silently kept going.
    e.append_digit("5");
    assert(e.has_error);
    e.set_operation(CalculatorEngine.Operation.ADD);
    assert(e.has_error);
    e.equals();
    assert(e.has_error);
    e.apply_function(CalculatorEngine.Function.SQRT);
    assert(e.has_error);
    e.backspace();
    assert(e.has_error);
}

private void test_clear_recovers_from_an_error() {
    var e = engine();
    feed(e, "5");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "0");
    e.equals();
    e.clear();

    assert(!e.has_error);
    assert(e.status == CalculatorEngine.Status.OK);
    assert(e.display == "0");
    assert(e.history == "");
    assert(e.paren_depth == 0);
    assert(!e.has_pending_operation);

    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "2");
    e.equals();
    assert(e.display == "4");
}

// ---------------------------------------------------------------------------
// Parentheses
// ---------------------------------------------------------------------------

private void test_parentheses() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    e.open_paren();
    assert(e.paren_depth == 1);
    feed(e, "3");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "4");
    e.close_paren();
    assert(e.paren_depth == 0);
    assert(e.display == "7");
    e.equals();
    assert(e.display == "14");
}

private void test_nested_parentheses() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    e.open_paren();
    e.open_paren();
    assert(e.paren_depth == 2);
    feed(e, "1");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "2");
    e.close_paren();
    assert(e.display == "3");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "3");
    e.close_paren();
    assert(e.display == "9");
    e.equals();
    assert(e.display == "18");
}

private void test_open_paren_after_a_number_multiplies_implicitly() {
    var e = engine();
    feed(e, "5");
    e.open_paren();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "3");
    e.close_paren();
    e.equals();
    assert(e.display == "25");
}

private void test_unbalanced_parentheses() {
    var e = engine();
    e.close_paren();
    assert(e.paren_depth == 0);
    assert(!e.has_error);

    // An unclosed group is resolved by "=".
    var f = engine();
    feed(f, "2");
    f.set_operation(CalculatorEngine.Operation.MULTIPLY);
    f.open_paren();
    feed(f, "3");
    f.set_operation(CalculatorEngine.Operation.ADD);
    feed(f, "4");
    f.equals();
    assert(f.display == "14");
    assert(f.paren_depth == 0);
}

private void test_clear_empties_the_paren_stack() {
    var e = engine();
    e.open_paren();
    e.open_paren();
    e.clear();
    assert(e.paren_depth == 0);
}

// ---------------------------------------------------------------------------
// Memory
// ---------------------------------------------------------------------------

private void test_memory() {
    var e = engine();
    assert(!e.has_memory);

    feed(e, "5");
    e.memory_add();
    assert(e.has_memory);
    assert(e.memory == 5);

    e.clear();
    feed(e, "3");
    e.memory_subtract();
    assert(e.memory == 2);

    e.clear();
    e.memory_recall();
    assert(e.display == "2");

    e.memory_clear();
    assert(!e.has_memory);
    assert(e.memory == 0);
}

private void test_set_value() {
    var e = engine();
    e.set_value(12.5);
    assert(e.display == "12.5");
    e.append_digit("3");
    assert(e.display == "3");
}

private void test_memory_survives_clear() {
    var e = engine();
    feed(e, "7");
    e.memory_add();
    e.clear();
    assert(e.memory == 7);
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

private void test_formatting_keeps_twelve_significant_digits() {
    var e = engine();
    feed(e, "1");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "3");
    e.equals();
    assert(e.display == "0.333333333333");
}

private void test_formatting_hides_binary_residue() {
    var e = engine();
    feed(e, "0.1");
    e.set_operation(CalculatorEngine.Operation.ADD);
    feed(e, "0.2");
    e.equals();
    assert(e.display == "0.3");
}

private void test_formatting_strips_trailing_zeros() {
    var e = engine();
    feed(e, "2");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "1");
    e.equals();
    assert(e.display == "2");
}

private void test_formatting_normalises_negative_zero() {
    assert(CalculatorEngine.format(-0.0) == "0");
    assert(CalculatorEngine.format(0.0) == "0");
}

/**
 * The display is rounded to 12 significant digits; the values fed to the next
 * operator must not be. Folding a chain through the rendered string turned
 * sqrt(2) x sqrt(2) into 1.99999999999.
 */
private void test_chained_operations_keep_full_precision() {
    var e = engine();
    feed(e, "1");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "3");
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "3");
    e.equals();
    assert(e.display == "1");

    var f = engine();
    feed(f, "2");
    f.apply_function(CalculatorEngine.Function.SQRT);
    assert(f.display == "1.41421356237");
    f.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(f, "2");
    f.apply_function(CalculatorEngine.Function.SQRT);
    f.equals();
    assert(f.display == "2");
}

private void test_typed_digits_are_read_from_the_display() {
    // A number the user typed has no exact counterpart to fall back on.
    var e = engine();
    feed(e, "1");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "3");
    e.equals();
    assert(e.display == "0.333333333333");

    // Overwriting the result with typed digits must not reuse the old value.
    feed(e, "2");
    assert(e.current_value == 2);
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "3");
    e.equals();
    assert(e.display == "6");
}

/**
 * Regression guard for the locale bug: printf("%.12g") honours LC_NUMERIC and
 * emitted "0,125" under fr_FR, which g_ascii_strtod then read back as 0.
 */
private void test_formatting_is_locale_independent() {
    unowned string? previous = Intl.setlocale(LocaleCategory.NUMERIC, null);
    string[] candidates = { "fr_FR.UTF-8", "fr_FR.utf8", "de_DE.UTF-8", "es_ES.UTF-8" };
    bool applied = false;
    foreach (string candidate in candidates) {
        if (Intl.setlocale(LocaleCategory.NUMERIC, candidate) != null) {
            applied = true;
            break;
        }
    }
    if (!applied) {
        Test.skip("no comma-decimal locale is installed");
        return;
    }

    var e = engine();
    feed(e, "1");
    e.set_operation(CalculatorEngine.Operation.DIVIDE);
    feed(e, "8");
    e.equals();

    assert(e.display == "0.125");
    assert(!("," in e.display));

    // And the value must survive a round-trip back through the parser.
    e.set_operation(CalculatorEngine.Operation.MULTIPLY);
    feed(e, "8");
    e.equals();
    assert(e.display == "1");

    Intl.setlocale(LocaleCategory.NUMERIC, previous ?? "C");
}

public int main(string[] args) {
    Test.init(ref args);

    Test.add_func("/calculator/entry/replaces-leading-zero", test_entry_replaces_leading_zero);
    Test.add_func("/calculator/entry/appends-digits", test_entry_appends_digits);
    Test.add_func("/calculator/entry/after-result", test_entry_after_result_starts_a_new_number);
    Test.add_func("/calculator/entry/after-operator", test_entry_after_operator_starts_a_new_number);
    Test.add_func("/calculator/entry/length-capped", test_entry_is_length_capped);
    Test.add_func("/calculator/entry/decimal-point", test_decimal_point);
    Test.add_func("/calculator/entry/constants", test_constants);
    Test.add_func("/calculator/entry/negate", test_negate);
    Test.add_func("/calculator/entry/negate-after-operator", test_negate_after_operator_signs_the_next_operand);
    Test.add_func("/calculator/entry/backspace", test_backspace);

    Test.add_func("/calculator/operators/basic", test_basic_operations);
    Test.add_func("/calculator/operators/precedence", test_operator_precedence);
    Test.add_func("/calculator/operators/folds-stack", test_lower_precedence_folds_the_stack);
    Test.add_func("/calculator/operators/replace-pending", test_repeated_operator_replaces_the_pending_one);
    Test.add_func("/calculator/operators/power", test_power);
    Test.add_func("/calculator/operators/power-right-associative", test_power_is_right_associative);
    Test.add_func("/calculator/operators/equals-noop", test_equals_without_pending_operation_is_a_noop);
    Test.add_func("/calculator/operators/history", test_history_tracks_the_expression);

    Test.add_func("/calculator/percent/standalone", test_percent_standalone);
    Test.add_func("/calculator/percent/of-pending-operand", test_percent_of_the_pending_operand);
    Test.add_func("/calculator/percent/with-multiplication", test_percent_with_multiplication_is_a_plain_division);

    Test.add_func("/calculator/functions/trig-degrees", test_trig_in_degrees);
    Test.add_func("/calculator/functions/tangent-asymptote", test_tangent_asymptote_is_an_error);
    Test.add_func("/calculator/functions/trig-radians", test_trig_in_radians);
    Test.add_func("/calculator/functions/logarithms", test_logarithms);
    Test.add_func("/calculator/functions/logarithm-domain", test_logarithm_domain);
    Test.add_func("/calculator/functions/square-root", test_square_root);
    Test.add_func("/calculator/functions/square-reciprocal", test_square_and_reciprocal);
    Test.add_func("/calculator/functions/factorial", test_factorial);
    Test.add_func("/calculator/functions/factorial-range", test_factorial_out_of_range);

    Test.add_func("/calculator/errors/division-by-zero", test_division_by_zero);
    Test.add_func("/calculator/errors/zero-over-zero", test_zero_over_zero_is_undefined);
    Test.add_func("/calculator/errors/overflow", test_overflow);
    Test.add_func("/calculator/errors/sticky", test_errors_are_sticky);
    Test.add_func("/calculator/errors/clear-recovers", test_clear_recovers_from_an_error);

    Test.add_func("/calculator/parens/simple", test_parentheses);
    Test.add_func("/calculator/parens/nested", test_nested_parentheses);
    Test.add_func("/calculator/parens/implicit-multiplication", test_open_paren_after_a_number_multiplies_implicitly);
    Test.add_func("/calculator/parens/unbalanced", test_unbalanced_parentheses);
    Test.add_func("/calculator/parens/cleared", test_clear_empties_the_paren_stack);

    Test.add_func("/calculator/memory/basic", test_memory);
    Test.add_func("/calculator/memory/survives-clear", test_memory_survives_clear);
    Test.add_func("/calculator/entry/set-value", test_set_value);

    Test.add_func("/calculator/format/significant-digits", test_formatting_keeps_twelve_significant_digits);
    Test.add_func("/calculator/format/binary-residue", test_formatting_hides_binary_residue);
    Test.add_func("/calculator/format/trailing-zeros", test_formatting_strips_trailing_zeros);
    Test.add_func("/calculator/format/negative-zero", test_formatting_normalises_negative_zero);
    Test.add_func("/calculator/format/chained-precision", test_chained_operations_keep_full_precision);
    Test.add_func("/calculator/format/typed-digits", test_typed_digits_are_read_from_the_display);
    Test.add_func("/calculator/format/locale-independent", test_formatting_is_locale_independent);

    return Test.run();
}
