namespace Singularity.Apps {

    public class UnitConverter : Object {
        private struct Unit {
            public string symbol;
            public string category;
            public double factor;
            public double offset;
            public string aliases;
        }

        private const Unit[] UNITS = {
            { "mm", "length", 0.001, 0, "mm;millimeter;millimeters;millimetre;millimetres" },
            { "cm", "length", 0.01, 0, "cm;centimeter;centimeters;centimetre;centimetres" },
            { "m", "length", 1, 0, "m;meter;meters;metre;metres" },
            { "km", "length", 1000, 0, "km;kilometer;kilometers;kilometre;kilometres" },
            { "in", "length", 0.0254, 0, "inch;inches;\"" },
            { "ft", "length", 0.3048, 0, "ft;foot;feet;'" },
            { "yd", "length", 0.9144, 0, "yd;yard;yards" },
            { "mi", "length", 1609.344, 0, "mi;mile;miles" },
            { "nmi", "length", 1852, 0, "nmi;nauticalmile;nauticalmiles" },
            { "mg", "mass", 0.000001, 0, "mg;milligram;milligrams" },
            { "g", "mass", 0.001, 0, "g;gram;grams" },
            { "kg", "mass", 1, 0, "kg;kilogram;kilograms;kilo;kilos" },
            { "t", "mass", 1000, 0, "t;tonne;tonnes;ton;tons" },
            { "oz", "mass", 0.028349523125, 0, "oz;ounce;ounces" },
            { "lb", "mass", 0.45359237, 0, "lb;lbs;pound;pounds" },
            { "st", "mass", 6.35029318, 0, "st;stone;stones" },
            { "°C", "temperature", 1, 273.15, "c;°c;celsius;centigrade" },
            { "°F", "temperature", 5.0 / 9.0, 459.67, "f;°f;fahrenheit" },
            { "K", "temperature", 1, 0, "k;kelvin" },
            { "ml", "volume", 0.001, 0, "ml;milliliter;milliliters;millilitre;millilitres" },
            { "cl", "volume", 0.01, 0, "cl;centiliter;centiliters;centilitre;centilitres" },
            { "l", "volume", 1, 0, "l;liter;liters;litre;litres" },
            { "m³", "volume", 1000, 0, "m3;m³;cubicmeter;cubicmeters" },
            { "tsp", "volume", 0.00492892159375, 0, "tsp;teaspoon;teaspoons" },
            { "tbsp", "volume", 0.01478676478125, 0, "tbsp;tablespoon;tablespoons" },
            { "fl oz", "volume", 0.0295735295625, 0, "floz;fluidounce;fluidounces" },
            { "cup", "volume", 0.2365882365, 0, "cup;cups" },
            { "pt", "volume", 0.473176473, 0, "pt;pint;pints" },
            { "gal", "volume", 3.785411784, 0, "gal;gallon;gallons" },
            { "m²", "area", 1, 0, "m2;m²;sqm;squaremeter;squaremeters" },
            { "km²", "area", 1000000, 0, "km2;km²;squarekilometer;squarekilometers" },
            { "ha", "area", 10000, 0, "ha;hectare;hectares" },
            { "ac", "area", 4046.8564224, 0, "ac;acre;acres" },
            { "ft²", "area", 0.09290304, 0, "ft2;ft²;sqft;squarefoot;squarefeet" },
            { "mi²", "area", 2589988.110336, 0, "mi2;mi²;squaremile;squaremiles" },
            { "m/s", "speed", 1, 0, "m/s;mps" },
            { "km/h", "speed", 1000.0 / 3600.0, 0, "km/h;kmh;kph" },
            { "mph", "speed", 0.44704, 0, "mph;mi/h" },
            { "kn", "speed", 1852.0 / 3600.0, 0, "kn;knot;knots" },
            { "s", "time", 1, 0, "s;sec;secs;second;seconds" },
            { "min", "time", 60, 0, "min;mins;minute;minutes" },
            { "h", "time", 3600, 0, "h;hr;hrs;hour;hours" },
            { "d", "time", 86400, 0, "d;day;days" },
            { "wk", "time", 604800, 0, "wk;week;weeks" },
            { "B", "data", 1, 0, "b;byte;bytes" },
            { "KB", "data", 1000, 0, "kb;kilobyte;kilobytes" },
            { "MB", "data", 1000000, 0, "mb;megabyte;megabytes" },
            { "GB", "data", 1e9, 0, "gb;gigabyte;gigabytes" },
            { "TB", "data", 1e12, 0, "tb;terabyte;terabytes" },
            { "KiB", "data", 1024, 0, "kib;kibibyte;kibibytes" },
            { "MiB", "data", 1048576, 0, "mib;mebibyte;mebibytes" },
            { "GiB", "data", 1073741824, 0, "gib;gibibyte;gibibytes" },
            { "TiB", "data", 1099511627776, 0, "tib;tebibyte;tebibytes" },
            { "J", "energy", 1, 0, "j;joule;joules" },
            { "kJ", "energy", 1000, 0, "kj;kilojoule;kilojoules" },
            { "cal", "energy", 4.184, 0, "cal;calorie;calories" },
            { "kcal", "energy", 4184, 0, "kcal;kilocalorie;kilocalories" },
            { "kWh", "energy", 3600000, 0, "kwh;kilowatthour;kilowatthours" },
            { "Pa", "pressure", 1, 0, "pa;pascal;pascals" },
            { "kPa", "pressure", 1000, 0, "kpa;kilopascal;kilopascals" },
            { "bar", "pressure", 100000, 0, "bar;bars" },
            { "atm", "pressure", 101325, 0, "atm;atmosphere;atmospheres" },
            { "psi", "pressure", 6894.757293168, 0, "psi" }
        };

        public string from_symbol { get; private set; default = ""; }
        public string to_symbol { get; private set; default = ""; }
        public double value { get; private set; default = 0; }
        public double result { get; private set; default = 0; }

        public static string format_number(double val, int digits = 12) {
            if (val.is_nan()) return "Error";
            if (val.is_infinity() != 0) return val > 0 ? "∞" : "-∞";
            string s = "%.*g".printf(digits, val);
            if ("." in s && !("e" in s)) {
                while (s.has_suffix("0")) s = s.substring(0, s.length - 1);
                if (s.has_suffix(".")) s = s.substring(0, s.length - 1);
            }
            return s;
        }

        private static int find_unit(string text) {
            string key = text.strip().down().replace(" ", "");
            if (key == "") return -1;
            for (int i = 0; i < UNITS.length; i++) {
                if (UNITS[i].symbol == text.strip()) return i;
            }
            for (int i = 0; i < UNITS.length; i++) {
                foreach (string alias in UNITS[i].aliases.split(";")) {
                    if (alias == key) return i;
                }
            }
            return -1;
        }

        public bool parse(string query) {
            MatchInfo match;
            string connectors = "in|to|into|as|=|%s|%s".printf(
                Regex.escape_string(_("in")), Regex.escape_string(_("to")));
            try {
                var regex = new Regex("^\\s*(-?[0-9]+(?:[.,][0-9]+)?(?:e-?[0-9]+)?)\\s*(.+?)\\s+(?:%s)\\s+(.+?)\\s*$".printf(connectors),
                    RegexCompileFlags.CASELESS);
                if (!regex.match(query, 0, out match)) return false;
            } catch (RegexError e) {
                return false;
            }
            double amount;
            if (!double.try_parse(match.fetch(1).replace(",", "."), out amount)) return false;
            int from = find_unit(match.fetch(2));
            int to = find_unit(match.fetch(3));
            if (from < 0 || to < 0 || from == to) return false;
            if (UNITS[from].category != UNITS[to].category) return false;
            double base_value = (amount + UNITS[from].offset) * UNITS[from].factor;
            value = amount;
            result = base_value / UNITS[to].factor - UNITS[to].offset;
            from_symbol = UNITS[from].symbol;
            to_symbol = UNITS[to].symbol;
            return true;
        }
    }

    public class ConversionSearchProvider : Singularity.SearchProviderService {
        private const string RESULT_ID = "conversion";

        private UnitConverter converter = new UnitConverter();
        private bool valid = false;

        public override async string[] get_initial_results(string[] terms, Cancellable? cancellable) throws Error {
            valid = converter.parse(string.joinv(" ", terms));
            return valid ? new string[] { RESULT_ID } : new string[] {};
        }

        private string result_text() {
            return "%s %s".printf(UnitConverter.format_number(converter.result, 6), converter.to_symbol);
        }

        public override async Singularity.SearchResultMeta[] get_result_metas(string[] ids, Cancellable? cancellable) throws Error {
            if (!valid || ids.length == 0 || ids[0] != RESULT_ID) return {};
            var meta = new Singularity.SearchResultMeta(RESULT_ID, result_text());
            meta.description = "%s %s = %s".printf(UnitConverter.format_number(converter.value),
                converter.from_symbol, result_text());
            meta.icon = new ThemedIcon("dev.sinty.calculator");
            meta.score = 100;
            meta.add_action("copy", _("Copy"), "edit-copy-symbolic");
            return { meta };
        }

        public override async Singularity.SearchActivationReply? activate_result(string id, string[] terms,
                                                                                uint32 timestamp) throws Error {
            return copy_reply(terms);
        }

        public override async Singularity.SearchActivationReply? activate_action(string id, string action_id,
                                                                                string[] terms, uint32 timestamp) throws Error {
            return copy_reply(terms);
        }

        private Singularity.SearchActivationReply? copy_reply(string[] terms) {
            if (!converter.parse(string.joinv(" ", terms))) return null;
            return Singularity.SearchActivationReply.copy(UnitConverter.format_number(converter.result));
        }
    }
}
