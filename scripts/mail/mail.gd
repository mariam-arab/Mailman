extends Resource
class_name Mail
## A single letter the player must deliver. Stored as a .tres resource so
## designers can create new letters in the inspector without code changes.

@export var id: String = ""
@export var sender_name: String = ""
@export var sender_address: String = ""
## Vague hint at who lives at the destination — visible on the envelope.
@export_multiline var recipient_description: String = ""
## Handwritten note on the back of the envelope. Often the strongest clue.
@export_multiline var clue_text: String = ""
## Visible smudged street label, e.g. "?? Maple Street". Address number missing.
@export var address_line: String = ""
@export var has_wax_seal: bool = false
## Which house this letter belongs to. Must match Mailbox.house_id.
@export var correct_house_id: String = ""
## 1 = obvious, 2 = moderate, 3 = subtle.
@export_range(1, 3) var difficulty: int = 1
## Optional — a Texture2D for the envelope front. Falls back to a flat color.
@export var envelope_texture: Texture2D
@export var stamp_texture: Texture2D
@export var envelope_color: Color = Color(0.96, 0.91, 0.78)  # cream
