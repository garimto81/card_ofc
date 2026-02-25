class_name GameUI
extends Control

## GameScene UI 컨트롤러
## GameController와 연동하여 보드/벤치/상점 표시 및 버튼 처리

var controller: GameController
var selected_bench_index: int = -1
var card_node_scene = preload("res://scenes/CardNode.tscn")

@onready var hud: HUD = $HUD

@onready var player_info: Label = $TopBar/PlayerInfo
@onready var ai_info: Label = $TopBar/AIInfo
@onready var round_label: Label = $TopBar/RoundLabel
@onready var back_line: HBoxContainer = $BoardArea/BackLine
@onready var mid_line: HBoxContainer = $BoardArea/MidLine
@onready var front_line: HBoxContainer = $BoardArea/FrontLine
@onready var bench_area: HBoxContainer = $BoardArea/BenchArea
@onready var shop_area: HBoxContainer = $RightPanel/ShopArea
@onready var combat_btn: Button = $RightPanel/CombatBtn
@onready var end_round_btn: Button = $RightPanel/EndRoundBtn
@onready var combat_log: RichTextLabel = $RightPanel/CombatLog
@onready var back_hand_label: Label = $HandInfoArea/BackHandLabel
@onready var mid_hand_label: Label = $HandInfoArea/MidHandLabel
@onready var front_hand_label: Label = $HandInfoArea/FrontHandLabel
@onready var reroll_btn: Button = $RightPanel/ButtonRow/RerollBtn
@onready var buy_xp_btn: Button = $RightPanel/ButtonRow/BuyXPBtn

func _ready() -> void:
	controller = GameController.new()
	add_child(controller)
	controller.round_started.connect(_on_round_started)
	controller.combat_done.connect(_on_combat_done)
	controller.state_changed.connect(_on_state_changed)
	controller.player_hp_changed.connect(_on_player_hp_changed)
	controller.ai_hp_changed.connect(_on_ai_hp_changed)
	controller.shop_refreshed.connect(_on_shop_refreshed)
	combat_btn.pressed.connect(_on_combat_pressed)
	end_round_btn.pressed.connect(_on_end_round_pressed)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	buy_xp_btn.pressed.connect(_on_buy_xp_pressed)
	controller.start_game()

func _update_hud() -> void:
	player_info.text = "Player | HP: %d | Gold: %d | Lv:%d" % [
		controller.player_hp,
		controller.player_economy.gold,
		controller.player_economy.level
	]
	ai_info.text = "AI | HP: %d | Gold: %d | Lv:%d" % [
		controller.ai_hp,
		controller.ai_economy.gold,
		controller.ai_economy.level
	]
	round_label.text = "Round %d" % controller.round_num
	_update_hand_info()

func _update_hand_info() -> void:
	var ev = HandEvaluator.new()
	for line_name in ["back", "mid", "front"]:
		var cards: Array = controller.player_board.get(line_name, [])
		var hand: Dictionary = ev.evaluate_hand(cards)
		var hand_name: String = ev.hand_type_name(hand["hand_type"])
		match line_name:
			"back":
				back_hand_label.text = "Back: %s" % hand_name
			"mid":
				mid_hand_label.text = "Mid: %s" % hand_name
			"front":
				front_hand_label.text = "Front: %s" % hand_name

func _refresh_board_display() -> void:
	_clear_container(back_line)
	_clear_container(mid_line)
	_clear_container(front_line)
	_clear_container(bench_area)
	var line_map: Dictionary = {"back": back_line, "mid": mid_line, "front": front_line}
	var max_slots: Dictionary = {"back": 5, "mid": 5, "front": 3}
	for line_name in line_map:
		var line_container: HBoxContainer = line_map[line_name]
		var cards: Array = controller.player_board.get(line_name, [])
		# 점유된 슬롯: 카드 노드 (클릭 시 벤치로 복귀)
		for i in range(cards.size()):
			var cn: CardNode = card_node_scene.instantiate()
			line_container.add_child(cn)
			cn.setup(cards[i])
			cn.line_name = line_name
			cn.slot_index = i
			cn.is_in_bench = false
			cn.card_clicked.connect(_on_board_card_clicked.bind(line_name, i))
		# 빈 슬롯: 클릭 시 선택된 벤치 카드 배치
		var empty_count = max_slots[line_name] - cards.size()
		for _j in range(empty_count):
			var slot_btn = Button.new()
			slot_btn.custom_minimum_size = Vector2(80, 120)
			slot_btn.text = "[ 빈 ]"
			var cap_line = line_name
			slot_btn.pressed.connect(func(): _on_empty_slot_clicked(cap_line))
			line_container.add_child(slot_btn)
	for i in range(controller.player_bench.size()):
		var cn: CardNode = card_node_scene.instantiate()
		bench_area.add_child(cn)
		cn.setup(controller.player_bench[i])
		cn.is_in_bench = true
		cn.slot_index = i
		cn.card_clicked.connect(_on_bench_card_clicked.bind(i))

func _on_empty_slot_clicked(line_name: String) -> void:
	if selected_bench_index >= 0:
		if controller.place_card(selected_bench_index, line_name):
			combat_log.text = "%s 라인에 카드 배치 완료." % line_name
		else:
			combat_log.text = "%s 라인이 가득 찼습니다." % line_name
		selected_bench_index = -1
		_refresh_board_display()
		_update_hud()
	else:
		combat_log.text = "먼저 벤치 카드를 클릭하여 선택하세요."

func _refresh_shop_display(shop_cards: Array) -> void:
	_clear_container(shop_area)
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
		cn.card_clicked.connect(_on_shop_card_clicked.bind(i))
		var cost_label = Label.new()
		cost_label.text = "%dG" % card.cost
		cn.add_child(cost_label)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_bench_card_clicked(index: int) -> void:
	selected_bench_index = index
	combat_log.text = "벤치 카드 선택됨 (인덱스 %d).\n보드 라인을 클릭하여 배치하세요." % index

func _on_board_card_clicked(line_name: String, slot_index: int) -> void:
	if selected_bench_index >= 0:
		if controller.place_card(selected_bench_index, line_name):
			combat_log.text = "%s 라인에 카드 배치 완료." % line_name
		else:
			combat_log.text = "%s 라인이 가득 찼습니다." % line_name
		selected_bench_index = -1
		_refresh_board_display()
		_update_hud()
	else:
		if controller.remove_from_board(line_name, slot_index):
			combat_log.text = "카드를 벤치로 돌려보냈습니다."
		_refresh_board_display()
		_update_hud()

func _on_shop_card_clicked(index: int) -> void:
	if controller.buy_card(index):
		combat_log.text = "카드 구매 성공!"
		_refresh_board_display()
		_update_hud()
		_refresh_shop_display(controller.player_shop)
	else:
		combat_log.text = "골드 부족 또는 구매 불가."

func _on_combat_pressed() -> void:
	controller.start_combat()
	combat_btn.visible = false
	end_round_btn.visible = true

func _on_end_round_pressed() -> void:
	controller.end_round()
	combat_btn.visible = true
	end_round_btn.visible = false
	_refresh_board_display()
	_update_hud()

func _on_reroll_pressed() -> void:
	if not controller.reroll_shop():
		combat_log.text = "골드 부족 (리롤 2G 필요)"

func _on_buy_xp_pressed() -> void:
	if not controller.player_economy.buy_xp():
		combat_log.text = "XP 구매 불가 (4G 필요 또는 최대 레벨)"
	_update_hud()

func _on_round_started(rn: int) -> void:
	round_label.text = "Round %d" % rn
	combat_log.text = "라운드 %d 시작! 카드를 배치하세요." % rn
	_update_hud()

func _on_combat_done(result: Dictionary) -> void:
	var lines_won: int = result.get("lines_won", 0)
	var lines_lost: int = result.get("lines_lost", 0)
	var msg = "전투 결과:\n승리 라인: %d / 패배 라인: %d\n" % [lines_won, lines_lost]
	if result.get("scoop", false):
		msg += "[스쿠프! 3:0 완승]\n"
	if result.get("hula", false):
		msg += "[훌라 선언 가능!]\n"
	msg += "데미지: %d" % result.get("damage", 0)
	if lines_won > lines_lost:
		msg += "\n[승리] AI에게 데미지 적용"
	elif lines_lost > lines_won:
		msg += "\n[패배] 플레이어에게 데미지 적용"
	else:
		msg += "\n[무승부]"
	combat_log.text = msg
	_update_hud()
	if hud:
		hud.show_combat_result(result)

func _on_state_changed(state: String) -> void:
	if state == "game_over":
		var player_won = controller.player_hp > 0
		if player_won:
			combat_log.text = "[게임 클리어] 플레이어 승리"
		else:
			combat_log.text = "[게임 오버] AI 승리"
		combat_btn.visible = false
		end_round_btn.visible = false
		if hud:
			hud.show_game_over(player_won)

func _on_player_hp_changed(_hp: int) -> void:
	_update_hud()

func _on_ai_hp_changed(_hp: int) -> void:
	_update_hud()

func _on_shop_refreshed(cards: Array) -> void:
	_refresh_shop_display(cards)
	_refresh_board_display()
	_update_hud()
