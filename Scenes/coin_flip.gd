extends Node3D

@export var flip_force_y = 8.0 #向上力度
@export var flip_torque_x = 150.0 #力矩力度
@export var min_spin_time = 1.5 #旋轉時間
@export var coin_land_force_y = -20.0


var coin: RigidBody3D
var is_frontResult = false

#測試開始
func _ready():
	coin = $Coin
	$CanvasLayer/Button.visible = false
	coin.global_position = Vector3(0, 0.5, 0)
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO
	toss_coin()

#硬幣投擲
func toss_coin():
	$CanvasLayer/Button.visible = true
	#重置硬幣狀態
	
	coin.sleeping = false
	coin.call_deferred("set_global_position", Vector3(0, 1.0, 0))
	# 讓 Godot 等待一幀，確保位置設定完成
	await get_tree().process_frame
	coin.angular_velocity = Vector3.ZERO
	
	#向上及旋轉
	var toss_impulse = Vector3(0, flip_force_y, 0)
	var toss_torque = Vector3(flip_torque_x, 0, 0)
	
	coin.apply_impulse(toss_impulse)
	coin.apply_torque(toss_torque)
	
	await get_tree().create_timer(min_spin_time).timeout
	finalize_result()
	
#顯示結果
func finalize_result():
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO
	coin.global_rotation = Vector3.ZERO
	
	var final_rotation = Vector3.ZERO
	if is_frontResult:
		final_rotation = Vector3(deg_to_rad(0), 0, 0)
	else:
		final_rotation = Vector3(deg_to_rad(180), 0, 0)
	$Coin/MeshInstance3D.rotation = final_rotation
	
	coin.global_position.y = 1
	coin.linear_velocity.y = coin_land_force_y
	
	$CanvasLayer/Button.visible = true

func _on_button_pressed() -> void:
	toss_coin()
