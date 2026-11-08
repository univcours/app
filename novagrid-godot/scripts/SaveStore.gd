extends RefCounted
## Atomic replace plus last valid backup; unknown save keys survive upgrades.
const PATH = "user://novagrid-godot-save.json"
static func _read_path(path:String) -> Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {}
 var decoder:=JSON.new()
 if decoder.parse(file.get_as_text())!=OK:return {}
 var value:Variant=decoder.data
 return value if value is Dictionary else {}
static func read() -> Dictionary:
 var value:Dictionary=_read_path(PATH)
 return _read_path(PATH+".bak") if value.is_empty() else value
static func write(data:Dictionary) -> Error:
 var temp:=PATH+".tmp"
 var file:=FileAccess.open(temp,FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify(data))
 file.flush()
 var error:Error=file.get_error()
 file.close()
 if error!=OK:return error
 # Never replace a good backup with a corrupt main save.
 if not _read_path(PATH).is_empty():
  error=DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH),ProjectSettings.globalize_path(PATH+".bak"))
  if error!=OK:return error
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(PATH))
