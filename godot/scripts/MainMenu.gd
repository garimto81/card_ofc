class_name MainMenu
extends Control

## 메인 메뉴 씬 컨트롤러
## 게임 시작 / 종료 버튼 처리

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
