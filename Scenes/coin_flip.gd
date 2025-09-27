extends Node3D

@export var flip_force_y = 10.0 #向上力度
@export var flip_torque_x = 150.0 #力矩力度
@export var spin_time = 3.0 #旋轉時間

var coin: RigidBody3D
var is_frontResult = false 

#測試開始
func _ready():
	coin = $Coin
	toss_coin()

#硬幣投擲
func toss_coin():
	#重置硬幣狀態
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO
	
	#重置硬幣位置
	coin.global_position = Vector3(0, 1.0, 0)
	is_frontResult = false #結果匯入
	
	#向上及旋轉
	var toss_impulse = Vector3(0, flip_force_y, 0)
	var toss_torque = Vector3(flip_torque_x, 0, 0)
	
	coin.apply_impulse(toss_impulse)
	coin.apply_torque(toss_torque)
	
	#結果判定
	await get_tree().create_timer(spin_time).timeout
	finalize_result()
	
#顯示結果
func finalize_result():
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO
	
	var final_rotation = Vector3.ZERO
	
	if is_frontResult:
		final_rotation = Vector3(deg_to_rad(0), 0, 0)
	
	else:
		final_rotation = Vector3(deg_to_rad(180), 0, 0)
	
	$Coin/MeshInstance3D.rotation = final_rotation
