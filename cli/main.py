"""2인 로컬 대전 CLI — Trump Card Auto Chess POC"""
from src.card import Card, Rank, Suit
from src.economy import Player
from src.pool import SharedCardPool
from src.board import OFCBoard
from src.combat import count_synergies
from src.game import GameState, RoundManager


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
        print(f"[{player.name}]  HP: {player.hp}  골드: {player.gold}골드  "
              f"레벨: {player.level}  연승: {player.win_streak}  연패: {player.loss_streak}")
        print(f"  벤치: {cards_str(player.bench)}")
        print_board(player)
        synergies = count_synergies(player.board)
        print(f"  수트 시너지: {synergies}개 활성화")
        print()


def setup_demo_board(player: Player, use_strong: bool = True):
    """데모용 보드 자동 설정"""
    player.board = OFCBoard()
    if use_strong:
        # 강한 보드: 플러시 back
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
        # 약한 보드: 원페어 back
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
        print(f"  ★ {p1.name} 스쿠프! (3:0 전승)")
    if result_b.is_scoop:
        print(f"  ★ {p2.name} 스쿠프! (3:0 전승)")
    if result_a.hula_applied:
        print(f"  ★ {p1.name} 훌라 성공! (×4 배수)")
    if result_b.hula_applied:
        print(f"  ★ {p2.name} 훌라 성공! (×4 배수)")


def run_poc_game(auto_mode: bool = False):
    """2인 로컬 대전 메인 루프"""
    print("=" * 60)
    print("  Trump Card Auto Chess — POC (2인 로컬)")
    print("=" * 60)

    pool = SharedCardPool()
    pool.initialize()

    p1 = Player(name="Player1", gold=0)
    p2 = Player(name="Player2", gold=0)
    state = GameState(players=[p1, p2], pool=pool)
    manager = RoundManager(state)

    while not state.is_game_over():
        # 준비 단계
        manager.start_prep_phase()
        print_game_state(state)

        if not auto_mode:
            print(f"[준비 페이즈] 카드 배치 (데모: 자동 배치)")
            input("Enter를 누르면 자동 배치 및 전투를 시작합니다... ")

        # 데모: 자동 보드 배치
        setup_demo_board(p1, use_strong=True)
        setup_demo_board(p2, use_strong=False)

        print("\n[배치 완료]")
        print_game_state(state)

        # Foul 확인
        foul_a = p1.board.check_foul()
        foul_b = p2.board.check_foul()
        if foul_a.has_foul:
            print(f"[경고] {p1.name} Foul 발생! 라인: {foul_a.foul_lines}")
        if foul_b.has_foul:
            print(f"[경고] {p2.name} Foul 발생! 라인: {foul_b.foul_lines}")

        # 전투
        results = manager.start_combat_phase()
        if results:
            result_a, result_b = results[0]
            print_combat_result(result_a, result_b, p1, p2)

        # 라운드 종료
        manager.end_round()

        print(f"\n[라운드 종료] {p1.name} HP: {p1.hp}  {p2.name} HP: {p2.hp}")
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
    import sys
    auto = '--auto' in sys.argv
    run_poc_game(auto_mode=auto)
