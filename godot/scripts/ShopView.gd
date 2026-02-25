class_name ShopView
extends VBoxContainer

## 상점 뷰 컴포넌트
## Shop.tscn에 연결되는 스크립트

signal shop_card_clicked(index: int)
signal reroll_pressed
signal buy_xp_pressed

@onready var shop_area: HBoxContainer = $ShopArea
@onready var reroll_btn: Button = $ButtonRow/RerollBtn
@onready var buy_xp_btn: Button = $ButtonRow/BuyXPBtn

var card_node_scene = preload("res://scenes/CardNode.tscn")

func _ready() -> void:
	reroll_btn.pressed.connect(func(): emit_signal("reroll_pressed"))
	buy_xp_btn.pressed.connect(func(): emit_signal("buy_xp_pressed"))

func refresh(shop_cards: Array, player_gold: int) -> void:
	## 상점 카드 표시 갱신
	for child in shop_area.get_children():
		child.queue_free()

	for i in range(shop_cards.size()):
		var card = shop_cards[i]
		if card == null:
			var placeholder = Panel.new()
			placeholder.custom_minimum_size = Vector2(80, 120)
			shop_area.add_child(placeholder)
			continue

		var cn: CardNode = card_node_scene.instantiate()
		shop_area.add_child(cn)
		cn.setup(card)

		# 구매 가능 여부 표시
		if player_gold >= card.cost:
			cn.modulate.a = 1.0
		else:
			cn.modulate.a = 0.5

		# 비용 라벨 추가
		var cost_label = Label.new()
		cost_label.text = "%dG" % card.cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.theme_override_font_sizes = {"font_size": 12}
		cn.add_child(cost_label)

		cn.card_clicked.connect(_on_shop_card_clicked.bind(i))

func _on_shop_card_clicked(index: int) -> void:
	emit_signal("shop_card_clicked", index)
