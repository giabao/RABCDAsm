module obfuscator.optimizenames;

import std.regex;

class OptimizeNames {
	static void optimize(string[string] fullRenames, string namePrefix) {
		foreach(k, v; fullRenames) {
			if (k == v) fullRenames.remove(k);
		}

		uint[string] ids;
		uint n = 0;
		foreach(v; fullRenames) {
			auto m = match(v, regex(`([^.:]+)([.:]?)`, "g"));
			if(m.empty) {
				ids[v] = n++;
			} else {
				while (!m.empty) {
					string p = m.captures[1];
					if (! (p in ids))
						ids[p] = n++;
					m.popFront();
				}
			}
		}

		foreach(ref v; fullRenames) {
			auto m = match(v, regex(`([^.:]+)([.:]?)`, "g"));
			if(m.empty) {
				v = namePrefix ~ toBasedName(ids[v]);
			} else {
				string r;
				while (!m.empty) {
					string p = m.captures[1];
					r ~= namePrefix ~ toBasedName(ids[p]) ~ m.captures[2];
					m.popFront();
				}
				v = r;
			}
		}
	}

	private static string toBasedName(uint n) {
		auto digits = toDigits(n, DIGITS.length);
		char[] s = [];
		foreach_reverse(ubyte d; digits) {
			s ~= DIGITS[d];
		}
		return s.dup;
	}

	private static const char[] DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$0123456789";
	
	private static ubyte[] toDigits(uint n, ubyte b) {
		ubyte[] digits = [];
		while (n > 0) {
			digits ~= n % b;
			n /= b;
		}
		return digits;
	}
}
