extends Node
## Справжній транспорт хмари: один HTTPRequest на запит. Створює його лише Cloud.start(), коли тести чи
## перевірка не підставили свій. send(метод, адреса, заголовки, тіло, done) і done(ok, код HTTP, текст):
## ok = false, коли відповіді нема зовсім (немає мережі, час вийшов, TLS) — тоді код 0.
## На комп'ютері запит іде через проксі зі змінної HTTPS_PROXY (так у середовищі збирання й перевірок),
## на телефоні — напряму. Меню ставлять гру на паузу, тож вузли працюють і під паузою.

var timeout := 15.0
var proxy_host := ""
var proxy_port := 0

const METHODS := {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PATCH": HTTPClient.METHOD_PATCH,
	"DELETE": HTTPClient.METHOD_DELETE}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() in ["Android", "iOS"]:
		return
	var p := OS.get_environment("HTTPS_PROXY")
	if p == "":
		p = OS.get_environment("https_proxy")
	var hp := proxy_of(p)
	if not hp.is_empty():
		proxy_host = hp[0]
		proxy_port = hp[1]


## «http://127.0.0.1:3128» → ["127.0.0.1", 3128]; порожньо, якщо не розібрати.
static func proxy_of(p: String) -> Array:
	if p == "":
		return []
	var hp := p.get_slice("://", 1) if "://" in p else p
	hp = hp.get_slice("/", 0)
	if "@" in hp:
		hp = hp.get_slice("@", 1)
	var i := hp.rfind(":")
	if i <= 0 or not hp.substr(i + 1).is_valid_int():
		return []
	return [hp.substr(0, i), int(hp.substr(i + 1))]


func send(method: String, url: String, headers: PackedStringArray, body: String, done: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(req)
	if proxy_host != "":
		req.set_https_proxy(proxy_host, proxy_port)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, bytes: PackedByteArray):
		req.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS
		done.call(ok, code if ok else 0, bytes.get_string_from_utf8()), CONNECT_ONE_SHOT)
	var err := req.request(url, headers, METHODS.get(method, HTTPClient.METHOD_GET), body)
	if err != OK:
		req.queue_free()
		done.call(false, 0, "")
