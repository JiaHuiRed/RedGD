extends "res://addons/gut/test.gd"

var _runner: AsyncJobRunner = null

func before_each():
	_runner = AsyncJobRunner.new()

func after_each():
	if _runner != null:
		_runner.flush()
	_runner = null

func _fast_work() -> Dictionary:
	return {"ok": true, "value": 42}

func _slow_work() -> Dictionary:
	OS.delay_msec(150)
	return {"ok": true}

func _non_dictionary_work() -> int:
	return 7

func _wait_for_result(key: String, timeout_ms: int = 5000) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var polled: Dictionary = _runner.poll(key)
		if bool(polled["finished"]):
			return polled["result"]
		OS.delay_msec(10)
	return {}

func test_start_then_poll_returns_worker_result():
	assert_true(_runner.start("job-a", Callable(self, "_fast_work")), "start returns true for a new key")
	var result: Dictionary = _wait_for_result("job-a")
	assert_eq(result.get("value"), 42, "poll returns the worker's result once finished")
	assert_false(_runner.has_job("job-a"), "finished job is removed after a successful poll")

func test_duplicate_start_while_running_is_rejected():
	assert_true(_runner.start("job-b", Callable(self, "_slow_work")), "first start succeeds")
	assert_false(_runner.start("job-b", Callable(self, "_slow_work")), "second start for a running key is rejected")
	assert_eq(_runner.active_count(), 1, "only one job is tracked for the key")
	var result: Dictionary = _wait_for_result("job-b")
	assert_true(bool(result.get("ok")), "the original job still finishes and is pollable")

func test_poll_unknown_key_is_not_finished():
	var polled: Dictionary = _runner.poll("missing")
	assert_false(bool(polled["finished"]), "polling an unknown key reports not finished")
	assert_eq(polled["result"], {}, "polling an unknown key yields an empty result")

func test_has_job_and_active_count_track_lifecycle():
	assert_eq(_runner.active_count(), 0, "no jobs initially")
	_runner.start("job-c", Callable(self, "_fast_work"))
	assert_true(_runner.has_job("job-c"), "has_job is true while the job exists")
	_wait_for_result("job-c")
	assert_eq(_runner.active_count(), 0, "active_count returns to zero after the job is polled")

func test_non_dictionary_result_is_wrapped():
	_runner.start("job-d", Callable(self, "_non_dictionary_work"))
	var result: Dictionary = _wait_for_result("job-d")
	assert_eq(result.get("result"), 7, "a non-Dictionary worker result is wrapped under 'result'")

func test_flush_clears_outstanding_jobs():
	_runner.start("job-e", Callable(self, "_slow_work"))
	_runner.flush()
	assert_eq(_runner.active_count(), 0, "flush joins and clears outstanding jobs")
	assert_false(_runner.has_job("job-e"), "no jobs remain after flush")
