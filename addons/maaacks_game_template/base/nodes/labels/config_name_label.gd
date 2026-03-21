@tool
extends Label
## Displays the value of `application/config/name`, set in project settings.

const NO_NAME_STRING : String = "Death Below"

## If true, update the title when ready.
@export var auto_update : bool = true
