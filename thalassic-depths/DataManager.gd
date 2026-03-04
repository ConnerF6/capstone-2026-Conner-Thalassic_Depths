extends Resource

const DataPath := "user://ThalassicSaveData.tres"
@export var username := ""

func save_game():
	ResourceSaver.save(self, DataPath)

static func load_save() -> Resource:
	if ResourceLoader.exists(DataPath):
		return load(DataPath)
	return null
