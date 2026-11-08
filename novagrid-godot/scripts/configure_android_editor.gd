extends SceneTree
## Native Godot editor setup for the user's local Windows Android Studio SDK.
## Set NOVAGRID_ANDROID_SDK and NOVAGRID_JAVA_SDK before invoking:
## godot --headless --editor --path <project> --script res://scripts/configure_android_editor.gd
func _initialize() -> void:
 call_deferred("_configure")

func _configure() -> void:
 if not Engine.is_editor_hint():
  printerr("Open this script with --editor enabled")
  quit(1)
  return
 # Let the editor initialize before setting paths. Quitting from _initialize
 # interrupts the resource scan and can leave settings only partially saved.
 await process_frame
 await process_frame
 var filesystem = EditorInterface.get_resource_filesystem()
 while filesystem.is_scanning():
  await process_frame
 var sdk:String = OS.get_environment("NOVAGRID_ANDROID_SDK").strip_edges()
 var jdk:String = OS.get_environment("NOVAGRID_JAVA_SDK").strip_edges()
 if sdk.is_empty() or jdk.is_empty():
  printerr("NOVAGRID_ANDROID_SDK and NOVAGRID_JAVA_SDK are required")
  quit(1)
  return
 var settings:EditorSettings = EditorInterface.get_editor_settings()
 if settings==null:
  printerr("Godot Editor Settings unavailable")
  quit(1)
  return
 settings.set_setting("export/android/android_sdk_path",sdk.replace("\\","/"))
 settings.set_setting("export/android/java_sdk_path",jdk.replace("\\","/"))
 # Godot 4.5.1's headless editor/custom SceneTree shutdown reports five
 # known Dummy-renderer RID allocation types even after a complete scan.
 # CI classifies only those exact shutdown diagnostics for this helper;
 # gameplay, compilation, imports and exports retain strict error checks.
 print("NOVAGRID_ANDROID_EDITOR_CONFIGURED")
 quit(0)
