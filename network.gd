# CoinFlipClient.gd
# WebSocket 客戶端函數庫 - 適用於 Godot 4.x
extends Node

## ----------------------------------------------------------------------------
## Signals (信號)
## ----------------------------------------------------------------------------

signal connected_successful
signal connection_failed
signal disconnected
signal message_received(type: String, data: Dictionary)
signal toss_result_received(result: Dictionary)
signal status_updated # 通用狀態更新，如水杯、在線人數

## ----------------------------------------------------------------------------
## Properties (屬性)
## ----------------------------------------------------------------------------

const DEFAULT_SERVER_URL := "ws://127.0.0.1:8765"
const MAX_HOLD_DURATION := 5.0 # 最大長按時間 (秒)

@export var server_url: String = DEFAULT_SERVER_URL
var player_uuid := "" # 使用 String 類型存儲 UUID

# 遊戲狀態
var water_cup := 0
var water_cup_limit := 200
var online_players := 0
var active_events := [] # 存儲事件字典陣列
var last_result := {} # 存儲上次拋擲結果字典
var fragment_rewards := {}
var last_message := ""

# WebSocket 客戶端實例
var _client: WebSocketPeer
var _is_connected := false

## ----------------------------------------------------------------------------
## Initialization (初始化)
## ----------------------------------------------------------------------------

func _ready() -> void:
	# 確保 WebSocketClient 可用
	_client = WebSocketPeer.new()
	
	# 連接 WebSocketClient 的內建信號 (Godot 4 推薦的 Callable 連接方式)
	_client.connection_established.connect(_on_connection_established)
	_client.connection_closed.connect(_on_connection_closed)
	_client.connection_error.connect(_on_connection_error)
	_client.data_received.connect(_on_data_received)
	
	# 初始化 UUID (使用 OS.get_unique_id() 或更健壯的方法)
	player_uuid = "%s-%s" % [OS.get_unique_id(), randi() % 10000]

# 【修正 1: 避免衝突】將 is_connected 改名為 is_socket_connected
func is_socket_connected() -> bool:
	# 【修正 2: 狀態常數】將 WebSocketPeer.STATE_CONNECTED 改為 STATE_OPEN
	return _is_connected and _client.get_connection_status() == WebSocketPeer.STATE_OPEN

## ----------------------------------------------------------------------------
## Base Connection Functions (基本連接函數)
## ----------------------------------------------------------------------------

func connect_to_server() -> bool:
	if is_socket_connected():
		print("🔌 已連接")
		return true

	# 【修正 3: URL 解析】使用更符合 Godot 4 的 split
	var url_parts: PackedStringArray = server_url.split("://")
	if url_parts.size() < 2 or not url_parts[1].contains(":"):
		print("❌ 服務器 URL 格式錯誤 (應為 ws://host:port)")
		connection_failed.emit()
		return false
		
	var host_port: PackedStringArray = url_parts[1].split(":")
	var host: String = host_port[0]
	var port_str: String = host_port[1].split("/")[0] # 確保只取端口，忽略路徑
	var port: int = port_str.to_int()

	if port == 0:
		print("❌ 服務器端口錯誤: %s" % port_str)
		connection_failed.emit()
		return false

	print("🔌 正在連接到 %s..." % server_url)
	
	var error: Error = _client.connect_to_url("ws://%s:%d" % [host, port])
	if error != OK:
		print("❌ 連接失敗 (Godot錯誤): %s" % error)
		connection_failed.emit()
		return false

	return true

func disconnect_from_server() -> void:
	if _client and _client.get_connection_status() == WebSocketPeer.STATE_OPEN:
		_client.disconnect_from_host()
	_is_connected = false
	print("🔌 已斷開連接")

## ----------------------------------------------------------------------------
## WebSocket Client Callbacks (WebSocket 客戶端回調)
## ----------------------------------------------------------------------------

func _on_connection_established(protocol: String) -> void:
	_is_connected = true
	print("✅ 成功連接，玩家ID: %s" % player_uuid)
	connected_successful.emit()

func _on_connection_closed(was_clean: bool) -> void:
	_is_connected = false
	print("🔌 服務器連接已斷開 (Clean: %s)" % was_clean)
	disconnected.emit()

func _on_connection_error() -> void:
	_is_connected = false
	print("❌ 連接失敗: 連接錯誤")
	connection_failed.emit()

func _on_data_received() -> void:
	var peer: WebSocketPeer = _client.get_peer(1)
	var data_bytes: PackedByteArray = peer.get_packet()
	var message: String = data_bytes.get_string_from_utf8()
	
	var data: Variant = JSON.parse_string(message)
	
	if data is Dictionary and data.has("type"):
		var msg_type: String = data["type"]
		_handle_message(msg_type, data as Dictionary)
		message_received.emit(msg_type, data as Dictionary)
	else:
		print("⚠️ JSON解析錯誤或收到無效消息: %s" % message.left(50))

## ----------------------------------------------------------------------------
## Message Handling (消息處理)
## ----------------------------------------------------------------------------

# 內部處理函數保持與 Python 版本邏輯一致
func _handle_message(msg_type: String, data: Dictionary) -> void:
	match msg_type:
		"welcome":
			_handle_welcome(data)
		"toss_result":
			_handle_toss_result(data)
		"cup_update":
			_handle_cup_update(data)
		"server_event":
			_handle_server_event(data)
		"personal_reward":
			_handle_personal_reward(data)
		"events_info":
			_handle_events_info(data)
		"status_info":
			_handle_status_info(data)
		"error":
			_handle_error(data)

func _handle_welcome(data: Dictionary) -> void:
	water_cup = data.get("water_cup", 0)
	water_cup_limit = data.get("water_cup_limit", 200)
	online_players = data.get("online_players", 0)
	last_message = data.get("message", "")
	print("🎉 歡迎消息: 水杯 %s/%s" % [water_cup, water_cup_limit])
	status_updated.emit()

func _handle_toss_result(data: Dictionary) -> void:
	var coin_result: Dictionary = data.get("coin_result", {})
	
	last_result = {
		"is_heads": coin_result.get("is_heads", false),
		"flip_results": coin_result.get("flip_results", []),
		"heads_count": coin_result.get("heads_count", 0),
		"tails_count": coin_result.get("tails_count", 0),
		"water_drops_added": coin_result.get("water_drops_added", 0),
		"flip_probability": coin_result.get("flip_probability", 0.5)
	}
	
	water_cup = data.get("water_cup", 0)
	water_cup_limit = data.get("water_cup_limit", 200)
	active_events = data.get("active_events", [])
	fragment_rewards = data.get("fragment_rewards", {})
	
	var result_text: String = "正面(女神)" if last_result.is_heads else "反面(雲朵)"
	var flip_count: int = len(last_result.flip_results)
	print("🪙 拋擲結果: %s, 翻轉 %d 次, 水滴 +%d" % [result_text, flip_count, last_result.water_drops_added])
	toss_result_received.emit(last_result)
	status_updated.emit()

func _handle_cup_update(data: Dictionary) -> void:
	water_cup = data.get("water_cup", 0)
	water_cup_limit = data.get("water_cup_limit", 200)
	online_players = data.get("online_players", 0)
	print("💧 水杯更新: %s/%s" % [water_cup, water_cup_limit])
	status_updated.emit()

func _handle_server_event(data: Dictionary) -> void:
	last_message = data.get("message", "")
	var event_type: String = data.get("event", "")
	
	if event_type == "water_cup_full":
		var reward: int = data.get("reward", 0)
		print("🎉 水杯已滿！獲得 %d 個雲碎片" % reward)
	elif event_type == "new_event_started":
		var event_name: String = data.get("event_name", "未知事件")
		print("🎪 新事件: %s" % event_name)

func _handle_personal_reward(data: Dictionary) -> void:
	last_message = data.get("message", "")
	var reward: int = data.get("reward", 0)
	print("🎁 個人獎勵: %d 個雲碎片" % reward)

func _handle_events_info(data: Dictionary) -> void:
	active_events = data.get("active_events", [])
	print("📋 活躍事件: %d 個" % len(active_events))

func _handle_status_info(data: Dictionary) -> void:
	water_cup = data.get("water_cup", 0)
	water_cup_limit = data.get("water_cup_limit", 200)
	online_players = data.get("online_players", 0)
	print("📊 狀態: 水杯 %s/%s, 在線 %d" % [water_cup, water_cup_limit, online_players])
	status_updated.emit()

func _handle_error(data: Dictionary) -> void:
	var error_msg: String = data.get("message", "未知錯誤")
	print("❌ 服務器錯誤: %s" % error_msg)

## ----------------------------------------------------------------------------
## Send Message Functions (發送消息函數)
## ----------------------------------------------------------------------------

func _send_message(message: Dictionary) -> bool:
	if not is_socket_connected():
		print("⚠️ 未連接到服務器")
		return false
	
	var json_str: String = JSON.stringify(message)
	var data_bytes: PackedByteArray = json_str.to_utf8_buffer()

	var error: Error = _client.get_peer(1).put_packet(data_bytes)
	
	if error != OK:
		print("❌ 發送失敗 (Godot錯誤: %s)" % error)
		return false
	
	return true

func toss_coin(hold_duration: float = 0.0) -> bool:
	var clamped_duration: float = clampf(hold_duration, 0.0, MAX_HOLD_DURATION)
	
	var message: Dictionary = {
		"type": "toss",
		"uuid": player_uuid,
		"hold_duration": clamped_duration
	}
	
	var success: bool = _send_message(message)
	if success:
		var flip_prob: float = calculate_flip_probability(clamped_duration)
		print("🪙 發送拋擲請求: 長按 %.2fs, 翻轉機率 %.0f%%" % [clamped_duration, flip_prob * 100.0])
		
	return success

func get_status() -> bool:
	var message: Dictionary = {
		"type": "get_status",
		"uuid": player_uuid
	}
	
	var success: bool = _send_message(message)
	if success:
		print("📊 請求狀態資訊")
		
	return success

func get_events() -> bool:
	var message: Dictionary = {
		"type": "get_events",
		"uuid": player_uuid
	}
	
	var success: bool = _send_message(message)
	if success:
		print("🎪 請求事件資訊")
		
	return success

## ----------------------------------------------------------------------------
## Utility Functions (便利函數)
## ----------------------------------------------------------------------------

func calculate_flip_probability(hold_duration: float) -> float:
	const BASE_PROB := 0.5
	var hold_bonus: float = minf(hold_duration / MAX_HOLD_DURATION, 1.0) * 0.47
	return BASE_PROB + hold_bonus

func get_water_percentage() -> float:
	if water_cup_limit <= 0:
		return 0.0
	return float(water_cup) / float(water_cup_limit)

func get_active_event_names() -> Array:
	var names: Array = []
	for event in active_events:
		if typeof(event) == TYPE_DICTIONARY:
			names.append(event.get("name", "未知"))
	return names

func get_last_flip_sequence() -> Array:
	if last_result.has("flip_results"):
		return last_result.flip_results
	return []

func get_total_fragment_rewards() -> int:
	return fragment_rewards.get("total", 0)

## ----------------------------------------------------------------------------
## Godot Processing (必須持續 Polling)
## ----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _client and _client.is_connected_to_host():
		_client.poll()
