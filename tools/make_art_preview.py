"""assets/images/<캐릭터>/<캐릭터>.json을 모두 읽어 art_preview.html을 만든다 (동작을 실제 fps로 재생, design.md §3).

    python tools/make_art_preview.py
    python tools/make_art_preview.py --help

캐릭터 한국어 이름은 data/art/prompts.json의 characters.<캐릭터>.name에서 (없으면 영어 이름 그대로).
결과는 저장소 뿌리의 art_preview.html (todo.html에서 링크).
"""
import json
import sys

from art_common import PROMPTS_PATH, ROOT, setup_console, usage, wants_help

OUT = ROOT / "art_preview.html"

# 자주 쓰는 동작의 한국어 이름 (없으면 동작 이름 그대로)
ACTIONS = {"idle": "기본", "attack": "공격", "hit": "피격", "death": "쓰러짐", "walk": "이동", "swim": "헤엄",
           "fly": "날기", "cast": "빛 쏘기", "produce": "만들기", "spawn": "나타남"}

# 게임에서 캐릭터 키 (px). 자리 원 지름 88(GameConfig.slotRadius × 2) 안에 들어가는 크기.
GAME_HEIGHT = 80
SLOT_DIAMETER = 88

PAGE = """<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>등대 지키기 아트</title>
<style>
:root{--bg:#0b1a33;--card:#13264a;--ink:#eef3ff;--muted:#a9b7d6;--line:#24406e;--beam:#ffe38a;--beam-soft:#2a3f66;--sea1:#1b2e57;--sea2:#050d1f}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 system-ui,"Malgun Gothic",sans-serif}
main{max-width:1180px;margin:0 auto;padding:28px 16px 64px}
h1{margin:0 0 4px;font-size:1.7rem}
h2{font-size:1.25rem;margin:32px 0 12px;padding-top:16px;border-top:2px solid var(--beam)}
a{color:var(--beam)}
.muted{color:var(--muted);font-size:.92rem}
.bar{position:sticky;top:0;z-index:2;background:var(--bg);padding:10px 0;display:flex;flex-wrap:wrap;gap:8px;align-items:center;border-bottom:1px solid var(--line)}
.bar button{font:inherit;font-size:.92rem;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:999px;padding:4px 14px;cursor:pointer}
.bar button[aria-pressed="true"]{background:var(--beam);border-color:var(--beam);color:#13264a}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
.stage{position:relative;background:linear-gradient(var(--sea1),var(--sea2));display:flex;align-items:center;justify-content:center;height:240px}
.stage canvas{display:block;width:240px;height:240px;position:relative}
.stage.small::before{content:'';position:absolute;left:50%;top:50%;width:__SLOT__px;height:__SLOT__px;margin:-__HALF__px 0 0 -__HALF__px;border-radius:50%;border:2px solid rgba(255,213,138,.7);background:rgba(255,213,138,.15)}
.meta{padding:8px 12px;font-size:.9rem;display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
.meta b{font-size:1rem}
.strip{display:flex;overflow-x:auto;gap:2px;padding:0 12px 10px}
.strip span{flex:0 0 auto;width:34px;height:34px;border-radius:4px;background-repeat:no-repeat;background-color:var(--beam-soft);outline:2px solid transparent;outline-offset:-2px}
.strip span.on{outline-color:var(--beam)}
.strip span.ev{box-shadow:inset 0 -4px 0 #ff9a4a}
code{background:var(--beam-soft);padding:1px 6px;border-radius:4px;font-size:.88em}
</style>
</head>
<body>
<main>
  <h1>등대 지키기 · 아트 미리보기</h1>
  <p class="muted"><a href="todo.html">할 일 목록</a> · <a href="preview.html">게임 미리보기</a> · <a href="worklog.html">작업 기록</a> ·
    Blender 컷아웃으로 렌더한 스프라이트 시트를 실제 fps로 재생한다. 아래 띠의 주황 밑줄은 이벤트 프레임(발사·생산·피해).</p>
  <div class="bar">
    <button data-speed="1" aria-pressed="true">실제 속도</button>
    <button data-speed="0.25">¼ 느리게</button>
    <button id="pause">일시정지</button>
    <button id="step">한 프레임</button>
    <button id="size" aria-pressed="false">게임 크기로 보기</button>
  </div>
  <div id="root"></div>
  <p class="muted" id="empty" hidden>아직 시트가 없다 (bash tools/build_sprites.sh &lt;캐릭터&gt;).</p>
</main>
<script>
const DATA = __DATA__;
const NAMES = __NAMES__, ACTIONS = __ACTIONS__;
const GAME_HEIGHT = __GAME_HEIGHT__;  // 게임에서 캐릭터 키 (자리 원 안)
let speed = 1, paused = false, gameSize = false;
const players = [];
document.getElementById('empty').hidden = DATA.length > 0;

for (const ch of DATA) {
  const h2 = document.createElement('h2');
  h2.textContent = `${NAMES[ch.character] || ch.character} (${ch.character})`;
  const grid = document.createElement('div'); grid.className = 'grid';
  for (const [name, a] of Object.entries(ch.actions)) {
    const card = document.createElement('div'); card.className = 'card';
    const stage = document.createElement('div'); stage.className = 'stage';
    const cv = document.createElement('canvas'); cv.width = ch.frame[0]; cv.height = ch.frame[1];
    stage.append(cv);
    const meta = document.createElement('div'); meta.className = 'meta';
    meta.innerHTML = `<span><b>${ACTIONS[name] || name}</b> <code>${name}</code></span>` +
      `<span>${a.frames}프레임 · ${a.fps}fps · ${a.loop ? '반복' : '한 번'}${a.event ? ` · 이벤트 ${a.event}` : ''}</span>`;
    const strip = document.createElement('div'); strip.className = 'strip';
    const src = `assets/images/${ch.character}/${name}.webp`;
    for (let i = 0; i < a.frames; i++) {
      const s = document.createElement('span');
      s.style.backgroundImage = `url(${src})`;
      s.style.backgroundSize = `${34 * a.frames}px 34px`;
      s.style.backgroundPosition = `${-34 * i}px 0`;
      if (a.event === i + 1) s.classList.add('ev');
      strip.append(s);
    }
    card.append(stage, meta, strip); grid.append(card);
    const img = new Image(); img.src = src;
    players.push({ ch, a, cv, ctx: cv.getContext('2d'), img, stage, strip, frame: 0, t: 0, hold: 0 });
  }
  document.getElementById('root').append(h2, grid);
}

function draw(p) {
  const [w, h] = p.ch.frame;
  p.ctx.clearRect(0, 0, w, h);
  if (p.img.complete) p.ctx.drawImage(p.img, p.frame * w, 0, w, h, 0, 0, w, h);
  [...p.strip.children].forEach((s, i) => s.classList.toggle('on', i === p.frame));
}
function advance(p) {
  if (p.frame + 1 < p.a.frames) p.frame++;
  else if (p.a.loop) p.frame = 0;
  else { p.hold++; if (p.hold > p.a.fps) { p.frame = 0; p.hold = 0; } }  // 한 번 동작은 1초 쉬고 다시
}
let last = performance.now();
function tick(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  for (const p of players) {
    if (!paused) { p.t += dt * speed; const step = 1 / p.a.fps; while (p.t >= step) { p.t -= step; advance(p); } }
    draw(p);
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);

function layout() {
  for (const p of players) {
    p.stage.classList.toggle('small', gameSize);
    // 게임 크기: 캐릭터 키(발 기준점 위쪽)가 GAME_HEIGHT px가 되게 줄이고, 발을 자리 원 가운데에 둔다
    const height = p.ch.anchor[1] - p.ch.bbox[1];
    const s = gameSize ? GAME_HEIGHT / height : 240 / p.ch.frame[1];
    p.cv.style.width = `${p.ch.frame[0] * s}px`; p.cv.style.height = `${p.ch.frame[1] * s}px`;
    p.cv.style.left = gameSize ? `${(p.ch.frame[0] / 2 - p.ch.anchor[0]) * s}px` : '0';
    p.cv.style.top = gameSize ? `${(p.ch.frame[1] / 2 - p.ch.anchor[1]) * s}px` : '0';
  }
}
layout();
document.querySelectorAll('[data-speed]').forEach(b => b.onclick = () => {
  speed = +b.dataset.speed;
  document.querySelectorAll('[data-speed]').forEach(x => x.setAttribute('aria-pressed', x === b));
});
document.getElementById('pause').onclick = e => { paused = !paused; e.target.textContent = paused ? '재생' : '일시정지'; };
document.getElementById('step').onclick = () => { paused = true; document.getElementById('pause').textContent = '재생'; players.forEach(advance); };
document.getElementById('size').onclick = e => { gameSize = !gameSize; e.target.setAttribute('aria-pressed', gameSize); layout(); };
</script>
</body>
</html>
"""


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) != 1:
        usage(__doc__, 2)
    prompts = json.loads(PROMPTS_PATH.read_text(encoding="utf-8")) if PROMPTS_PATH.exists() else {}
    names = {k: v.get("name", k) for k, v in prompts.get("characters", {}).items()}
    data = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "assets" / "images").glob("*/*.json"))]
    html = (PAGE.replace("__DATA__", json.dumps(data, ensure_ascii=False))
            .replace("__NAMES__", json.dumps(names, ensure_ascii=False))
            .replace("__ACTIONS__", json.dumps(ACTIONS, ensure_ascii=False))
            .replace("__GAME_HEIGHT__", str(GAME_HEIGHT))
            .replace("__SLOT__", str(SLOT_DIAMETER))
            .replace("__HALF__", str(SLOT_DIAMETER // 2)))
    OUT.write_text(html, encoding="utf-8")
    print(f"{OUT.name}: 캐릭터 {len(data)}개, 동작 {sum(len(d['actions']) for d in data)}개")


if __name__ == "__main__":
    main()
