extends Button

signal wordSelected(word)

var word = ""


func _ready():
	pressed.connect(func(): wordSelected.emit(word))
