from __future__ import annotations

import random
from dataclasses import dataclass, field


@dataclass(frozen=True)
class HoldemEvent:
    id: str
    name: str
    phase: str          # "flop" | "turn" | "river"
    description: str
    effect_type: str    # "suit_boost" | "economy" | "foul" | "combat"


@dataclass
class HoldemState:
    stage: int = 1                              # 현재 스테이지 번호
    flop: list = field(default_factory=list)    # HoldemEvent 최대 3장
    turn: object = None                         # HoldemEvent | None
    river: object = None                        # HoldemEvent | None
    active_events: list = field(default_factory=list)  # 현재 라운드 적용 이벤트

    def advance(self, round_in_stage: int) -> None:
        """라운드 내 순서(1=Flop, 2=Turn, 3=River)에 따라 이벤트 공개."""
        if round_in_stage == 1:
            self.active_events = list(self.flop)
        elif round_in_stage == 2:
            if self.turn is not None:
                self.active_events = list(self.flop) + [self.turn]
        elif round_in_stage == 3:
            events = list(self.flop)
            if self.turn is not None:
                events.append(self.turn)
            if self.river is not None:
                events.append(self.river)
            self.active_events = events

    def get_active_by_type(self, effect_type: str) -> list:
        """특정 effect_type의 활성 이벤트 필터링."""
        return [e for e in self.active_events if e.effect_type == effect_type]

    def has_active_event(self, event_id: str) -> bool:
        """특정 id 이벤트 활성화 여부."""
        return any(e.id == event_id for e in self.active_events)


PILOT_EVENTS: list[HoldemEvent] = [
    HoldemEvent(
        id="suit_bonus_spade",
        name="스페이드 우위",
        phase="flop",
        description="이번 라운드 ♠ 수트 시너지 카운트 +1",
        effect_type="suit_boost",
    ),
    HoldemEvent(
        id="double_interest",
        name="이자 배가",
        phase="flop",
        description="이번 라운드 이자 수입 ×2",
        effect_type="economy",
    ),
    HoldemEvent(
        id="foul_amnesty",
        name="폴 면제",
        phase="turn",
        description="이번 라운드 Foul 패널티 미적용",
        effect_type="foul",
    ),
    HoldemEvent(
        id="scoop_bonus",
        name="스쿠프 강화",
        phase="turn",
        description="스쿠프 시 추가 피해 +4 (기존 +2에서 +6으로)",
        effect_type="combat",
    ),
    HoldemEvent(
        id="low_card_power",
        name="로우카드 역전",
        phase="river",
        description="이번 라운드 하이카드 비교 역전 (낮은 랭크 우선)",
        effect_type="combat",
    ),
]


def create_holdem_state(stage: int = 1) -> HoldemState:
    """스테이지용 HoldemState 생성. PILOT_EVENTS에서 무작위 배분."""
    flop_candidates = [e for e in PILOT_EVENTS if e.phase == "flop"]
    turn_candidates = [e for e in PILOT_EVENTS if e.phase == "turn"]
    river_candidates = [e for e in PILOT_EVENTS if e.phase == "river"]
    return HoldemState(
        stage=stage,
        flop=random.sample(flop_candidates, min(3, len(flop_candidates))),
        turn=random.choice(turn_candidates) if turn_candidates else None,
        river=random.choice(river_candidates) if river_candidates else None,
    )
