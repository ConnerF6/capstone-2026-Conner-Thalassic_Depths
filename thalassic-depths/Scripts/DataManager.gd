extends Resource
const DataPath := "user://ThalassicSaveData.tres"
@export var username := ""

func save_game():
	ResourceSaver.save(self, DataPath)

static func load_save() -> Resource:
	if ResourceLoader.exists(DataPath):
		return load(DataPath)
	return null


static func get_or_create() -> Resource:
	var existing = load_save()
	if existing != null:
		return existing
	return load("res://Scripts/DataManager.gd").new()
