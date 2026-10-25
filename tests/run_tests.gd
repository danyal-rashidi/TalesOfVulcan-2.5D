extends Node
# Runs every res://tests/test_*.gd: a fresh instance per test_* method, awaited in turn.
# Any engine or script error logged during a test fails it (warnings don't). Quits with the number of failures.

class ErrorLog extends Logger:
	var errors: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])
		_lock.unlock()

	func take() -> Array[String]:
		_lock.lock()
		var out: Array[String] = errors.duplicate()
		errors.clear()
		_lock.unlock()
		return out

func _ready() -> void:
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		errors.take()
		var script := load("res://tests/" + file) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s: does not load: %s" % [file, "; ".join(errors.take())])
			failed += 1
			continue
		for m in script.get_script_method_list():
			var test: String = m["name"]
			if not test.begins_with("test_"):
				continue
			var t := script.new() as TestCase
			add_child(t)
			await t.call(test)
			var why: Array[String] = t.failures.duplicate()
			why.append_array(errors.take())
			t.queue_free()
			Engine.time_scale = 1.0    # a test left in hit-stop or slow motion must not slow the next one
			if why.is_empty():
				print("PASS %s::%s" % [file, test])
				passed += 1
			else:
				print("FAIL %s::%s: %s" % [file, test, "; ".join(why)])
				failed += 1
	OS.remove_logger(errors)
	print("TESTS PASSED %d FAILED %d" % [passed, failed])
	get_tree().quit(failed)
