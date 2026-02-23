import pytest

from src.holdem import (
    PILOT_EVENTS,
    HoldemEvent,
    HoldemState,
    create_holdem_state,
)


class TestHoldemEvent:
    def test_event_has_id_and_phase(self):
        e = PILOT_EVENTS[0]
        assert hasattr(e, "id")
        assert hasattr(e, "phase")
        assert hasattr(e, "effect_type")

    def test_event_frozen(self):
        e = HoldemEvent(id="test", name="테스트", phase="flop", description="설명", effect_type="passive")
        with pytest.raises((AttributeError, TypeError)):
            e.id = "other"

    def test_event_fields(self):
        e = HoldemEvent(id="x", name="이름", phase="flop", description="설명", effect_type="economy")
        assert e.id == "x"
        assert e.name == "이름"
        assert e.phase == "flop"
        assert e.description == "설명"
        assert e.effect_type == "economy"


class TestHoldemState:
    def test_initial_state_empty_active(self):
        hs = HoldemState(stage=1)
        assert hs.active_events == []

    def test_initial_state_stage(self):
        hs = HoldemState(stage=2)
        assert hs.stage == 2

    def test_advance_flop(self):
        hs = create_holdem_state(1)
        hs.advance(1)
        assert len(hs.active_events) == len(hs.flop)

    def test_advance_turn_accumulates(self):
        hs = create_holdem_state(1)
        hs.advance(2)
        expected = len(hs.flop) + (1 if hs.turn else 0)
        assert len(hs.active_events) == expected

    def test_advance_river_accumulates(self):
        hs = create_holdem_state(1)
        hs.advance(3)
        expected = len(hs.flop) + (1 if hs.turn else 0) + (1 if hs.river else 0)
        assert len(hs.active_events) == expected

    def test_has_active_event_true(self):
        hs = HoldemState(stage=1)
        e = HoldemEvent(id="test_id", name="테스트", phase="flop", description="설명", effect_type="passive")
        hs.flop = [e]
        hs.advance(1)
        assert hs.has_active_event("test_id") is True

    def test_has_active_event_false(self):
        hs = HoldemState(stage=1)
        assert hs.has_active_event("nonexistent") is False

    def test_get_active_by_type(self):
        hs = HoldemState(stage=1)
        e = HoldemEvent(id="e1", name="이코노미", phase="flop", description="설명", effect_type="economy")
        hs.flop = [e]
        hs.advance(1)
        result = hs.get_active_by_type("economy")
        assert len(result) == 1

    def test_get_active_by_type_empty(self):
        hs = HoldemState(stage=1)
        assert hs.get_active_by_type("economy") == []

    def test_advance_flop_sets_flop_events(self):
        hs = HoldemState(stage=1)
        e1 = HoldemEvent(id="a", name="A", phase="flop", description="설명", effect_type="suit_boost")
        e2 = HoldemEvent(id="b", name="B", phase="flop", description="설명", effect_type="economy")
        hs.flop = [e1, e2]
        hs.advance(1)
        assert e1 in hs.active_events
        assert e2 in hs.active_events


class TestPilotEvents:
    def test_five_pilot_events(self):
        assert len(PILOT_EVENTS) == 5

    def test_pilot_event_ids(self):
        ids = {e.id for e in PILOT_EVENTS}
        assert "suit_bonus_spade" in ids
        assert "double_interest" in ids
        assert "foul_amnesty" in ids
        assert "scoop_bonus" in ids
        assert "low_card_power" in ids

    def test_pilot_event_phases(self):
        flop_events = [e for e in PILOT_EVENTS if e.phase == "flop"]
        turn_events = [e for e in PILOT_EVENTS if e.phase == "turn"]
        river_events = [e for e in PILOT_EVENTS if e.phase == "river"]
        assert len(flop_events) == 2
        assert len(turn_events) == 2
        assert len(river_events) == 1

    def test_all_events_have_effect_type(self):
        for e in PILOT_EVENTS:
            assert e.effect_type in ("suit_boost", "economy", "foul", "combat")


class TestCreateHoldemState:
    def test_create_returns_holdem_state(self):
        hs = create_holdem_state(1)
        assert isinstance(hs, HoldemState)

    def test_create_stage_set(self):
        hs = create_holdem_state(3)
        assert hs.stage == 3

    def test_create_flop_populated(self):
        hs = create_holdem_state(1)
        assert len(hs.flop) >= 1

    def test_create_turn_set(self):
        hs = create_holdem_state(1)
        assert hs.turn is not None

    def test_create_river_set(self):
        hs = create_holdem_state(1)
        assert hs.river is not None


class TestGameStateHoldem:
    def test_game_state_has_holdem_state(self):
        from src.economy import Player
        from src.game import GameState
        from src.pool import SharedCardPool

        pool = SharedCardPool()
        pool.initialize()
        p1 = Player("p1")
        p2 = Player("p2")
        state = GameState(players=[p1, p2], pool=pool)
        assert hasattr(state, "holdem_state")

    def test_game_state_holdem_state_default_none(self):
        from src.economy import Player
        from src.game import GameState
        from src.pool import SharedCardPool

        pool = SharedCardPool()
        pool.initialize()
        p1 = Player("p1")
        state = GameState(players=[p1], pool=pool)
        # holdem_state는 None이 기본값
        assert state.holdem_state is None
