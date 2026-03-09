extends Control

var data = null
@onready var username_input: TextEdit = $UsernameInput
@onready var username_confirm: Button = $UsernameConfirm
@onready var rich_text_label: RichTextLabel = $UsernameInputLable
@onready var join_btn: Button = $JoinBtn
@onready var host_btn: Button = $HostBtn

func _ready():
	if ResourceLoader.exists("user://ThalassicSaveData.tres"):
		data = ResourceLoader.load("user://ThalassicSaveData.tres")
	else:
		data = load("res://Scripts/DataManager.gd").new()
	if data.username != "":
		$UsernameInput.text = data.username
		join_btn.show()
		host_btn.show()
	else:
		username_input.show()
		username_confirm.show()
		rich_text_label.show()

func _on_confirm_pressed():
	data.username = $UsernameInput.text
	data.save_game()
	username_input.hide()
	username_confirm.hide()
	rich_text_label.hide()
	join_btn.show()
	host_btn.show()
