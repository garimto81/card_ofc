"""2인+ 로컬 대전 CLI — Trump Card Auto Chess STANDARD"""
import sys
import io

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
else:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from src.card import Card, Rank, Suit  # noqa: E402
from src.economy import Player  # noqa: E402
from src.pool import SharedCardPool  # noqa: E402
from src.board import OFCBoard  # noqa: E402
from src.combat import count_synergies  # noqa: E402
from src.game import GameState, RoundManager  # noqa: E402


RANK_DISPLAY = {
    Rank.TWO: '2', Rank.THREE: '3', Rank.FOUR: '4', Rank.FIVE: '5',
    Rank.SIX: '6', Rank.SEVEN: '7', Rank.EIGHT: '8', Rank.NINE: '9',
    Rank.TEN: 'T', Rank.JACK: 'J', Rank.QUEEN: 'Q', Rank.KING: 'K', Rank.ACE: 'A',
}
SUIT_DISPLAY = {Suit.SPADE: 'S', Suit.HEART: 'H', Suit.DIAMOND: 'D', Suit.CLUB: 'C'}


def card_str(card: Card) -> str:
    stars = '*' * card.stars
    return f"{RANK_DISPLAY[card.rank]}{SUIT_DISPLAY[card.suit]}{stars}"


def cards_str(cards: list) -> str:
    if not cards:
        return '[비어있음]'
    return ' '.join(card_str(c) for c in cards)


def print_separator():
    print('-' * 60)


def print_board(player: Player):
    board = player.board
    hand_results = board.get_hand_results()

    back_hand = hand_results.get('back')
    mid_hand = hand_results.get('mid')
    front_hand = hand_results.get('front')

    back_label = f"({back_hand.hand_type.name})" if back_hand else ""
    mid_label = f"({mid_hand.hand_type.name})" if mid_hand else ""
    front_label = f"({front_hand.hand_type.name})" if front_hand else ""

    print(f"  Back  (5칸): {cards_str(board.back):40} {back_label}")
    print(f"  Mid   (5칸): {cards_str(board.mid):40} {mid_label}")
    print(f"  Front (3칸): {cards_str(board.front):40} {front_label}")

    warnings = board.get_foul_warning()
    for w in warnings:
        print(f"  [!] {w}")


def print_game_state(state: GameState):
    print_separator()
    print(f"라운드 {state.round_num} / {state.max_rounds}  |  페이즈: {state.phase}")
    print_separator()
    for player in state.players:
        fl_tag = " [FL]" if player.in_fantasyland else ""
        print(f"[{player.name}]{fl_tag}  HP: {player.hp}  골드: {player.gold}골드  "
              f"레벨: {player.level}  연승: {player.win_streak}  연패: {player.loss_streak}")
        print(f"  벤치: {cards_str(player.bench)}")
        print_board(player)
        synergies = count_synergies(player.board)
        print(f"  수트 시너지: {synergies}개 활성화")
        print()


def select_player_count(auto_mode: bool) -> int:
    """플레이어 수 선택. auto_mode 시 2인 기본."""
    if auto_mode:
        return 2
    print("플레이어 수를 선택하세요 (2~8):")
    while True:
        try:
            n = int(input("> "))
            if 2 <= n <= 8:
                return n
        except (ValueError, EOFError):
            pass
        print("2에서 8 사이의 숫자를 입력하세요.")


def augment_selector(player: Player, choices: list, auto_mode: bool):
    """증강체 선택 UI. auto_mode 시 첫 번째 자동 선택."""
    if auto_mode:
        return choices[0]
    print(f"\n[증강체 선택] {player.name}")
    for i, aug in enumerate(choices, 1):
        print(f"  {i}. {aug.name}: {aug.description}")
    while True:
        try:
            n = int(input(f"선택 (1~{len(choices)}): "))
            if 1 <= n <= len(choices):
                return choices[n - 1]
        except (ValueError, EOFError):
            pass
        print(f"1~{len(choices)} 중 하나를 입력하세요.")


def run_shop_phase(player: Player, pool: SharedCardPool, auto_mode: bool):
    """상점 UI: shop_cards 출력 + 구매/패스."""
    if not player.shop_cards:
        return
    print(f"\n[ 상점 ] {player.name} (골드: {player.gold})")
    for i, card in enumerate(player.shop_cards, 1):
        print(f"  {i}: {card_str(card)} ({card.cost}코스트)")

    if auto_mode:
        # 자동 모드: 살 수 있는 첫 번째 카드 구매
        for card in player.shop_cards:
            bench_before = len(player.bench)
            if player.buy_card(card, pool):
                bench_after = len(player.bench)
                print(f"  [자동 구매] {card_str(card)}")
                if bench_after < bench_before:
                    upgraded = player.bench[-1]
                    print(f"  {'*' * upgraded.stars} {card_str(upgraded)} {upgraded.stars}성 합성!")
                break
        return

    while True:
        try:
            raw = input("번호 입력 (구매), b (패스): ").strip()
        except EOFError:
            return
        if raw == 'b':
            return
        try:
            idx = int(raw) - 1
            if 0 <= idx < len(player.shop_cards):
                card = player.shop_cards[idx]
                bench_before = len(player.bench)
                if player.buy_card(card, pool):
                    bench_after = len(player.bench)
                    print(f"  구매 완료: {card_str(card)}")
                    if bench_after < bench_before:
                        upgraded = player.bench[-1]
                        print(f"  {'*' * upgraded.stars} {card_str(upgraded)} {upgraded.stars}성 합성!")
                    # 상점 갱신 출력
                    print(f"\n[ 상점 ] {player.name} (골드: {player.gold})")
                    for j, c in enumerate(player.shop_cards, 1):
                        print(f"  {j}: {card_str(c)} ({c.cost}코스트)")
                else:
                    print("  구매 실패 (골드 부족 또는 카드 없음)")
        except (ValueError, IndexError):
            print("  올바른 번호를 입력하세요.")


def run_fl_placement(player: Player, manager: RoundManager, auto_mode: bool):
    """FL 플레이어 13장 배치 UI."""
    cards = player.shop_cards
    if not cards:
        return
    print(f"\n[판타지랜드] {player.name} — 13장 중 보드에 배치하세요")
    print(f"  카드 목록:")
    for i, card in enumerate(cards, 1):
        print(f"    {i}: {card_str(card)}")

    if auto_mode:
        # 자동 배치: 첫 3장 → front, 다음 5장 → mid, 다음 5장 → back
        player.board = OFCBoard()
        player.board.front = list(cards[:3])
        player.board.mid = list(cards[3:8])
        player.board.back = list(cards[8:13])
        manager._return_unplaced_cards(player)
        print("  [자동 배치 완료]")
        return

    while True:
        print(f"\n  현재 보드:")
        print_board(player)
        print(f"\n  미배치 카드:")
        placed_ids = set()
        for line in ['front', 'mid', 'back']:
            for c in getattr(player.board, line):
                placed_ids.add(id(c))
        unplaced = [c for c in cards if id(c) not in placed_ids]
        for i, card in enumerate(unplaced, 1):
            print(f"    {i}: {card_str(card)}")

        if not unplaced:
            print("  모든 카드 배치 완료. 'done' 입력으로 종료.")

        try:
            raw = input("배치 (f/m/b 번호) 또는 done: ").strip().lower()
        except EOFError:
            break
        if raw == 'done':
            front_full = len(player.board.front) == 3
            mid_full = len(player.board.mid) == 5
            back_full = len(player.board.back) == 5
            if front_full and mid_full and back_full:
                manager._return_unplaced_cards(player)
                print("  FL 배치 완료!")
                return
            else:
                print(f"  경고: 보드 미완성 (Front:{len(player.board.front)}/3, "
                      f"Mid:{len(player.board.mid)}/5, Back:{len(player.board.back)}/5)")
                try:
                    confirm = input("  그래도 완료하시겠습니까? (y/n): ").strip().lower()
                except EOFError:
                    break
                if confirm == 'y':
                    manager._return_unplaced_cards(player)
                    return
        else:
            parts = raw.split()
            if len(parts) == 2 and parts[0] in ('f', 'm', 'b'):
                line_map = {'f': 'front', 'm': 'mid', 'b': 'back'}
                line = line_map[parts[0]]
                try:
                    idx = int(parts[1]) - 1
                    if 0 <= idx < len(unplaced):
                        card = unplaced[idx]
                        target = getattr(player.board, line)
                        max_size = 3 if line == 'front' else 5
                        if len(target) < max_size:
                            target.append(card)
                            print(f"  {card_str(card)} → {line.upper()} 배치")
                        else:
                            print(f"  {line.upper()} 슬롯 가득 찼습니다.")
                    else:
                        print("  올바른 번호를 입력하세요.")
                except (ValueError, IndexError):
                    print("  올바른 입력 형식: f/m/b 번호")
            else:
                print("  입력 형식: f/m/b 번호 (예: f 1, m 3, b 5)")

    manager._return_unplaced_cards(player)


def setup_demo_board(player: Player, use_strong: bool = True):
    """데모용 보드 자동 설정"""
    player.board = OFCBoard()
    if use_strong:
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            player.board.back.append(Card(r, Suit.SPADE))
        player.board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.SPADE),
            Card(Rank.FOUR, Suit.HEART),
        ]
        player.board.front = [
            Card(Rank.KING, Suit.CLUB),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
        ]
    else:
        player.board.back = [
            Card(Rank.ACE, Suit.CLUB),
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.JACK, Suit.HEART),
        ]
        player.board.mid = [
            Card(Rank.SEVEN, Suit.SPADE),
            Card(Rank.SEVEN, Suit.CLUB),
            Card(Rank.TWO, Suit.HEART),
            Card(Rank.THREE, Suit.HEART),
            Card(Rank.FOUR, Suit.SPADE),
        ]
        player.board.front = [
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.CLUB),
            Card(Rank.FOUR, Suit.DIAMOND),
        ]


def print_combat_result(result_a, result_b, p1: Player, p2: Player):
    print("\n[전투 결과]")
    for line in ['back', 'mid', 'front']:
        r = result_a.line_results[line]
        if r == 1:
            winner = p1.name
        elif r == -1:
            winner = p2.name
        else:
            winner = '무승부'
        print(f"  {line.upper():5}: {winner}")

    print(f"\n  {p1.name} 승리 라인: {result_a.winner_lines}개  피해: {result_a.damage}")
    print(f"  {p2.name} 승리 라인: {result_b.winner_lines}개  피해: {result_b.damage}")
    if result_a.is_scoop:
        print(f"  * {p1.name} 스쿠프! (3:0 전승)")
    if result_b.is_scoop:
        print(f"  * {p2.name} 스쿠프! (3:0 전승)")
    if result_a.hula_applied:
        print(f"  * {p1.name} 훌라 성공! (x4 배수)")
    if result_b.hula_applied:
        print(f"  * {p2.name} 훌라 성공! (x4 배수)")


def run_poc_game(auto_mode: bool = False):
    """N인 로컬 대전 메인 루프"""
    print("=" * 60)
    print("  Trump Card Auto Chess — STANDARD")
    print("=" * 60)

    num_players = select_player_count(auto_mode)
    pool = SharedCardPool()
    pool.initialize()

    players = [Player(name=f"Player{i+1}", gold=0) for i in range(num_players)]
    state = GameState(players=players, pool=pool)

    def _augment_selector(player, choices):
        return augment_selector(player, choices, auto_mode)

    manager = RoundManager(state, augment_selector=_augment_selector)

    while not state.is_game_over():
        # 준비 단계
        manager.start_prep_phase()
        print_game_state(state)

        # 상점 + FL 배치
        for player in state.players:
            if player.in_fantasyland:
                run_fl_placement(player, manager, auto_mode)
            else:
                run_shop_phase(player, pool, auto_mode)

        if not auto_mode:
            print(f"\n[준비 페이즈] 카드 배치 (데모: 자동 배치)")
            input("Enter를 누르면 자동 배치 및 전투를 시작합니다... ")

        # 데모: 자동 보드 배치 (FL 플레이어 제외)
        for i, player in enumerate(state.players):
            if not player.in_fantasyland:
                setup_demo_board(player, use_strong=(i % 2 == 0))

        print("\n[배치 완료]")
        print_game_state(state)

        # Foul 확인
        for player in state.players:
            foul = player.board.check_foul()
            if foul.has_foul:
                print(f"[경고] {player.name} Foul 발생! 라인: {foul.foul_lines}")

        # 전투
        results = manager.start_combat_phase()
        if results and len(state.players) >= 2:
            result_a, result_b = results[0]
            p1 = state.players[state.combat_pairs[0][0]]
            p2 = state.players[state.combat_pairs[0][1]]
            print_combat_result(result_a, result_b, p1, p2)

        # HP 출력
        print("\n[전투 후 HP]")
        for player in state.players:
            print(f"  {player.name}: {player.hp} HP")

        # 라운드 종료
        prev_names = {p.name for p in state.players}
        manager.end_round()
        current_names = {p.name for p in state.players}
        eliminated = prev_names - current_names
        for name in eliminated:
            print(f"\n[탈락] {name} 탈락!")
        if len(state.players) == 1:
            print(f"\n[우승] {state.players[0].name} 우승!")

        print_separator()

        if not auto_mode and not state.is_game_over():
            input("다음 라운드 계속... ")

    # 최종 결과
    print("\n" + "=" * 60)
    print("  게임 종료!")
    print("=" * 60)
    winner = state.get_winner()
    if winner:
        print(f"  최종 승자: {winner.name}  (HP: {winner.hp})")
    else:
        print("  무승부!")
    print(f"  총 {state.round_num - 1}라운드 진행")
    print("=" * 60)


if __name__ == '__main__':
    auto = '--auto' in sys.argv
    run_poc_game(auto_mode=auto)
