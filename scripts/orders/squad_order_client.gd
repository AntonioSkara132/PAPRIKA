class_name SquadOrderClient
extends Node

## Sends typed squad orders to the local order service (tools/sandbox_order_service.py)
## and reports the interpreted order. The service only interprets text; the
## world validates the order again and decides what the soldiers do.
##
## The service address is http://127.0.0.1:8787, or SANDBOX_SERVICE_URL when it
## names a loopback HTTP address. Only one order is in flight at a time: a new
## one cancels the reply to the previous one.

signal order_ready(order: Dictionary, source: String)
signal order_failed(message: String)
signal status_changed(text: String)

const PROTOCOL_VERSION := 2
const REQUIRED_ACTIONS := ["form_line", "move_to", "stop", "clarify", "follow_player", "patrol", "create_group", "attack"]
const OFFLINE_STATUS := "order service offline · start tools/sandbox_order_service.py"

var service_url := "http://127.0.0.1:8787"
var compatible := false
var status := "checking the order service"
var _url_valid := true
var _timeout := 20.0
var _revision := 0
var _order_request: HTTPRequest
var _health_request: HTTPRequest

func _ready() -> void:
	var configured := OS.get_environment("SANDBOX_SERVICE_URL").trim_suffix("/")
	if not configured.is_empty():
		var pattern := RegEx.new()
		pattern.compile("^http://(127\\.0\\.0\\.1|localhost)(:([0-9]{1,5}))?$")
		var matched := pattern.search(configured)
		_url_valid = matched != null and (matched.get_string(3).is_empty() or int(matched.get_string(3)) in range(1, 65536))
		if _url_valid:
			service_url = configured.replace("localhost", "127.0.0.1")
	check()

func busy() -> bool:
	return is_instance_valid(_order_request)

## Asks the service whether it is running and speaks the expected protocol.
func check() -> void:
	compatible = false
	if not _url_valid:
		_set_status("SANDBOX_SERVICE_URL must be http://127.0.0.1 or localhost")
		return
	if is_instance_valid(_health_request):
		_health_request.cancel_request()
		_health_request.queue_free()
	_health_request = HTTPRequest.new()
	_health_request.timeout = 3.0
	_health_request.body_size_limit = 16384
	add_child(_health_request)
	_health_request.request_completed.connect(_on_health_completed.bind(_health_request))
	_set_status("checking the order service")
	if _health_request.request(service_url + "/health") != OK:
		_set_status(OFFLINE_STATUS)

func submit(prompt: String, context: Dictionary) -> bool:
	cancel()
	if not compatible:
		order_failed.emit("The order service is not running. Q follow, R hold and T attack still work.")
		check()
		return false
	_order_request = HTTPRequest.new()
	_order_request.timeout = _timeout
	_order_request.body_size_limit = 65536
	add_child(_order_request)
	_order_request.request_completed.connect(_on_order_completed.bind(_revision))
	var payload := {"request_id": _revision, "prompt": prompt, "context": context}
	if _order_request.request(service_url + "/orders", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		_order_request.queue_free()
		_order_request = null
		order_failed.emit("The order could not be sent to the order service.")
		return false
	return true

## Drops the reply to the order in flight, if any.
func cancel() -> void:
	_revision += 1
	if is_instance_valid(_order_request):
		_order_request.cancel_request()
		_order_request.queue_free()
	_order_request = null

func _on_order_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int) -> void:
	if revision != _revision:
		return
	if is_instance_valid(_order_request):
		_order_request.queue_free()
	_order_request = null
	if result != HTTPRequest.RESULT_SUCCESS:
		order_failed.emit("No reply from the order service; nothing was ordered.")
		check()
		return
	var decoder := JSON.new()
	var parsed: Variant = decoder.data if decoder.parse(body.get_string_from_utf8()) == OK else null
	if not parsed is Dictionary:
		order_failed.emit("The order service returned invalid JSON; nothing was ordered.")
		return
	if code != 200:
		order_failed.emit(str(parsed.get("error", "The order service rejected the order.")).left(300))
		return
	var echoed: Variant = parsed.get("request_id")
	if (not echoed is int and not echoed is float) or int(echoed) != revision or not parsed.get("order") is Dictionary:
		order_failed.emit("The order service reply does not match the order; nothing was ordered.")
		return
	var source: String = {"local": "local model", "cloud": "cloud model", "fixture": "fixed test reply"}.get(parsed.get("mode"), "order service")
	order_ready.emit(parsed["order"], source)

func _on_health_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if request != _health_request:
		return
	_health_request.queue_free()
	_health_request = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status(OFFLINE_STATUS)
		return
	var decoder := JSON.new()
	var health: Variant = decoder.data if decoder.parse(body.get_string_from_utf8()) == OK else null
	if not health is Dictionary:
		_set_status("the order service returned invalid JSON")
		return
	var version: Variant = health.get("protocol_version")
	var actions: Variant = health.get("supported_actions")
	if (not version is int and not version is float) or int(version) != PROTOCOL_VERSION or not actions is Array:
		_set_status("the order service uses another protocol; restart it")
		return
	for action in REQUIRED_ACTIONS:
		if not actions.has(action):
			_set_status("the order service lacks %s; restart it" % action)
			return
	if not health.get("ready", false):
		_set_status("order service not ready: " + str(health.get("error", "model not loaded")).left(120))
		return
	var timeout_value: Variant = health.get("request_timeout", 20.0)
	if (timeout_value is int or timeout_value is float) and float(timeout_value) >= 5.0 and float(timeout_value) <= 180.0:
		_timeout = float(timeout_value) + 5.0
	compatible = true
	_set_status("Enter: type an order (%s)" % str(health.get("model", health.get("mode", ""))).left(40))

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)
