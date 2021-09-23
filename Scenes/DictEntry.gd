extends Control

export var key: String

func _ready():
	pass # Replace with function body.


func _on_DeleteButton_pressed():
	Dict.dict.erase(key)
	get_parent().remove_child(self)
	self.queue_free()
	
	pass # Replace with function body.
