class_name TestCase extends Node
# Base for every tests/test_*.gd. The runner makes a fresh instance per test_* method and reads `failures` afterwards.

var failures: Array[String] = []

func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)

func near(a: float, b: float, eps: float, what: String) -> void:
	check(absf(a - b) <= eps, "%s (got %s, want %s ± %s)" % [what, a, b, eps])
