extends "res://addons/gut/test.gd"

# Tests for prompts/get and resources/subscribe + resources/unsubscribe +
# notifications/resources/updated handling in mcp_server_core.gd.

var _core: RefCounted = null

class FakeTransport extends McpTransportBase:
	var sent: Array = []
	func send_raw_message(message: Dictionary) -> void:
		sent.append(message)
	func is_running() -> bool:
		return false

func before_each():
	_core = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()

func after_each():
	if _core and _core.is_running():
		_core.stop()
	_core = null

func _register_dummy_resource(uri: String) -> void:
	_core.register_resource(uri, "Dummy", "application/json", func(_params): return {"text": "{}"}, "dummy resource")

# ---------------------------------------------------------------------------
# prompts/get
# ---------------------------------------------------------------------------

func test_prompt_get_missing_name_returns_error():
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {}})
	assert_true(resp.has("error"), "Empty name should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_INVALID_PARAMS, "Should be invalid params")

func test_prompt_get_unknown_returns_error():
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "does_not_exist"}})
	assert_true(resp.has("error"), "Unknown prompt should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_INVALID_PARAMS, "Should be invalid params")

func test_prompt_get_returns_callable_content():
	var no_args: Array[Dictionary] = []
	_core.register_prompt("greet", "Greet prompt", no_args, func(_args): return {"messages": [{"role": "user", "content": {"type": "text", "text": "hi"}}]})
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "greet"}})
	assert_true(resp.has("result"), "Should return a result")
	assert_eq(resp["result"]["messages"].size(), 1, "Should pass through callable messages")
	assert_eq(resp["result"]["description"], "Greet prompt", "Should default description to prompt description")

func test_prompt_get_missing_required_argument_errors():
	var args: Array[Dictionary] = [{"name": "topic", "description": "t", "required": true}]
	_core.register_prompt("topical", "Topical", args, func(_a): return {"messages": []})
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "topical", "arguments": {}}})
	assert_true(resp.has("error"), "Missing required argument should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_INVALID_PARAMS, "Should be invalid params")

func test_prompt_get_with_required_argument_present():
	var args: Array[Dictionary] = [{"name": "topic", "required": true}]
	_core.register_prompt("topical", "Topical", args, func(a): return {"messages": [{"role": "user", "content": {"type": "text", "text": a.get("topic", "")}}]})
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "topical", "arguments": {"topic": "dogs"}}})
	assert_true(resp.has("result"), "Should return a result")
	assert_eq(resp["result"]["messages"][0]["content"]["text"], "dogs", "Argument should reach the callable")

func test_prompt_get_without_callable_falls_back_to_description():
	var no_args: Array[Dictionary] = []
	_core.register_prompt("plain", "Plain description", no_args, Callable())
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "plain"}})
	assert_true(resp.has("result"), "Should return a result")
	assert_eq(resp["result"]["messages"], [], "Should default to empty messages")
	assert_eq(resp["result"]["description"], "Plain description", "Should use prompt description")

func test_prompt_get_callable_non_dictionary_errors():
	var no_args: Array[Dictionary] = []
	_core.register_prompt("bad", "Bad", no_args, func(_a): return "not a dict")
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "bad"}})
	assert_true(resp.has("error"), "Non-dictionary callable result should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_INTERNAL_ERROR, "Should be internal error")

func test_prompt_get_awaits_async_callable():
	var no_args: Array[Dictionary] = []
	_core.register_prompt("async_prompt", "Async", no_args, func(_a):
		await get_tree().process_frame
		return {"messages": [{"role": "user", "content": {"type": "text", "text": "async-ok"}}]})
	var resp: Dictionary = await _core._handle_prompt_get({"id": 1, "params": {"name": "async_prompt"}})
	assert_true(resp.has("result"), "Async callable should resolve to a result")
	assert_eq(resp["result"]["messages"][0]["content"]["text"], "async-ok", "Async message should pass through")

# ---------------------------------------------------------------------------
# resources/subscribe + unsubscribe
# ---------------------------------------------------------------------------

func test_subscribe_missing_uri_errors():
	var resp: Dictionary = _core._handle_resource_subscribe({"id": 1, "params": {}})
	assert_true(resp.has("error"), "Missing uri should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_INVALID_PARAMS, "Should be invalid params")

func test_subscribe_unknown_resource_errors():
	var resp: Dictionary = _core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://missing"}})
	assert_true(resp.has("error"), "Unknown resource should error")
	assert_eq(resp["error"]["code"], MCPTypes.ERROR_RESOURCE_NOT_FOUND, "Should be resource not found")

func test_subscribe_registers_subscription():
	_register_dummy_resource("godot://dummy")
	var resp: Dictionary = _core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://dummy"}})
	assert_true(resp.has("result"), "Subscribe should succeed")
	assert_true(_core.is_resource_subscribed("godot://dummy"), "Subscription should be tracked")

func test_unsubscribe_removes_subscription():
	_register_dummy_resource("godot://dummy")
	_core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://dummy"}})
	var resp: Dictionary = _core._handle_resource_unsubscribe({"id": 2, "params": {"uri": "godot://dummy"}})
	assert_true(resp.has("result"), "Unsubscribe should succeed")
	assert_false(_core.is_resource_subscribed("godot://dummy"), "Subscription should be removed")

func test_unregister_resource_drops_subscription():
	_register_dummy_resource("godot://dummy")
	_core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://dummy"}})
	_core.unregister_resource("godot://dummy")
	assert_false(_core.is_resource_subscribed("godot://dummy"), "Unregistering should drop subscription")

func test_stop_clears_subscriptions():
	_register_dummy_resource("godot://dummy")
	_core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://dummy"}})
	# stop() returns early unless the server is active; simulate a running server.
	_core._active = true
	_core.stop()
	assert_false(_core.is_resource_subscribed("godot://dummy"), "stop() should clear per-session subscriptions")

# ---------------------------------------------------------------------------
# notifications/resources/updated
# ---------------------------------------------------------------------------

func test_notify_resource_updated_sends_when_subscribed():
	_register_dummy_resource("godot://dummy")
	_core._handle_resource_subscribe({"id": 1, "params": {"uri": "godot://dummy"}})
	var fake: FakeTransport = FakeTransport.new()
	_core._transport = fake
	var sent: bool = _core.notify_resource_updated("godot://dummy")
	assert_true(sent, "Should report a notification was sent")
	assert_eq(fake.sent.size(), 1, "Exactly one notification should be sent")
	assert_eq(fake.sent[0]["method"], MCPTypes.NOTIFICATION_RESOURCES_UPDATED, "Should use resources/updated method")
	assert_eq(fake.sent[0]["params"]["uri"], "godot://dummy", "Should carry the uri")

func test_notify_resource_updated_skips_when_not_subscribed():
	_register_dummy_resource("godot://dummy")
	var fake: FakeTransport = FakeTransport.new()
	_core._transport = fake
	var sent: bool = _core.notify_resource_updated("godot://dummy")
	assert_false(sent, "Should not notify when not subscribed")
	assert_eq(fake.sent.size(), 0, "No notification should be sent")
