import itertools
import random
from dataclasses import dataclass, field

from src.combat import CombatResolver
from src.economy import Player
from src.pool import SharedCardPool


@dataclass
class GameState:
    players: list
    pool: SharedCardPool
    round_num: int = 1
    phase: str = 'prep'  # 'prep' | 'combat' | 'result' | 'end'
    max_rounds: int = 5
    match_history: dict = field(default_factory=dict)
    combat_pairs: list = field(default_factory=list)
    holdem_state: object = None  # HoldemState | None

    def is_game_over(self) -> bool:
        """생존자 1명 이하이거나 max_rounds 초과 여부"""
        alive = [p for p in self.players if p.hp > 0]
        if len(alive) <= 1:
            return True
        return self.round_num > self.max_rounds

    def get_winner(self) -> 'Player | None':
        """현재 HP 기준 승자 반환. 진행 중이면 None"""
        if not self.is_game_over():
            return None
        alive = [p for p in self.players if p.hp > 0]
        if not alive:
            return None
        return max(alive, key=lambda p: p.hp)


class RoundManager:
    def __init__(self, state: GameState):
        self.state = state
        self.resolver = CombatResolver()

    def start_prep_phase(self):
        """준비 단계: 골드 지급"""
        self.state.phase = 'prep'
        for player in self.state.players:
            income = player.round_income()
            player.gold += income

    def start_combat_phase(self) -> list:
        """전투 단계: 2인 보드 전투"""
        self.state.phase = 'combat'
        results = []
        players = self.state.players

        if len(players) == 2:
            result_a, result_b = self.resolver.resolve(
                players[0].board, players[1].board
            )
            # HP 피해
            players[1].hp -= result_a.damage
            players[0].hp -= result_b.damage

            # 연승/연패 업데이트
            if result_a.winner_lines > result_b.winner_lines:
                players[0].win_streak += 1
                players[0].loss_streak = 0
                players[1].loss_streak += 1
                players[1].win_streak = 0
            elif result_b.winner_lines > result_a.winner_lines:
                players[1].win_streak += 1
                players[1].loss_streak = 0
                players[0].loss_streak += 1
                players[0].win_streak = 0
            else:
                # 동률 시 streak 변경 없음
                pass

            results.append((result_a, result_b))

        return results

    def _get_bye_counts(self) -> dict:
        result = {}
        for player in self.state.players:
            bye_list = self.state.match_history.get(f"__bye__{player.name}", [])
            result[player.name] = len(bye_list)
        return result

    def _record_bye(self, player_name: str) -> None:
        key = f"__bye__{player_name}"
        self.state.match_history.setdefault(key, []).append(self.state.round_num)

    def _update_match_history(self, idx_a: int, idx_b: int) -> None:
        p_a = self.state.players[idx_a]
        p_b = self.state.players[idx_b]
        hist_a = self.state.match_history.setdefault(p_a.name, [])
        hist_a.append(p_b.name)
        if len(hist_a) > 3:
            hist_a.pop(0)
        hist_b = self.state.match_history.setdefault(p_b.name, [])
        hist_b.append(p_a.name)
        if len(hist_b) > 3:
            hist_b.pop(0)

    def _pick_pairs_avoid_repeat(self, indices: list) -> list:
        """4인: match_history 기반 3연속 금지 매칭."""
        candidates = list(itertools.combinations(indices, 2))
        random.shuffle(candidates)

        def recent_matches(idx):
            name = self.state.players[idx].name
            return self.state.match_history.get(name, [])

        for (a, b) in candidates:
            pa_name = self.state.players[a].name
            pb_name = self.state.players[b].name
            hist_a = recent_matches(a)
            hist_b = recent_matches(b)
            # 최근 3회 중 2회 이상 같은 상대면 스킵
            if hist_a.count(pb_name) >= 2 or hist_b.count(pa_name) >= 2:
                continue
            # 나머지 인덱스로 두 번째 쌍 만들기
            remaining = [i for i in indices if i not in (a, b)]
            if len(remaining) == 2:
                return [(a, b), (remaining[0], remaining[1])]

        # fallback: 첫 2쌍
        shuffled = list(indices)
        random.shuffle(shuffled)
        return [(shuffled[0], shuffled[1]), (shuffled[2], shuffled[3])]

    def generate_matchups(self) -> list:
        """생존 플레이어 인덱스 기반 전투 쌍 생성."""
        players = self.state.players
        n = len(players)
        indices = list(range(n))

        if n == 2:
            return [(0, 1)]
        elif n == 3:
            bye_counts = self._get_bye_counts()
            bye_idx = max(indices, key=lambda i: bye_counts.get(players[i].name, 0))
            active = [i for i in indices if i != bye_idx]
            self._record_bye(players[bye_idx].name)
            return [(active[0], active[1])]
        elif n == 4:
            return self._pick_pairs_avoid_repeat(indices)
        else:
            raise ValueError(f"Alpha 지원 플레이어 수: 2~4. 현재: {n}")

    def end_round(self):
        """라운드 종료: 번호 증가, 판타지랜드 전환, 보드 리셋, 증강체 선택, 탈락자 처리"""
        self.state.phase = 'result'
        self.state.round_num += 1

        from src.board import OFCBoard
        for player in self.state.players:
            # 판타지랜드 플래그 전환
            if player.fantasyland_next:
                player.in_fantasyland = True
                player.fantasyland_next = False
            else:
                player.in_fantasyland = False
            # 보드 리셋
            player.board = OFCBoard()

        # 증강체 선택 페이즈 (라운드 2→3, 3→4, 4→5 종료 시)
        if self.state.round_num in (3, 4, 5):
            self._offer_augments()

        # 탈락자 처리
        self.state.players = [p for p in self.state.players if p.hp > 0]

        if self.state.is_game_over():
            self.state.phase = 'end'
        else:
            self.state.phase = 'prep'

    def _offer_augments(self) -> None:
        """각 플레이어에게 SILVER_AUGMENTS 중 1개 자동 선택. Alpha 범위: 자동 선택."""
        from src.augment import SILVER_AUGMENTS
        for player in self.state.players:
            choices = random.sample(SILVER_AUGMENTS, min(3, len(SILVER_AUGMENTS)))
            player.add_augment(choices[0])
