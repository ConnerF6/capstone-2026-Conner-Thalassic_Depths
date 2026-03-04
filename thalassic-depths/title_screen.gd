extends Control

var data = null
@onready var username_input: TextEdit = $UsernameInput
@onready var username_confirm: Button = $UsernameConfirm
@onready var rich_text_label: RichTextLabel = $UsernameInputLable

func _ready():
	if ResourceLoader.exists("user://ThalassicSaveData.tres"):
		data = ResourceLoader.load("user://ThalassicSaveData.tres")
	else:
		data = load("res://DataManager.gd").new()
	if data.username != "":
		$UsernameInput.text = data.username
	else:
		username_input.show()
		username_confirm.show()
		rich_text_label.show()

func _on_confirm_pressed():
	data.username = $UsernameInput.text
	data.save_game()
