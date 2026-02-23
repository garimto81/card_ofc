from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Augment:
    id: str               # 고유 식별자
    name: str             # 표시 이름
    tier: str             # "silver" | "gold" | "prismatic"
    description: str      # 효과 설명
    effect_type: str      # "passive" | "trigger"


SILVER_AUGMENTS: list[Augment] = [
    Augment(
        id="economist",
        name="경제학자",
        tier="silver",
        description="이자 수입 상한 5 → 6골드",
        effect_type="passive",
    ),
    Augment(
        id="suit_mystery",
        name="수트의 신비",
        tier="silver",
        description="가장 많이 보유한 수트 시너지 카운트 +1 (영구)",
        effect_type="passive",
    ),
    Augment(
        id="lucky_shop",
        name="행운의 상점",
        tier="silver",
        description="매 라운드 상점 공개 +1장 (5 → 6장)",
        effect_type="passive",
    ),
]


class AugmentPool:
    def offer_augments(self, count: int = 3) -> list[Augment]:
        """count개 선택지 제공"""
        return SILVER_AUGMENTS[:count]

    def get_augment(self, augment_id: str) -> Augment | None:
        """id로 증강체 조회"""
        for aug in SILVER_AUGMENTS:
            if aug.id == augment_id:
                return aug
        return None
