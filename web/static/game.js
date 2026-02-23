/* ── 전역 상태 ──────────────────────────────────────────────────────────────── */
let gameState = null;
let selectedCard = null;  // {type: 'bench'|'shop', index, playerId}

const UIState = {
    LOBBY:    'LOBBY',
    PREP:     'PREP',
    PLACING:  'PLACING',
    RESULT:   'RESULT',
    GAMEOVER: 'GAMEOVER',
};
let uiState = UIState.LOBBY;

/* ── API 통신 레이어 ─────────────────────────────────────────────────────────── */

async function apiCall(method, path, body) {
    const options = {
        method,
        headers: { 'Content-Type': 'application/json' },
    };
    if (body !== undefined) {
        options.body = JSON.stringify(body);
    }
    try {
        const resp = await fetch(path, options);
        const data = await resp.json();
        if (!data.success) {
            showError(data.error || '오류가 발생했습니다');
            return null;
        }
        return data.state;
    } catch (err) {
        showError('서버 연결 오류: ' + err.message);
        return null;
    }
}

async function startGame(numPlayers, names) {
    return apiCall('POST', '/api/start', { num_players: numPlayers, player_names: names });
}

async function getState() {
    return apiCall('GET', '/api/state');
}

async function sendAction(playerId, actionType, payload) {
    const state = await apiCall('POST', '/api/action', {
        player_id: playerId,
        action_type: actionType,
        payload: payload || {},
    });
    if (state) {
        gameState = state;
        updateUI(state);
    }
    return state;
}

async function resetGame() {
    return apiCall('POST', '/api/reset');
}

/* ── 카드 렌더링 헬퍼 ─────────────────────────────────────────────────────────── */

function buildCardSlot(card, dataset, extraClass) {
    const slot = document.createElement('div');
    slot.className = 'card-slot' + (card ? ' filled suit-' + card.suit_name : ' empty') + (extraClass ? ' ' + extraClass : '');

    // data 속성 부여
    for (const [k, v] of Object.entries(dataset || {})) {
        slot.dataset[k] = v;
    }

    if (card) {
        const rankEl = document.createElement('span');
        rankEl.className = 'card-rank';
        rankEl.textContent = card.rank;

        const suitEl = document.createElement('span');
        suitEl.className = 'suit-symbol';
        suitEl.textContent = card.suit_symbol;

        const starsEl = document.createElement('span');
        starsEl.className = 'card-stars';
        starsEl.textContent = '★'.repeat(card.stars);

        const costEl = document.createElement('span');
        costEl.className = 'cost-badge';
        costEl.textContent = card.cost;

        slot.append(rankEl, suitEl, starsEl, costEl);
    } else {
        const empty = document.createElement('span');
        empty.textContent = '[ ]';
        slot.append(empty);
    }
    return slot;
}

/* ── 보드 렌더링 ──────────────────────────────────────────────────────────────── */

function renderBoard(boardData, playerId) {
    const container = document.createElement('div');
    container.className = 'board-container';

    const title = document.createElement('h4');
    title.textContent = '보드';
    container.append(title);

    const lines = [
        { key: 'back',  label: 'BACK',  slots: 5 },
        { key: 'mid',   label: 'MID',   slots: 5 },
        { key: 'front', label: 'FRONT', slots: 3 },
    ];

    for (const { key, label, slots } of lines) {
        const line = document.createElement('div');
        const isFoul = boardData.foul && boardData.foul_lines.includes(key);
        line.className = 'board-line' + (isFoul ? ' foul' : '');
        line.dataset.line = key;
        line.dataset.playerId = playerId;

        const lineLabel = document.createElement('span');
        lineLabel.className = 'board-line-label';
        lineLabel.textContent = label;
        line.append(lineLabel);

        const cards = boardData[key] || [];
        for (let i = 0; i < slots; i++) {
            const card = cards[i] || null;
            const slot = buildCardSlot(card, {
                line: key,
                slot: i,
                playerId,
                type: card ? 'board' : 'empty-slot',
            }, null);

            // 배치 모드에서 빈 슬롯 하이라이트
            if (!card && selectedCard && selectedCard.playerId === playerId) {
                slot.classList.add('droppable');
            }
            // 보드 카드 클릭 이벤트 (회수)
            if (card) {
                slot.addEventListener('click', () => handleBoardCardClick(playerId, key, i));
            } else {
                slot.addEventListener('click', () => handleSlotClick(playerId, key, i));
            }
            line.append(slot);
        }

        // 핸드 타입 레이블
        const strength = boardData.hand_strengths[key];
        if (strength) {
            const handLabel = document.createElement('span');
            handLabel.className = 'hand-label';
            handLabel.textContent = formatHandType(strength);
            line.append(handLabel);
        }
        container.append(line);
    }

    // Foul 경고 메시지
    if (boardData.warnings && boardData.warnings.length > 0) {
        for (const w of boardData.warnings) {
            const warn = document.createElement('div');
            warn.className = 'foul-warning';
            warn.textContent = w;
            container.append(warn);
        }
    }
    return container;
}

/* ── 벤치 렌더링 ──────────────────────────────────────────────────────────────── */

function renderBench(player) {
    const container = document.createElement('div');
    container.className = 'bench-container';

    const title = document.createElement('h4');
    title.textContent = '벤치';
    container.append(title);

    const cards = document.createElement('div');
    cards.className = 'bench-cards';

    if (!player.bench || player.bench.length === 0) {
        const hint = document.createElement('span');
        hint.className = 'bench-empty-hint';
        hint.textContent = '상점에서 카드를 구매하세요';
        cards.append(hint);
    } else {
        player.bench.forEach((card, idx) => {
            const isSelected = selectedCard
                && selectedCard.type === 'bench'
                && selectedCard.index === idx
                && selectedCard.playerId === player.id;

            const slot = buildCardSlot(card, {
                type: 'bench',
                index: idx,
                playerId: player.id,
            }, isSelected ? 'selected' : null);

            slot.addEventListener('click', () => handleBenchCardClick(player.id, idx));
            cards.append(slot);
        });
    }
    container.append(cards);
    return container;
}

/* ── 상점 렌더링 ──────────────────────────────────────────────────────────────── */

function renderShop(player) {
    const container = document.createElement('div');
    container.className = 'shop-container';

    const header = document.createElement('div');
    header.className = 'shop-header';

    const title = document.createElement('h4');
    title.textContent = '상점';
    header.append(title);

    // 새로고침 버튼 (2골드 소모)
    const rollBtn = document.createElement('button');
    rollBtn.className = 'btn btn-warn btn-sm';
    rollBtn.textContent = '새로고침 (2G)';
    rollBtn.disabled = player.gold < 2 || gameState.phase !== 'prep';
    rollBtn.addEventListener('click', () => handleRollShop(player.id));
    header.append(rollBtn);
    container.append(header);

    const shopCards = document.createElement('div');
    shopCards.className = 'shop-cards';

    if (!player.shop_cards || player.shop_cards.length === 0) {
        const hint = document.createElement('span');
        hint.className = 'bench-empty-hint';
        hint.textContent = '상점이 비어있습니다';
        shopCards.append(hint);
    } else {
        player.shop_cards.forEach((card, idx) => {
            const canAfford = player.gold >= card.cost;
            const slot = buildCardSlot(card, {
                type: 'shop',
                index: idx,
                playerId: player.id,
            }, canAfford ? null : 'disabled');

            if (canAfford && gameState.phase === 'prep') {
                slot.addEventListener('click', () => handleShopCardClick(player.id, idx));
            }
            shopCards.append(slot);
        });
    }
    container.append(shopCards);
    return container;
}

/* ── 플레이어 패널 렌더링 ─────────────────────────────────────────────────────── */

function renderPlayer(player) {
    const panel = document.createElement('div');
    panel.className = 'player-panel';
    panel.id = `player-panel-${player.id}`;

    // 플레이어 헤더 (이름 + 스탯)
    const header = document.createElement('div');
    header.className = 'player-header';

    const nameEl = document.createElement('span');
    nameEl.className = 'player-name';
    nameEl.textContent = player.name;
    header.append(nameEl);

    const stats = document.createElement('div');
    stats.className = 'player-stats';

    const hpEl = document.createElement('span');
    hpEl.className = 'stat-item hp';
    hpEl.textContent = `HP: ${player.hp}`;

    const goldEl = document.createElement('span');
    goldEl.className = 'stat-item gold';
    goldEl.textContent = `G: ${player.gold}`;

    const lvEl = document.createElement('span');
    lvEl.className = 'stat-item level';
    lvEl.textContent = `Lv.${player.level}`;

    const streakEl = document.createElement('span');
    streakEl.className = 'stat-item streak';
    if (player.win_streak >= 2) {
        streakEl.textContent = `${player.win_streak}연승`;
    } else if (player.loss_streak >= 2) {
        streakEl.textContent = `${player.loss_streak}연패`;
        streakEl.style.color = 'var(--danger)';
    }

    stats.append(hpEl, goldEl, lvEl, streakEl);
    header.append(stats);
    panel.append(header);

    // 보드
    panel.append(renderBoard(player.board, player.id));
    // 벤치
    panel.append(renderBench(player));
    // 상점
    panel.append(renderShop(player));

    // 준비 완료 버튼
    if (gameState.phase === 'prep') {
        const isReady = gameState.ready_flags && gameState.ready_flags[String(player.id)];
        const readyBtn = document.createElement('button');
        readyBtn.className = 'btn btn-ready' + (isReady ? ' ready' : '');
        readyBtn.textContent = isReady ? '준비 완료!' : '준비';
        readyBtn.disabled = isReady;
        readyBtn.addEventListener('click', () => handleReadyClick(player.id));
        panel.append(readyBtn);
    }

    return panel;
}

/* ── 전체 UI 갱신 ──────────────────────────────────────────────────────────────── */

function renderAll(state) {
    const container = document.getElementById('players-container');
    container.innerHTML = '';
    for (const player of state.players) {
        container.append(renderPlayer(player));
    }
}

function updateUI(state) {
    if (!state) {
        setState(UIState.LOBBY);
        return;
    }

    // 헤더 업데이트
    const roundEl = document.getElementById('round-display');
    if (roundEl) roundEl.textContent = `라운드 ${state.round_num}`;

    const phaseEl = document.getElementById('phase-display');
    if (phaseEl) {
        const phaseMap = { prep: 'PREP', combat: 'COMBAT', result: 'RESULT', end: 'END' };
        phaseEl.textContent = phaseMap[state.phase] || state.phase.toUpperCase();
        phaseEl.className = 'phase-badge ' + (state.phase === 'result' ? 'result' : state.phase === 'end' ? 'end' : '');
    }

    if (state.is_game_over) {
        setState(UIState.GAMEOVER);
        renderGameOver(state);
        return;
    }

    switch (state.phase) {
        case 'prep':
            setState(selectedCard ? UIState.PLACING : UIState.PREP);
            renderAll(state);
            break;
        case 'combat':
        case 'result':
            setState(UIState.RESULT);
            renderAll(state);
            if (state.last_combat_results && state.last_combat_results.length > 0) {
                renderCombatResult(state.last_combat_results, state.players);
                showModal('combat-result-modal');
            }
            break;
        case 'end':
            setState(UIState.GAMEOVER);
            renderGameOver(state);
            break;
        default:
            renderAll(state);
    }
}

/* ── 이벤트 핸들러 ─────────────────────────────────────────────────────────────── */

function handleBenchCardClick(playerId, index) {
    if (gameState.phase !== 'prep') return;

    if (selectedCard
        && selectedCard.type === 'bench'
        && selectedCard.index === index
        && selectedCard.playerId === playerId) {
        // 같은 카드 재클릭 → 선택 해제
        selectedCard = null;
        setState(UIState.PREP);
    } else {
        selectedCard = { type: 'bench', index, playerId };
        setState(UIState.PLACING);
    }
    renderAll(gameState);
}

function handleSlotClick(playerId, line, slot) {
    if (!selectedCard || selectedCard.type !== 'bench') return;
    if (selectedCard.playerId !== playerId) return;

    const cardIndex = selectedCard.index;
    selectedCard = null;
    setState(UIState.PREP);

    sendAction(playerId, 'place_card', { card_index: cardIndex, line });
}

function handleBoardCardClick(playerId, line, slot) {
    if (gameState.phase !== 'prep') return;
    // 보드 카드 클릭 → 벤치로 회수
    sendAction(playerId, 'remove_card', { line, slot });
}

function handleShopCardClick(playerId, index) {
    if (gameState.phase !== 'prep') return;
    sendAction(playerId, 'buy_card', { card_index: index });
}

function handleRollShop(playerId) {
    sendAction(playerId, 'roll_shop', {});
}

function handleReadyClick(playerId) {
    sendAction(playerId, 'ready', {});
}

async function handleNextRound(playerId) {
    const state = await sendAction(playerId, 'next_round', {});
    if (state) {
        selectedCard = null;
        hideModal('combat-result-modal');
    }
}

async function handleStartGame() {
    const selectEl = document.getElementById('num-players-select');
    const numPlayers = parseInt(selectEl.value, 10);
    const nameInputs = document.querySelectorAll('.player-name-input');
    const names = Array.from(nameInputs).map(inp => inp.value.trim()).filter(Boolean);

    const state = await startGame(numPlayers, names);
    if (state) {
        gameState = state;
        document.getElementById('start-screen').classList.remove('active');
        document.getElementById('game-screen').classList.add('active');
        updateUI(state);
    }
}

async function handleReset() {
    await resetGame();
    gameState = null;
    selectedCard = null;
    setState(UIState.LOBBY);
    hideModal('combat-result-modal');
    hideModal('gameover-modal');
    document.getElementById('game-screen').classList.remove('active');
    document.getElementById('start-screen').classList.add('active');
}

/* ── 플레이어 수 변경 시 이름 입력 필드 동적 업데이트 ──────────────────────────── */

function updatePlayerNameInputs(num) {
    const container = document.getElementById('player-names-container');
    container.innerHTML = '';
    for (let i = 0; i < num; i++) {
        const inp = document.createElement('input');
        inp.type = 'text';
        inp.className = 'player-name-input';
        inp.placeholder = `Player ${i + 1}`;
        inp.dataset.index = i;
        container.append(inp);
    }
}

/* ── 전투 결과 모달 렌더링 ─────────────────────────────────────────────────────── */

function renderCombatResult(results, players) {
    const content = document.getElementById('combat-result-content');
    content.innerHTML = '';

    for (const pair of results) {
        const pairEl = document.createElement('div');
        pairEl.className = 'combat-pair';

        const pairHeader = document.createElement('div');
        pairHeader.className = 'combat-pair-header';
        pairHeader.innerHTML = `
            <span>${pair.player_a.player_name}</span>
            <span style="color:var(--muted)">VS</span>
            <span>${pair.player_b.player_name}</span>
        `;
        pairEl.append(pairHeader);

        // 라인별 결과
        const linesEl = document.createElement('div');
        linesEl.className = 'combat-lines';

        const lineOrder = ['back', 'mid', 'front'];
        for (const line of lineOrder) {
            const va = pair.player_a.line_results[line];
            const vb = pair.player_b.line_results[line];

            const aEl = document.createElement('span');
            aEl.className = va > 0 ? 'win' : va < 0 ? 'loss' : 'tie';
            aEl.textContent = va > 0 ? '승' : va < 0 ? '패' : '-';

            const labelEl = document.createElement('span');
            labelEl.className = 'line-label';
            labelEl.textContent = line.toUpperCase();

            const bEl = document.createElement('span');
            bEl.className = vb > 0 ? 'win' : vb < 0 ? 'loss' : 'tie';
            bEl.textContent = vb > 0 ? '승' : vb < 0 ? '패' : '-';

            linesEl.append(aEl, labelEl, bEl);
        }
        pairEl.append(linesEl);

        // 스쿠프 / 훌라 배너
        const banners = [];
        if (pair.player_a.is_scoop) banners.push(`${pair.player_a.player_name} 스쿠프!`);
        if (pair.player_b.is_scoop) banners.push(`${pair.player_b.player_name} 스쿠프!`);
        if (pair.player_a.hula_applied) banners.push(`${pair.player_a.player_name} 훌라×4!`);
        if (pair.player_b.hula_applied) banners.push(`${pair.player_b.player_name} 훌라×4!`);
        if (pair.player_a.stop_applied) banners.push(`${pair.player_a.player_name} 스톱×8!`);
        if (pair.player_b.stop_applied) banners.push(`${pair.player_b.player_name} 스톱×8!`);

        if (banners.length > 0) {
            const banner = document.createElement('div');
            banner.className = 'combat-banner';
            banner.textContent = banners.join('  ');
            pairEl.append(banner);
        }

        // 데미지 정보
        const dmgLine = document.createElement('div');
        dmgLine.className = 'damage-line';
        dmgLine.innerHTML = `
            <span>${pair.player_a.player_name}: <span class="damage-val">-${pair.player_b.damage} HP</span></span>
            <span>${pair.player_b.player_name}: <span class="damage-val">-${pair.player_a.damage} HP</span></span>
        `;
        pairEl.append(dmgLine);
        content.append(pairEl);
    }
}

/* ── 게임 종료 모달 ────────────────────────────────────────────────────────────── */

function renderGameOver(state) {
    const content = document.getElementById('gameover-content');
    if (state.winner) {
        content.innerHTML = `<p style="font-size:1.2rem; text-align:center; margin-bottom:20px;">
            <strong>${state.winner}</strong> 승리!</p>`;
    } else {
        content.innerHTML = '<p style="text-align:center; margin-bottom:20px;">무승부</p>';
    }

    // 최종 순위
    const sorted = [...state.players].sort((a, b) => b.hp - a.hp);
    const rankEl = document.createElement('ul');
    rankEl.style.cssText = 'list-style:none; padding:0; margin-bottom:16px;';
    sorted.forEach((p, i) => {
        const li = document.createElement('li');
        li.style.cssText = 'padding:6px 0; border-bottom:1px solid var(--border); display:flex; justify-content:space-between;';
        li.innerHTML = `<span>${i + 1}위. ${p.name}</span><span>HP: ${p.hp}</span>`;
        rankEl.append(li);
    });
    content.append(rankEl);
    showModal('gameover-modal');
}

/* ── 모달 유틸 ─────────────────────────────────────────────────────────────────── */

function showModal(id) {
    const el = document.getElementById(id);
    if (el) el.classList.remove('hidden');
}

function hideModal(id) {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
}

/* ── UI 상태 전이 ──────────────────────────────────────────────────────────────── */

function setState(newState) {
    uiState = newState;
}

/* ── 에러 토스트 ───────────────────────────────────────────────────────────────── */

let toastTimer = null;
function showError(msg) {
    const toast = document.getElementById('error-toast');
    toast.textContent = msg;
    toast.classList.remove('hidden');
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 3500);
}

/* ── 핸드 타입 한글 변환 ───────────────────────────────────────────────────────── */

function formatHandType(ht) {
    const map = {
        HIGH_CARD:        '하이카드',
        ONE_PAIR:         '원페어',
        TWO_PAIR:         '투페어',
        THREE_OF_A_KIND:  '트리플',
        STRAIGHT:         '스트레이트',
        FLUSH:            '플러시',
        FULL_HOUSE:       '풀하우스',
        FOUR_OF_A_KIND:   '포카드',
        STRAIGHT_FLUSH:   '스트레이트플러시',
        ROYAL_FLUSH:      '로얄플러시',
    };
    return map[ht] || ht;
}

/* ── 초기화 ─────────────────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', () => {
    // 플레이어 수 변경 이벤트
    const numSelect = document.getElementById('num-players-select');
    if (numSelect) {
        numSelect.addEventListener('change', () => {
            updatePlayerNameInputs(parseInt(numSelect.value, 10));
        });
    }

    // 게임 시작 버튼
    const startBtn = document.getElementById('start-btn');
    if (startBtn) {
        startBtn.addEventListener('click', handleStartGame);
    }

    // 새 게임(리셋) 버튼
    const resetBtn = document.getElementById('reset-btn');
    if (resetBtn) {
        resetBtn.addEventListener('click', handleReset);
    }
});
