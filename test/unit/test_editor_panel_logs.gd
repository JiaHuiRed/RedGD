extends "res://addons/gut/test.gd"

var _debug_tools: RefCounted = null

func before_each():
	_debug_tools = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()

func after_each():
	_debug_tools = null

func test_infer_log_type_error():
	assert_eq(_debug_tools._infer_log_type_from_line("ERROR: Something went wrong"), "Error", "ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("SCRIPT ERROR: test"), "Error", "SCRIPT ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("PARSE ERROR: syntax"), "Error", "PARSE ERROR: prefix should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("ERROR at line 5"), "Error", "ERROR at prefix should be Error")

func test_infer_log_type_warning():
	assert_eq(_debug_tools._infer_log_type_from_line("WARNING: Check this"), "Warning", "WARNING: prefix should be Warning")
	assert_eq(_debug_tools._infer_log_type_from_line("WARN something"), "Warning", "WARN prefix should be Warning")

func test_infer_log_type_debug():
	assert_eq(_debug_tools._infer_log_type_from_line("DEBUG: Detail info"), "Debug", "DEBUG: prefix should be Debug")
	assert_eq(_debug_tools._infer_log_type_from_line("DEBUG message"), "Debug", "DEBUG prefix should be Debug")

func test_infer_log_type_info():
	assert_eq(_debug_tools._infer_log_type_from_line("Normal log message"), "Info", "Normal message should be Info")
	assert_eq(_debug_tools._infer_log_type_from_line("Godot Engine v4.6.1"), "Info", "Engine message should be Info")
	assert_eq(_debug_tools._infer_log_type_from_line("print output"), "Info", "print output should be Info")

func test_infer_log_type_godot_format():
	assert_eq(_debug_tools._infer_log_type_from_line("  ERROR: core/variant/variant_utility.cpp:1024 - message"), "Error", "Godot ERROR format should be Error")
	assert_eq(_debug_tools._infer_log_type_from_line("  WARNING: core/variant/variant_utility.cpp:1034 - message"), "Warning", "Godot WARNING format should be Warning")

func test_get_editor_panel_logs_no_editor():
	var result: Dictionary = _debug_tools._get_editor_panel_logs([], 100, 0, "desc")
	assert_has(result, "source", "Should have source field")
	assert_eq(result["source"], "editor_panel", "Source should be editor_panel")
