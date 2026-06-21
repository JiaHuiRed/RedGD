# Test fixture: a plain Resource subclass (no class_name) used by the
# data-driven resource tool tests. Mirrors a typical deckbuilder CardData.
extends Resource

@export var title: String = ""
@export var cost: int = 0
@export var damage: int = 0
@export var tags: Array = []
@export var anchor: Vector2 = Vector2.ZERO
