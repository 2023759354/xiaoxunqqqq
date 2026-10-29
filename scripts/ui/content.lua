-- 自动生成：原版页面的 <body> 内容与样式表（逐字保留）
local M = {}
M.htmlAttrs = [======[lang="zh-CN"]======]
M.bodyAttrs = [======[]======]
M.css = [======[
:root {
  box-sizing: border-box;
  padding-top: env(safe-area-inset-top, 0px);
  padding-bottom: env(safe-area-inset-bottom, 0px);
  --bg: #2a2042;
  --night: #1b1530;
  --panel: #3a2d52;
  --panel-hi: #4b3c69;
  --ink: #f1e3c2;
  --ink-dim: #b9aacb;
  --brass: #e2b33c;
  --brass-hi: #ffe27a;
  --brass-dk: #9a6f1c;
  --blood: #d8433a;
  --blood-dk: #8e2420;
  --wood: #6b3f22;
  --wood-dk: #4a2a15;
  --moss: #8fe07a;
  --floor: none;
  color-scheme: dark;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg: #241b39; }
}
:root[data-theme="dark"] { --bg: #241b39; }
*, *::before, *::after { box-sizing: border-box; }
html { scroll-padding-top: env(safe-area-inset-top, 0px); }
html, body { height: 100%; margin: 0; }
body {
  background-color: var(--bg);
  background-image: var(--floor);
  background-size: 48px 48px;
  image-rendering: pixelated;
  color: var(--ink);
  font-family: "Silkscreen", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans SC", "Source Han Sans SC", sans-serif;
  font-size: 15px;
  line-height: 1.5;
  -webkit-tap-highlight-color: transparent;
  -webkit-font-smoothing: none;
}
img, canvas { max-width: 100%; }
button { font: inherit; }
.sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }

#app {
  max-width: 1120px; margin: 0 auto; padding: 12px 14px 18px;
  display: flex; flex-direction: column; gap: 12px; min-height: 100%;
}

/* ---------- 顶栏 ---------- */
.hud {
  display: flex; align-items: center; gap: 18px; flex-wrap: wrap;
  padding: 8px 12px;
  background: var(--panel);
  border: 3px solid var(--night);
  box-shadow: inset 0 3px 0 var(--panel-hi), 4px 4px 0 var(--night);
}
.logo {
  margin: 0 auto 0 0; font-size: 22px; font-weight: 900; letter-spacing: 0.08em; color: var(--brass);
  text-shadow: 2px 0 0 var(--night), -2px 0 0 var(--night), 0 2px 0 var(--night), 0 -2px 0 var(--night), 3px 3px 0 var(--blood-dk);
}
.stat { display: flex; align-items: center; gap: 6px; white-space: nowrap; }
.stat .lbl { color: var(--ink-dim); font-size: 13px; }
.stat b { font-weight: 700; font-size: 18px; }
#waveTag { color: var(--blood); font-size: 13px; font-weight: 700; }
#hearts { display: inline-flex; gap: 3px; }
#hearts img { width: 21px; height: 21px; image-rendering: pixelated; }
#goldBox img { width: 22px; height: 22px; image-rendering: pixelated; }
#goldBox b { color: var(--brass-hi); min-width: 2ch; }
#goldBox.bump { animation: bump .35s steps(3); }
@keyframes bump { 50% { transform: translateY(-4px) scale(1.15); } }
.hud-btns { display: flex; gap: 8px; }
.chip {
  font-size: 13px; color: var(--ink); background: var(--night); border: 2px solid var(--panel-hi);
  padding: 4px 10px; cursor: pointer;
}
.chip:hover { border-color: var(--brass); }

/* ---------- 主区 ---------- */
.board { display: grid; grid-template-columns: minmax(0, 1fr) 320px; gap: 16px; align-items: start; }
.field { display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.field-frame {
  position: relative; border: 4px solid var(--night);
  box-shadow: 0 0 0 3px var(--wood-dk), 6px 6px 0 3px rgba(10, 6, 20, 0.55);
  background: #44733a; line-height: 0;
}
#arena { width: 100%; height: auto; display: block; image-rendering: pixelated; image-rendering: crisp-edges; touch-action: none; cursor: grab; }
#arena:active { cursor: grabbing; }
.banner {
  position: absolute; left: 50%; top: 38%; transform: translate(-50%, -50%) scale(0.6);
  opacity: 0; pointer-events: none; white-space: nowrap; line-height: 1.2;
  font-size: clamp(18px, 3.6vw, 32px); font-weight: 900; letter-spacing: 0.06em; color: var(--ink);
  /* 像素风描边：8 方向偏移。像素字体（FusionPixel，12px 设计）在 29px 时
     一个设计像素 ≈ 2.4 个屏幕像素、笔画间隙只有 2 个设计像素；描边偏移一旦
     接近或超过间隙，8 份副本就会把字内部的缝糊死，看起来像「描边没对好」。
     实测真机（DPR 3）：2px 描边 = 6 物理像素，比 5px 的笔画还粗。
     0.75px 对应约 2.25 物理像素，恰好盖住边缘又不吃掉笔画间隙。 */
  text-shadow:
    -0.75px 0 0 var(--night), 0.75px 0 0 var(--night), 0 -0.75px 0 var(--night), 0 0.75px 0 var(--night),
    -0.75px -0.75px 0 var(--night), 0.75px -0.75px 0 var(--night), -0.75px 0.75px 0 var(--night), 0.75px 0.75px 0 var(--night);
  transition: transform .18s steps(3), opacity .18s steps(2);
}
.banner.show { opacity: 1; transform: translate(-50%, -50%) scale(1); }
.banner.gold { color: var(--brass-hi); }
.banner.red { color: #ff8b7c; }
.banner.q1 { color: #7cc4ff; }
.banner.q2 { color: #dba6ff; }
.banner.q3 { color: #ffb24a; }
.banner.q4 { color: #ff6a5a; text-shadow: 3px 0 0 var(--night), -3px 0 0 var(--night), 0 3px 0 var(--night), 0 -3px 0 var(--night), 4px 4px 0 var(--night), 0 0 18px rgba(255, 40, 40, 0.9); }
.qtag.sup { text-shadow: 0 0 6px rgba(255, 52, 52, 0.75); }
.info b.supline { color: #ff7a6a; }
.field-frame.supflash::after {
  content: ''; position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(circle at var(--fx, 25%) var(--fy, 50%), rgba(255, 52, 52, 0.55), rgba(120, 0, 20, 0.28) 40%, transparent 75%);
  animation: supflash .9s steps(6) forwards;
}
@keyframes supflash { 0% { opacity: 1; } 100% { opacity: 0; } }
.modal .qline { padding: 8px 10px; background: var(--night); border-left: 5px solid var(--qc); }
.modal .qline b { color: var(--qc); }
.qtag { font-weight: 700; }
.toast {
  position: absolute; left: 8px; top: 8px; line-height: 1.4; padding: 4px 10px; font-size: 13px;
  background: rgba(27, 21, 48, 0.88); border: 2px solid var(--night); color: var(--ink);
  opacity: 0; transition: opacity .2s steps(2); pointer-events: none; max-width: calc(100% - 16px);
}
.toast.show { opacity: 1; }
.info {
  margin: 0; min-height: 3.2em; padding: 8px 12px; font-size: 14px; line-height: 1.6;
  background: var(--night); border: 3px solid var(--panel); color: var(--ink-dim);
}
.info b { color: var(--ink); }
.info b.up { color: var(--brass-hi); }
.field-meta { display: flex; justify-content: space-between; gap: 12px; font-size: 13px; color: var(--ink-dim); flex-wrap: wrap; }

/* ---------- 老虎机柜 ---------- */
.cabinet {
  position: relative; padding: 14px 14px 16px;
  background: var(--wood);
  border: 4px solid var(--night);
  box-shadow: inset 4px 4px 0 #8a5531, inset -4px -4px 0 var(--wood-dk), 6px 6px 0 rgba(10, 6, 20, 0.55);
  display: flex; flex-direction: column; gap: 12px;
}
.cabinet.jackpot { animation: jolt .45s steps(6); }
@keyframes jolt { 20% { transform: translate(-4px, 2px); } 40% { transform: translate(4px, -2px); } 60% { transform: translate(-3px, -1px); } 80% { transform: translate(2px, 2px); } }
.marquee {
  text-align: center; padding: 6px 8px; background: var(--night); border: 3px solid var(--brass);
  box-shadow: inset 0 0 0 2px var(--brass-dk);
  /* 敌人数量随章节增长：固定高度 + 内部滚动，避免把下面的幸运/开战挤出屏幕 */
  display: flex; flex-direction: column; min-height: 0; flex: 0 1 auto;
  max-height: var(--marqmax, 76px);
}
.marquee .t { display: block; font-size: 12px; color: var(--ink-dim); flex: none; }
.marquee #nextWave {
  display: block; font-size: 14px; font-weight: 700; color: #ff9b8c; line-height: 1.45;
  flex: 1 1 auto; min-height: 0; overflow-y: auto; overflow-x: hidden;
}
.cab-body { display: flex; align-items: stretch; gap: 12px; justify-content: center; }
.reels {
  padding: 6px; background: var(--brass);
  border: 3px solid var(--night);
  box-shadow: inset 3px 3px 0 var(--brass-hi), inset -3px -3px 0 var(--brass-dk);
  line-height: 0;
}
#slot { width: 180px; height: 180px; image-rendering: pixelated; image-rendering: crisp-edges; display: block; border: 3px solid var(--night); }
.lever {
  position: relative; width: 58px; padding: 0; border: 0; background: none; cursor: pointer; color: var(--ink);
  display: flex; flex-direction: column; align-items: center; justify-content: flex-end; gap: 6px;
}
.lever .track {
  position: relative; width: 16px; flex: 1; min-height: 110px; background: var(--night);
  border: 3px solid var(--night); box-shadow: inset 0 0 0 3px #2d2245;
}
.lever .stick {
  position: absolute; left: 50%; bottom: 46%; width: 6px; height: 50%; margin-left: -3px;
  background: linear-gradient(90deg, #dfe7f2 0 50%, #8d9ab2 50%); border: 2px solid var(--night);
  transform-origin: bottom center; transition: transform .1s steps(2);
}
.lever .knob {
  position: absolute; left: 50%; top: -14px; width: 26px; height: 26px; margin-left: -13px;
  background: var(--blood); border: 3px solid var(--night);
  box-shadow: inset 4px 4px 0 #ff8b7c, inset -3px -3px 0 var(--blood-dk);
}
.lever.pulled .stick { animation: pull .5s steps(4); }
@keyframes pull { 30% { transform: scaleY(-0.85); } 70% { transform: scaleY(-0.85); } }
.lever .lbl { font-weight: 700; font-size: 15px; line-height: 1.2; }
.lever small { display: block; font-size: 12px; color: var(--brass-hi); font-weight: 400; }
.lever.poor small { color: #ff9b8c; }
.lever:disabled { cursor: default; opacity: .55; }
.lever:not(:disabled):hover .knob { background: #ef5a4c; }
.lever:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; }
.luck { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; font-size: 13px; padding: 6px 8px; background: var(--wood-dk); border: 2px solid var(--night); }
.luck i { width: 12px; height: 12px; background: var(--night); border: 2px solid #2d2245; display: inline-block; }
.luck i.on { background: var(--brass-hi); border-color: var(--brass-dk); }
.luck small { flex-basis: 100%; color: #e7c9a6; font-size: 12px; }
.luck .stamps { display: inline-flex; align-items: center; gap: 6px; }
.luck .stamps i.on { background: var(--moss); border-color: #3f7a34; }
.btn {
  display: block; width: 100%; padding: 12px 16px; cursor: pointer;
  font-size: 18px; font-weight: 900; letter-spacing: 0.12em; color: #fff;
  background: var(--blood); border: 3px solid var(--night);
  box-shadow: inset 3px 3px 0 #ff8b7c, inset -3px -3px 0 var(--blood-dk), 3px 3px 0 var(--night);
}
.btn:active:not(:disabled) { transform: translate(2px, 2px); box-shadow: inset 3px 3px 0 #ff8b7c, inset -3px -3px 0 var(--blood-dk), 1px 1px 0 var(--night); }
.btn.alt { background: var(--panel-hi); box-shadow: inset 3px 3px 0 #6a5a8e, inset -3px -3px 0 #2d2245, 3px 3px 0 var(--night); letter-spacing: 0.04em; }
.btn:disabled { cursor: default; filter: grayscale(.8); opacity: .6; }
.btn:focus-visible, .chip:focus-visible, .modal button:focus-visible, .choice:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; }

/* ---------- 弹窗 ---------- */
.overlay {
  position: fixed; inset: 0; z-index: 10; display: grid; place-items: center; padding: 16px;
  background: rgba(15, 10, 28, 0.78); overflow-y: auto;
}
.overlay[hidden] { display: none; }
.modal {
  width: min(560px, 100%); max-height: calc(100vh - 32px); max-height: calc(100dvh - 32px); overflow: auto;
  padding: 22px 22px 20px; background: var(--panel); border: 4px solid var(--night);
  box-shadow: inset 0 4px 0 var(--panel-hi), 8px 8px 0 rgba(0, 0, 0, 0.5);
}
.modal h2 {
  margin: 0 0 12px; font-size: 30px; font-weight: 900; letter-spacing: 0.06em; color: var(--brass);
  text-shadow: 3px 3px 0 var(--night);
}
.modal p { margin: 0 0 10px; font-size: 15px; line-height: 1.7; max-width: 38em; }
.modal p b { color: var(--brass-hi); }
.modal .dim { color: var(--ink-dim); font-size: 13px; }
.modal .warn { color: #ff9b8c; }
.modal .keys { color: var(--ink-dim); font-size: 13px; }
.legend { display: flex; flex-wrap: wrap; gap: 6px 14px; margin: 0 0 14px; padding: 10px; background: var(--night); }
.legend span { display: inline-flex; align-items: center; gap: 4px; font-size: 13px; white-space: nowrap; }
.legend.routes { flex-direction: column; gap: 6px; }
.legend.routes > span { display: block; white-space: normal; line-height: 1.6; color: var(--ink-dim); }
.legend.routes b { color: var(--ink); margin-right: 6px; }
.legend.routes span span { display: inline; }
.ico { width: 28px; height: 28px; image-rendering: pixelated; }
#mBtn {
  margin-top: 8px; width: 100%; padding: 12px; cursor: pointer; font-size: 17px; font-weight: 900; letter-spacing: 0.1em;
  color: var(--night); background: var(--brass); border: 3px solid var(--night);
  box-shadow: inset 3px 3px 0 var(--brass-hi), inset -3px -3px 0 var(--brass-dk), 3px 3px 0 var(--night);
}
#mBtn:active { transform: translate(2px, 2px); }
#mBtn[hidden] { display: none; }
.choices { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 4px; }
.choice {
  display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 14px 12px 12px; cursor: pointer;
  font: inherit; text-align: left; color: var(--ink); background: var(--night);
  border: 3px solid var(--panel-hi); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.choice:hover { border-color: var(--brass); }
.choice:active { transform: translate(2px, 2px); }
.choice img.big { width: 64px; height: 64px; image-rendering: pixelated; }
.choice b { font-size: 20px; letter-spacing: 0.06em; color: var(--brass-hi); }
.choice .pass, .choice .sk { align-self: stretch; font-size: 13px; line-height: 1.6; color: var(--ink-dim); }
.choice .sk { color: var(--ink); }
.choice .tag { font-size: 12px; color: var(--ink-dim); letter-spacing: 0.04em; }
.modal.wide { width: min(800px, 100%); }
.choices.n1, .choices.solo { grid-template-columns: 1fr; }
.choices.n3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.choices.n1 .choice, .choice.promote { display: grid; grid-template-columns: 64px 1fr; column-gap: 14px; row-gap: 4px; align-items: center; justify-items: start; }
.choices.n1 .choice img.big { grid-row: span 4; }
.choice.promote img.big { grid-row: span 5; }
.choice.promote { border-color: var(--qc); }
.choice.promote:hover { border-color: var(--brass); }
.choice.promote b { color: var(--qc); }
.choice .cost { align-self: stretch; font-size: 13px; line-height: 1.6; color: #ff9b8c; }
.or { display: flex; align-items: center; gap: 10px; margin: 14px 0 8px; font-size: 13px; color: var(--ink-dim); }
.or::before, .or::after { content: ''; flex: 1; border-top: 3px solid var(--night); }
.modal h3 { margin: 16px 0 8px; font-size: 18px; letter-spacing: 0.06em; color: var(--brass); text-shadow: 2px 2px 0 var(--night); }
.diffs { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.diff {
  display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; cursor: pointer;
  font: inherit; text-align: left; color: var(--ink); background: var(--night);
  border: 3px solid var(--panel-hi); border-left: 7px solid var(--dc); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.diff:hover:not(:disabled) { border-color: var(--brass); border-left-color: var(--dc); }
.diff:active:not(:disabled) { transform: translate(2px, 2px); }
.diff b { font-size: 19px; letter-spacing: 0.08em; color: var(--dc); }
.diff span { font-size: 12px; line-height: 1.55; color: var(--ink-dim); }
.diff small { font-size: 12px; color: var(--brass-hi); }
.diff:disabled { cursor: default; opacity: 0.45; filter: grayscale(0.8); }
.diff:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; }
.newly { padding: 8px 10px; background: var(--night); border: 2px solid var(--brass); color: var(--brass-hi); }
#diffNum { font-size: 15px; }
/* ---------- 主页 ---------- */
.home {
  position: fixed; inset: 0; z-index: 9; display: grid; place-items: center; overflow-y: auto;
  padding: calc(16px + env(safe-area-inset-top, 0px)) 16px calc(16px + env(safe-area-inset-bottom, 0px));
  background-color: var(--bg); background-image: var(--floor); background-size: 48px 48px;
}
.home[hidden] { display: none; }
.home-card {
  width: min(560px, 100%); display: flex; flex-direction: column; align-items: center; gap: 14px; padding: 22px;
  background: var(--panel); border: 4px solid var(--night); box-shadow: inset 0 4px 0 var(--panel-hi), 8px 8px 0 rgba(0, 0, 0, 0.5);
}
.home-art { display: block; width: 100%; height: auto; aspect-ratio: 192 / 56; image-rendering: pixelated; border: 3px solid var(--night); background: var(--night); }
.home-title {
  margin: 2px 0 0; font-size: clamp(40px, 10vw, 64px); font-weight: 900; line-height: 1.1; letter-spacing: 0.12em; color: var(--brass);
  text-shadow: 4px 0 0 var(--night), -4px 0 0 var(--night), 0 4px 0 var(--night), 0 -4px 0 var(--night), 6px 6px 0 var(--night);
}
.home-sub { margin: 0; letter-spacing: 0.16em; color: var(--ink-dim); }
.home-menu { width: min(320px, 100%); display: flex; flex-direction: column; gap: 10px; margin-top: 4px; }
.home-row { display: flex; flex-wrap: wrap; justify-content: center; gap: 8px; }
.btn .rec-tag { display: none; margin-left: 10px; padding: 1px 6px; font-size: 12px; letter-spacing: 0.04em; vertical-align: 2px; color: var(--night); background: var(--brass-hi); }
.btn.rec .rec-tag { display: inline-block; }
.btn.rec { box-shadow: inset 3px 3px 0 #6a5a8e, inset -3px -3px 0 #2d2245, 0 0 0 3px var(--brass), 3px 3px 0 3px var(--night); }
.home-prog { width: 100%; display: flex; flex-direction: column; gap: 6px; }
.hp-row { display: grid; grid-template-columns: auto 1fr auto; align-items: center; gap: 10px; padding: 7px 10px; font-size: 14px; background: var(--night); border-left: 5px solid var(--cc); }
.hp-row b { color: var(--cc); letter-spacing: 0.04em; }
.hp-row small { font-size: 12px; color: var(--ink-dim); }
.hp-row.locked { opacity: 0.55; }
.pips { display: inline-flex; gap: 4px; }
.pips i { width: 12px; height: 12px; border: 2px solid var(--dc); }
.pips i.on { background: var(--dc); }
.home-keys { margin: 0; font-size: 12px; color: var(--ink-dim); }
/* ---------- 新手教程 ---------- */
.coach { position: fixed; inset: 0; z-index: 12; pointer-events: none; }
.coach[hidden] { display: none; }
.coach-hole { position: fixed; border: 3px solid var(--brass-hi); box-shadow: 0 0 0 9999px rgba(15, 10, 28, 0.6); animation: coachPulse 1.2s steps(2) infinite; }
.coach-hole.center { left: 50%; top: 45%; width: 0; height: 0; border: 0; animation: none; }
.coach.nodim .coach-hole { box-shadow: none; }
@keyframes coachPulse { 50% { border-color: var(--ink); } }
.coach-tip { position: fixed; pointer-events: auto; width: min(340px, calc(100vw - 24px)); padding: 12px 14px 10px; background: var(--panel); border: 3px solid var(--brass); box-shadow: 4px 4px 0 var(--night); }
.coach-tip p { margin: 0 0 10px; font-size: 15px; line-height: 1.7; }
.coach-tip b { color: var(--brass-hi); }
.coach-tip .ico { width: 20px; height: 20px; image-rendering: pixelated; vertical-align: -4px; }
.coach-foot { display: flex; align-items: center; gap: 8px; }
.coach-foot small { margin-right: auto; font-size: 12px; color: var(--ink-dim); }
.chip.go { color: var(--night); background: var(--brass); border-color: var(--brass-hi); }
.chip[hidden] { display: none; }
.modal .tut-note { padding: 8px 10px; color: var(--ink); background: var(--night); border-left: 5px solid var(--brass); }
.confirm { display: flex; gap: 10px; margin-top: 16px; }
@media (prefers-reduced-motion: reduce) { .coach-hole { animation: none; } }
.chapters { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-bottom: 10px; }
.chap {
  display: flex; flex-direction: column; gap: 2px; padding: 10px 12px; cursor: pointer;
  font: inherit; text-align: left; color: var(--ink); background: var(--night);
  border: 3px solid var(--panel-hi); border-top: 6px solid var(--cc); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.chap b { font-size: 18px; letter-spacing: 0.06em; color: var(--cc); }
.chap span { font-size: 14px; }
.chap small { font-size: 12px; color: var(--ink-dim); }
.chap.on { border-color: var(--brass); border-top-color: var(--cc); box-shadow: inset 0 0 0 2px var(--brass-dk), 3px 3px 0 rgba(0, 0, 0, 0.5); }
.chap:hover:not(:disabled) { border-color: var(--brass); border-top-color: var(--cc); }
.chap:disabled { cursor: default; opacity: 0.45; filter: grayscale(0.8); }
.chap:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; }
.modal .chdesc { color: var(--ink-dim); font-size: 13px; margin-bottom: 10px; }
.info b.foe { color: #ff9b8c; }
.legend.foes { flex-direction: column; gap: 6px; }
.legend.foes > span { display: block; white-space: normal; line-height: 1.6; color: var(--ink-dim); }
.legend.foes .ico { vertical-align: middle; margin-right: 4px; }
.legend.foes b { color: var(--ink); margin-right: 6px; }
.cx-tabs { display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 6px; }
.cx-tab {
  display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px 6px 8px; cursor: pointer;
  font: inherit; font-size: 15px; color: var(--ink-dim); background: var(--night); border: 3px solid var(--panel-hi);
}
.cx-tab img { width: 24px; height: 24px; image-rendering: pixelated; }
.cx-tab:hover { border-color: var(--brass); }
.cx-tab[aria-selected="true"] { color: var(--brass-hi); border-color: var(--brass); box-shadow: inset 0 0 0 2px var(--brass-dk); }
.cx-tab:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; }
.cx-q { margin: 16px 0 8px; padding: 6px 10px; font-size: 13px; line-height: 1.6; color: var(--ink-dim); background: var(--night); border-left: 5px solid var(--qc); }
.cx-q b { margin-right: 10px; font-size: 16px; color: var(--qc); }
.cx-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
.cx-card {
  display: grid; grid-template-columns: 48px 1fr; column-gap: 10px; align-content: start; padding: 10px;
  background: var(--night); border: 3px solid var(--panel-hi); border-top: 5px solid var(--qc); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.cx-card img { width: 48px; height: 48px; image-rendering: pixelated; grid-row: span 2; align-self: center; }
.cx-card b { align-self: end; font-size: 17px; letter-spacing: 0.04em; color: var(--brass-hi); }
.cx-card .tag { font-size: 12px; color: var(--ink-dim); }
.modal .cx-card p { grid-column: 1 / -1; margin: 6px 0 0; font-size: 13px; line-height: 1.6; color: var(--ink-dim); }
.modal .cx-card p.sk { color: var(--ink); }
.cx-card p.sk i { font-style: normal; font-size: 12px; color: var(--ink-dim); }
@media (max-width: 760px) { .cx-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 520px) { .cx-grid { grid-template-columns: 1fr; } }
.skill-layer { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
.skill-pop {
  position: absolute; transform: translate(-50%, -100%); white-space: nowrap; line-height: 1.2;
  padding: 1px 5px; font-size: clamp(10px, 1.5vw, 13px); font-weight: 900; color: var(--brass-hi);
  background: rgba(27, 21, 48, 0.85); border: 2px solid var(--night);
  animation: skillpop .95s steps(6) forwards;
}
.skill-pop.e { color: #ff9b8c; }
.skill-pop.sup { color: #fff2ea; background: rgba(110, 10, 28, 0.92); border-color: #ff3434; box-shadow: 0 0 10px rgba(255, 52, 52, 0.7); }
.cx-q.sup { background: linear-gradient(90deg, rgba(168, 16, 42, 0.4), var(--night) 70%); }
.cx-card.sup { border-color: #6c2638; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5), 0 0 14px rgba(255, 52, 52, 0.45); }
.cx-card.sup b { color: #ff7a6a; }
@keyframes skillpop { 0% { opacity: 0; margin-top: 6px; } 15% { opacity: 1; margin-top: 0; } 75% { opacity: 1; } 100% { opacity: 0; margin-top: -10px; } }

/* ---------- 局外成长：军魂与军团强化 ---------- */
:root { --soul: #6ef0ff; --soul-dk: #2a8a9a; }
#hForge { position: relative; }
.soul-bal { display: inline-flex; align-items: center; gap: 4px; margin-left: 10px; padding: 1px 7px 1px 4px; font-size: 13px; letter-spacing: 0; color: var(--soul); background: var(--night); vertical-align: 1px; }
.soul-bal img { width: 16px; height: 16px; image-rendering: pixelated; }
#hForge.dot::after { content: ''; position: absolute; right: -7px; top: -7px; width: 12px; height: 12px; background: var(--blood); border: 3px solid var(--night); }
.modal /* ---------- 激励视频广告 ---------- */
.chip.ad { display: flex; flex-direction: column; align-items: center; gap: 2px; line-height: 1.25; text-align: center; color: var(--night); background: var(--brass); border-color: var(--brass-hi); font-weight: 700; }
.chip.ad:hover { background: var(--brass-hi); }
.chip.ad small { font-size: 11px; font-weight: 400; color: var(--brass-dk); }
.chip.ad:disabled { color: var(--ink-dim); background: var(--panel-hi); border-color: var(--panel-hi); cursor: default; }
.chip.ad:disabled small { color: var(--ink-dim); }
.modal .adline { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; padding: 8px 10px; margin: 0 0 10px; background: var(--night); border-left: 5px solid var(--brass); }
.modal .adline span { font-size: 13px; color: var(--ink-dim); }
.modal .adline span b { color: var(--brass-hi); }
.soulline .dbl { margin-left: 6px; padding: 1px 6px; font-size: 12px; color: var(--night); background: var(--soul); }

.soulline { display: flex; align-items: center; gap: 8px; padding: 8px 10px; background: var(--night); border-left: 5px solid var(--soul); color: var(--ink); }
.modal .soulline img { flex: none; width: 20px; height: 20px; image-rendering: pixelated; }
.modal .soulline span { flex: 1 1 0; min-width: 0; }
.modal .soulline b { color: var(--soul); }
.modal .soulline .chip { flex: none; }
.mu-bank { display: flex; align-items: center; gap: 12px; margin: 0 0 12px; padding: 10px 12px; background: var(--night); border: 3px solid var(--panel-hi); border-left: 7px solid var(--soul); }
.mu-bank > img { width: 44px; height: 44px; image-rendering: pixelated; flex: none; }
.mu-bank .num { display: block; font-size: 30px; font-weight: 900; line-height: 1.1; color: var(--soul); }
.mu-bank small { display: block; font-size: 12px; color: var(--ink-dim); }
.modal .mu-bank p { margin: 0 0 0 auto; max-width: 17em; font-size: 12px; line-height: 1.6; color: var(--ink-dim); }
.mu-list { display: flex; flex-direction: column; gap: 10px; margin-top: 10px; }
.mu-row {
  display: grid; grid-template-columns: 44px minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 10px 12px;
  background: var(--night); border: 3px solid var(--panel-hi); border-left: 7px solid var(--soul-dk); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.mu-row.max { border-left-color: var(--brass); }
.mu-ico { width: 44px; height: 44px; image-rendering: pixelated; }
.mu-head { display: flex; align-items: center; flex-wrap: wrap; gap: 4px 10px; }
.mu-head b { font-size: 17px; letter-spacing: 0.04em; color: var(--brass-hi); }
.mu-pips { display: inline-flex; gap: 3px; }
.mu-pips i { width: 10px; height: 10px; border: 2px solid var(--soul-dk); }
.mu-pips i.on { background: var(--soul); border-color: var(--soul); }
.mu-lv { font-size: 12px; color: var(--ink-dim); }
.modal .mu-row p { margin: 3px 0 0; max-width: none; font-size: 13px; line-height: 1.55; color: var(--ink-dim); }
.modal .mu-row p.now { color: var(--ink); }
.modal .mu-row p.next b { color: var(--soul); }
.mu-buy {
  min-width: 96px; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 8px 10px; cursor: pointer;
  font: inherit; font-size: 14px; font-weight: 700; color: var(--night); background: var(--soul); border: 3px solid var(--night);
  box-shadow: inset 3px 3px 0 #bff4ff, inset -3px -3px 0 var(--soul-dk), 3px 3px 0 var(--night);
}
.mu-buy small { display: inline-flex; align-items: center; gap: 3px; font-size: 13px; }
.mu-buy small img { width: 14px; height: 14px; image-rendering: pixelated; }
.mu-buy:active:not(:disabled) { transform: translate(2px, 2px); }
.mu-buy:disabled { cursor: default; color: var(--ink-dim); background: var(--panel-hi); box-shadow: inset 3px 3px 0 #6a5a8e, inset -3px -3px 0 #2d2245, 3px 3px 0 var(--night); }
.mu-foot { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px 12px; margin-top: 14px; font-size: 12px; color: var(--ink-dim); }
@media (max-width: 520px) {
  .mu-bank { flex-wrap: wrap; }
  .modal .mu-bank p { margin: 0; max-width: none; flex-basis: 100%; }
  .mu-row { grid-template-columns: 36px minmax(0, 1fr); gap: 8px 10px; }
  .mu-ico { width: 36px; height: 36px; }
  .mu-buy { grid-column: 1 / -1; flex-direction: row; justify-content: center; gap: 10px; }
}

/* ---------- 开局选兵种 ---------- */
#mBtn:disabled { cursor: default; opacity: 0.5; filter: grayscale(0.8); }
.sq-bar { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin: 4px 0 10px; font-size: 13px; color: var(--ink-dim); }
.sq-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.sq-card {
  position: relative; display: grid; grid-template-columns: 48px minmax(0, 1fr); column-gap: 10px; align-content: start; padding: 10px;
  font: inherit; text-align: left; cursor: pointer; color: var(--ink); background: var(--night);
  border: 3px solid var(--panel-hi); border-top: 5px solid var(--qc); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5);
}
.sq-card:disabled { cursor: default; opacity: 0.45; filter: grayscale(0.8); }
.sq-card img { width: 48px; height: 48px; grid-row: span 3; align-self: center; image-rendering: pixelated; }
.sq-card b { align-self: end; font-size: 17px; letter-spacing: 0.04em; color: var(--qc); }
.sq-card .tag, .sq-card .st { font-size: 12px; color: var(--ink-dim); }
.sq-card .sk { grid-column: 1 / -1; margin-top: 6px; font-size: 12px; line-height: 1.55; color: var(--ink); }
.sq-card .tick { position: absolute; right: 8px; top: 8px; width: 20px; height: 20px; display: none; place-items: center; font-style: normal; font-size: 13px; color: var(--night); background: var(--qc); }
.sq-card:hover { border-color: var(--brass); border-top-color: var(--qc); }
.sq-card:active { transform: translate(2px, 2px); }
.sq-card.on { border-color: var(--qc); box-shadow: inset 0 0 0 2px var(--qc), 3px 3px 0 rgba(0, 0, 0, 0.5); background: #2a2046; }
.sq-card.on .tick { display: grid; }
@media (max-width: 640px) { .sq-grid { grid-template-columns: 1fr; } }
.modal.stk #mBtn { position: sticky; bottom: -12px; z-index: 2; margin-top: 12px; box-shadow: inset 3px 3px 0 var(--brass-hi), inset -3px -3px 0 var(--brass-dk), 3px 3px 0 var(--night), 0 14px 0 10px var(--panel); }

/* ---------- 窄屏（手机） ---------- */
@media (max-width: 860px) {
  #app { padding: 8px 8px 12px; gap: 8px; }
  .board { grid-template-columns: 1fr; gap: 10px; }
  .hud { gap: 10px 14px; padding: 6px 10px; }
  .logo { font-size: 18px; }
  .stat b { font-size: 16px; }
  .cabinet { padding: 10px; gap: 8px; display: grid; grid-template-columns: auto minmax(0, 1fr); grid-template-areas: "marquee marquee" "body side"; }
  .marquee { grid-area: marquee; padding: 4px 8px; }
  .cab-body { grid-area: body; justify-content: flex-start; gap: 8px; }
  .side { grid-area: side; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
  #slot { width: min(150px, 36vw); height: min(150px, 36vw); }
  .reels { padding: 4px; }
  .lever { width: 40px; }
  .lever .knob { width: 22px; height: 22px; margin-left: -11px; top: -12px; }
  .lever .lbl { font-size: 13px; }
  .lever small { font-size: 12px; }
  .lever .track { min-height: 80px; }
  .btn { font-size: 16px; padding: 10px; flex: 1; }
  .luck { padding: 4px 6px; }
  .luck small { font-size: 12px; }
  .info { font-size: 13px; padding: 6px 10px; min-height: 3.4em; }
  .field-frame { box-shadow: 0 0 0 3px var(--wood-dk); }
}
@media (max-width: 640px) {
  .choices, .choices.n3 { grid-template-columns: 1fr; }
  .choice, .choices.n1 .choice, .choice.promote { display: grid; grid-template-columns: 56px 1fr; column-gap: 10px; align-items: center; justify-items: start; }
  .choice img.big { width: 48px; height: 48px; grid-row: span 4; }
}
@media (max-width: 520px) {
  .diffs { grid-template-columns: 1fr; }
}
@media (min-width: 861px) { .side { display: flex; flex-direction: column; gap: 12px; } }
@media (prefers-reduced-motion: reduce) {
  .cabinet.jackpot, .lever.pulled .stick, #goldBox.bump { animation: none; }
  .banner, .toast { transition: none; }
  .skill-pop { animation: none; }
  .field-frame.supflash::after { animation: none; opacity: 0; }
}

/* ---------- 商店与道具（更新） ---------- */
.shop-bar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; margin: 0 0 10px; padding: 8px 10px; font-size: 13px; color: var(--ink-dim); background: var(--night); border-left: 5px solid var(--brass); }
.shop-bar b { color: var(--brass-hi); font-size: 16px; }
.shop-bar img { width: 18px; height: 18px; image-rendering: pixelated; vertical-align: -3px; }
.shop-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
.shop-card { display: grid; grid-template-columns: 40px 1fr; column-gap: 10px; align-content: start; padding: 10px; background: var(--night); border: 3px solid var(--panel-hi); border-top: 5px solid var(--qc); box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.5); }
.shop-card img { width: 40px; height: 40px; image-rendering: pixelated; grid-row: span 2; align-self: center; }
.shop-card b { align-self: end; font-size: 15px; letter-spacing: 0.04em; color: var(--qc); }
.shop-card .tag { font-size: 12px; color: var(--ink-dim); }
.modal .shop-card p { grid-column: 1 / -1; margin: 6px 0 0; font-size: 12px; line-height: 1.6; color: var(--ink); }
.modal .shop-card p .cost { color: #ff9b8c; }
.shop-card .btns { grid-column: 1 / -1; display: flex; gap: 6px; margin-top: 8px; }
.shop-card .btns .chip { flex: 1; }
.shop-card.special { border-color: var(--brass); }
.shop-card.locked { border-color: var(--brass-hi); }
.shop-card.sold { opacity: 0.4; filter: grayscale(0.8); }
.chip:disabled { cursor: default; opacity: 0.5; }
.chip.on { color: var(--night); background: var(--brass-hi); border-color: var(--brass); }
.inv { display: flex; flex-wrap: wrap; gap: 8px; }
.inv-item { display: inline-flex; align-items: center; gap: 6px; padding: 4px 6px 4px 4px; font-size: 13px; background: var(--night); border: 2px solid var(--panel-hi); border-left: 4px solid var(--qc); }
.inv-item img { width: 24px; height: 24px; image-rendering: pixelated; }
.inv-item .chip { padding: 2px 6px; font-size: 12px; }
.inv-empty { font-size: 12px; color: var(--ink-dim); }
.itembar { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; padding: 6px 8px; font-size: 12px; background: var(--wood-dk); border: 2px solid var(--night); }
.itembar .lbl { color: #e7c9a6; margin-right: 2px; }
.itembar .rel { width: 22px; height: 22px; image-rendering: pixelated; }
.itembar .sep { flex-basis: 100%; height: 0; }
.itembar .cons { display: inline-flex; align-items: center; padding: 2px; cursor: pointer; background: var(--night); border: 2px solid var(--panel-hi); }
.itembar .cons img { width: 22px; height: 22px; image-rendering: pixelated; }
.itembar .cons:hover:not(:disabled) { border-color: var(--brass); }
.itembar .cons:disabled { cursor: default; opacity: 0.45; }
.itembar .slot0 { width: 26px; height: 26px; border: 2px dashed #6b4527; display: inline-block; }
.rules { margin: 0 0 12px; padding: 8px 10px; font-size: 13px; line-height: 1.6; background: var(--night); border-left: 5px solid var(--qc); }
.rules b { color: var(--qc); margin-right: 6px; }
.rules p { margin: 0; }
.rulebar { font-size: 12px; line-height: 1.5; padding: 4px 8px; color: #e7c9a6; background: var(--wood-dk); border: 2px solid var(--night); }
.rulebar b { color: var(--brass-hi); margin-right: 4px; }
.pick-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.pick-unit { display: grid; grid-template-columns: 32px 1fr; column-gap: 8px; align-items: center; padding: 6px 8px; cursor: pointer; font: inherit; font-size: 13px; text-align: left; color: var(--ink); background: var(--night); border: 3px solid var(--panel-hi); }
.pick-unit img { width: 32px; height: 32px; image-rendering: pixelated; grid-row: span 2; }
.pick-unit small { font-size: 12px; color: var(--ink-dim); }
.pick-unit:hover { border-color: var(--brass); }
@media (max-width: 760px) { .shop-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 520px) { .shop-grid, .pick-list { grid-template-columns: 1fr; } }

/* ---------- 自适应排版（更新）：game/layout.lua 按屏幕算好尺寸写进 --aw --slot 等变量 ---------- */
:root[data-lay] { padding: 0; }
:root[data-lay] body { overflow: hidden; }
:root[data-lay] #app { max-width: none; margin: 0; height: 100%; min-height: 0; overflow: hidden; padding: var(--pt) var(--prc) var(--pb) var(--plc); gap: var(--gap); }
/* 灵动岛分段避让：只有顶栏和左右两栏的「顶部那一段」让出胶囊宽度，
   其余内容（战场、下方各栏）贴到屏幕边缘，把宽度尽可能留给内容。
   顶栏放进左列（data-hud="D"）时不加这层 margin —— 它已经由 data-capover 分段处理。 */
:root[data-lay][data-island]:not([data-hud="D"]):not([data-hud="S"]) .hud { margin: 0 var(--prh) 0 var(--plh); }
/* 胶囊侧的顶栏再收掉自身内边距：--plh / --prh 已经是「胶囊外沿」，
   再叠加 12px 内边距就会在胶囊和文字之间空出一条（横屏 iPhone 左栏偏空的原因）。
   胶囊在右时只收右边，左边是普通圆角边（EDGE_W），保留 8px 不能贴死。 */
:root[data-lay][data-island] .hud { padding-left: 4px; }
:root[data-lay][data-island][data-island-r] .hud { padding-left: 12px; padding-right: 4px; }
/* 灵动岛凹槽：胶囊在横屏时位于左侧、垂直居中，只覆盖屏幕中间那一段高度。
   胶囊上下的面板没有遮挡，直接铺到屏幕最边缘把宽度用满；只有与胶囊纵向重叠的
   面板才向右让出胶囊宽度（--pisL）。以前是整列让位，左列宽度被砍掉 48px，
   战斗统计的数字就挤到换行、左侧文字被裁掉。 */
:root[data-lay][data-island] .detail-col,
:root[data-lay][data-island] .side-col { padding-top: 0; }
:root[data-lay][data-island] .detail-col > *:first-child,
:root[data-lay][data-island] .side-col > *:first-child { margin-top: 0; }
/* 列本身贴屏幕边缘（--plc / --prc 是圆角边距，比安全区小得多），
   只有和胶囊重叠的那一段用下面的分段规则让位。 */
:root[data-lay][data-island] .detail-col { padding-left: 0; padding-right: 2px; }
:root[data-lay][data-island][data-island-r] .detail-col { padding-left: 0; padding-right: 0; }
/* 胶囊在右：右侧那一列同理 */
:root[data-lay][data-island][data-island-r] .side-col { padding-right: 0; }
/* 分段让位：左列里与胶囊纵向重叠的「那一块」才向右缩进胶囊宽度。
   按元素在列内的实际位置判断做不到纯 CSS，所以这里交给 layout.lua 标记
   data-capover（见 LAYOUT.place）：被打上标记的面板让位，其余贴边。
   规则放在最后，保证能覆盖上面的 padding-left: 0。 */
:root[data-lay][data-island] .detail-col > [data-capover] { margin-left: var(--pisL); }
:root[data-lay][data-island][data-island-r] .side-col > [data-capover] { margin-right: var(--pisR); }
:root[data-lay] .hud { gap: 3px 10px; padding: 4px 8px; box-shadow: inset 0 2px 0 var(--panel-hi), 3px 3px 0 var(--night); }
:root[data-lay] .logo { display: none; }
:root[data-lay] .stat { gap: 4px; }
:root[data-lay] .stat .lbl { font-size: 12px; }
:root[data-lay] .stat b { font-size: 14px; }
:root[data-lay] #diffNum { font-size: 13px; }
:root[data-lay] #waveTag { font-size: 12px; }
:root[data-lay] #hearts img { width: 16px; height: 16px; }
:root[data-lay] #goldBox img { width: 18px; height: 18px; }
:root[data-lay] .hud-btns { gap: 4px; flex-wrap: wrap; }
:root[data-lay] .hud .chip { font-size: 12px; padding: 2px 7px; }
:root[data-lay] .field-frame { flex: none; width: var(--aw); border-width: 3px; box-shadow: 0 0 0 2px var(--wood-dk), 4px 4px 0 2px rgba(10, 6, 20, 0.5); }
:root[data-lay] .field-meta { display: none; }
:root[data-lay] .info { font-size: 13px; line-height: 1.55; padding: 5px 9px; min-height: 0; overflow: auto; }
:root[data-lay] .rulebar { font-size: 12px; padding: 2px 6px; }
:root[data-lay] .skill-pop { font-size: var(--popfs, 10px); padding: 0 3px; border-width: 1px; background: rgba(27, 21, 48, 0.72); letter-spacing: 0.02em; }
:root[data-lay] .cabinet { padding: 8px; gap: 6px; }
:root[data-lay] .marquee { padding: 3px 8px; }
:root[data-lay] .marquee .t { font-size: 12px; }
:root[data-lay] .marquee #nextWave { font-size: 13px; line-height: 1.35; }
:root[data-lay] #slot { width: var(--slot); height: var(--slot); }
:root[data-lay] .reels { padding: 4px; }
:root[data-lay] .cab-body { gap: 8px; }
:root[data-lay] .lever { width: 48px; }
:root[data-lay] .lever .knob { width: 22px; height: 22px; margin-left: -11px; top: -12px; }
:root[data-lay] .lever .lbl { font-size: 13px; }
:root[data-lay] .lever small { font-size: 12px; }
:root[data-lay] .lever .track { min-height: 60px; }
:root[data-lay] .side { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
/* 幸运 / 集点：压成两行紧凑排版，避免把下方「开战」挤出屏幕 */
:root[data-lay] .luck { padding: 3px 5px; font-size: 11px; gap: 2px 4px; line-height: 1.25; flex-wrap: wrap; }
:root[data-lay] .luck small { font-size: 10px; line-height: 1.2; }
:root[data-lay] .luck .stamps { flex-basis: 100%; flex-wrap: nowrap; gap: 4px; min-width: 0; }
:root[data-lay] .luck .stamps small { flex-basis: auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
:root[data-lay] .luck .stamps.off { color: #b89a7a; }
:root[data-lay] .itembar { padding: 4px 6px; gap: 3px; }
:root[data-lay] .itembar .rel { width: 18px; height: 18px; }
:root[data-lay] .itembar .cons img { width: 18px; height: 18px; }
:root[data-lay] .itembar .slot0 { width: 22px; height: 22px; }
:root[data-lay] .reels { align-self: center; }
:root[data-lay] .luck > small { display: none; }
:root[data-lay] .luck .lx { display: none; }
.luck .lkv { font-style: normal; font-size: 12px; color: var(--brass-hi); }
:root[data-wide] .luck > small { display: block; }
:root[data-wide] .luck .lx { display: inline; }
:root[data-lay] .btn { font-size: 16px; padding: 9px 10px; }
/* ===== 第四次更新：三种排法（A 三栏 / B 两栏 / P 竖排），尺寸由 game/layout.lua 求解 ===== */
.detail-col, .field-bar, .act-row { display: none; }
:root[data-lay] #app { display: flex; flex-direction: column; }
:root[data-lay] .board { display: flex; gap: var(--gap); min-height: 0; }
:root[data-lay] .info { flex: 1 1 0; min-height: 0; overflow: auto; }
:root[data-lay] .field-frame { align-self: flex-start; }
/* 横屏（A / B）：并排的几栏，全部撑满安全区以内的高度 */
:root[data-lay="A"] .board, :root[data-lay="B"] .board { flex-direction: row; flex: none; height: var(--ih); align-items: stretch; }
:root[data-hud="T"] #app > .hud { flex: none; flex-wrap: nowrap; }
:root[data-hud="T"][data-lay="A"] .board, :root[data-hud="T"][data-lay="B"] .board { height: auto; flex: 1 1 0; }
:root[data-narrow] .hud { gap: 2px 5px; padding: 4px 4px; }
/* 窄左列（横屏手机三栏）：顶栏挤在信息栏上方，每多折一行就吃掉几十像素，
   下面的战斗统计只能露出一两行。这里把顶栏压紧——图标、字号、间距再收一档。 */
:root[data-narrow][data-hud="D"] .hud { gap: 1px 4px; padding: 3px 4px; }
:root[data-narrow][data-hud="D"] #hearts img { width: 13px; height: 13px; }
:root[data-narrow][data-hud="D"] #goldBox img { width: 14px; height: 14px; }
:root[data-narrow][data-hud="D"] .stat b { font-size: 13px; }
:root[data-narrow][data-hud="D"] .stat .lbl { font-size: 11px; }
:root[data-narrow][data-hud="D"] .hud .chip { padding: 2px 5px; }
:root[data-narrow] #diffNum { font-size: 13px; }
:root[data-narrow] .hud .chip { padding: 3px 5px; font-size: 12px; }
:root[data-narrow] .hud-btns { gap: 3px; }
:root[data-narrow] .stat { gap: 2px; }
:root[data-narrow] #hearts img { width: 14px; height: 14px; }
:root[data-narrow] #goldBox img { width: 16px; height: 16px; }
:root[data-lay="A"] .detail-col { display: flex; flex-direction: column; gap: var(--gap); flex: none; width: var(--dw); min-height: 0; min-width: 0; }
:root[data-lay="A"] .field, :root[data-lay="B"] .field { flex: none; width: var(--aw); display: flex; flex-direction: column; gap: var(--gap); min-height: 0; position: relative; }
:root[data-lay="A"] .side-col, :root[data-lay="B"] .side-col { flex: 1 1 0; min-width: 0; display: flex; flex-direction: column; gap: var(--gap); min-height: 0; }
:root[data-lay="A"] .cabinet, :root[data-lay="B"] .cabinet { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; gap: 6px; }
:root[data-lay="A"] .cab-body, :root[data-lay="B"] .cab-body { flex: 1 0 auto; justify-content: center; align-items: center; }
:root[data-lay="A"] .side, :root[data-lay="B"] .side { flex: none; }
/* 开战/抽取按钮永远不能被上面内容挤掉：整块不收缩 */
:root[data-lay] .side .btn { flex: none; }
:root[data-lay] .side .luck { flex: none; }
:root[data-lay="A"] .cab-body > .lever, :root[data-lay="B"] .cab-body > .lever { align-self: center; height: calc(var(--slot) + 20px); max-height: none; }
/* 三栏：战场下方剩下的高度放「下一波敌人」和战场规则 */
:root[data-fbar] .field-bar { display: flex; flex-direction: column; justify-content: center; gap: 4px; flex: 1 1 0; min-height: 0; overflow: hidden; }
:root[data-fbar] .field-bar .marquee { flex: 1 1 auto; display: flex; flex-direction: column; justify-content: center; }
:root[data-lay="B"][data-fbar] .field-bar { flex: none; }
:root[data-fbar] .field-bar .itembar { flex: none; justify-content: center; background: var(--night); border: 3px solid var(--panel); }
:root[data-fbar] .field-bar .itembar .lbl { color: var(--ink-dim); }
:root[data-fbar] .field-bar .itembar .sep { flex-basis: auto; width: 10px; }
/* 圣物 8 格后，战场下方的道具栏要挤进一行：图标和内边距比右侧栏更紧一档。
   8 圣物 + 3 消耗品单行约 300px，横屏 iPhone（可用宽 ~460）不用再折成两行。 */
:root[data-fbar] .field-bar .itembar { gap: 3px; padding: 3px 5px; font-size: 12px; }
:root[data-fbar] .field-bar .itembar .lbl { font-size: 12px; }
:root[data-fbar] .field-bar .itembar .rel { padding: 0; border-width: 2px; }
:root[data-fbar] .field-bar .itembar .rel img { width: 18px; height: 18px; }
:root[data-fbar] .field-bar .itembar .rel0 { width: 20px; height: 20px; }
:root[data-fbar] .field-bar .itembar .cons { padding: 1px; }
:root[data-fbar] .field-bar .itembar .cons img { width: 18px; height: 18px; }
:root[data-fbar] .field-bar .itembar .slot0 { width: 20px; height: 20px; }
/* 确实放不下（非常窄）时才让圣物和消耗品各占一行 */
:root[data-fbar2] .field-bar .itembar { gap: 3px; }
:root[data-fbar2] .field-bar .itembar .sep { flex-basis: 100%; width: auto; height: 0; }
/* 下一波敌人：头像 + 名字 × 数量 */
.marquee #nextWave .nw { display: inline-flex; align-items: center; gap: 3px; margin: 0 4px; white-space: nowrap; vertical-align: top; }
.marquee #nextWave .nw img { width: 20px; height: 20px; image-rendering: pixelated; }
:root[data-hud="D"] .hud, :root[data-hud="S"] .hud { flex: none; }
:root[data-hud="D"] .hud .hud-btns, :root[data-hud="S"] .hud .hud-btns { margin-left: auto; }
/* 竖排（P）：顶栏 → 通栏战场 → 信息 → 老虎机 */
:root[data-lay="P"] .board { flex-direction: column; flex: 1 1 0; }
:root[data-lay="P"] .field { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; gap: var(--gap); position: relative; align-items: center; }
:root[data-lay="P"] .field > * { align-self: stretch; }
:root[data-lay="P"] .field > .field-frame { align-self: center; }
:root[data-lay="P"] .side-col { flex: none; }
:root[data-lay="P"] .cabinet { display: grid; grid-template-columns: auto minmax(0, 1fr); grid-template-areas: "marquee marquee" "items items" "body side"; }
:root[data-lay="P"] .marquee { grid-area: marquee; display: flex; gap: 6px; align-items: baseline; justify-content: center; }
:root[data-lay="P"] .marquee .t { flex: none; }
:root[data-lay="P"] .cab-body { grid-area: body; justify-content: flex-start; }
:root[data-lay="P"] .side { grid-area: side; }
:root[data-lay="P"] .side .btn { margin-top: auto; }
/* 宽一点的老虎机栏：跑马灯一行显示 */
:root[data-wide] .cabinet .marquee { display: flex; gap: 6px; align-items: baseline; justify-content: center; flex-wrap: wrap; }
:root[data-wide] .cabinet .marquee .t { flex: none; }
/* 战斗中信息栏：我方单位的血量和能量 */
.roster { display: flex; flex-wrap: wrap; gap: 4px 6px; margin-top: 4px; }
.roster .ro { display: inline-flex; align-items: center; gap: 3px; padding: 1px 4px 1px 1px; background: rgba(58, 45, 82, 0.6); border-left: 3px solid var(--qc); }
.roster .ro.dead { opacity: 0.35; filter: grayscale(1); }
.roster img { width: 22px; height: 22px; image-rendering: pixelated; }
.roster .bars { display: flex; flex-direction: column; gap: 2px; width: 40px; }
.roster .hpb, .roster .enb { display: block; height: 4px; background: #2d2245; }
.roster .hpb i, .roster .enb i { display: block; height: 4px; background: #6be06b; }
.roster .enb i { background: #3fa8ff; }
/* 主页：矮横屏时左右两栏 */
:root[data-hshort] .home { padding: 8px 12px; }
:root[data-hshort] .home-card { width: min(820px, 100%); display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); column-gap: 18px; row-gap: 8px; align-items: start; padding: 14px; }
:root[data-hshort] .home-art { grid-column: 1; }
:root[data-hshort] .home-title { grid-column: 1; font-size: 40px; text-align: center; }
:root[data-hshort] .home-sub { grid-column: 1; text-align: center; font-size: 13px; }
:root[data-hshort] .home-menu { grid-column: 2; grid-row: 1 / span 3; width: 100%; margin: 0; gap: 8px; }
:root[data-hshort] .home-menu .btn { padding: 8px 12px; font-size: 16px; }
:root[data-hshort] .home-prog { grid-column: 2; gap: 4px; }
:root[data-hshort] .hp-row { padding: 3px 8px; font-size: 12px; }
:root[data-hshort] .home-keys { display: none; }
@media (max-width: 520px) { .home-title { font-size: 44px; } .home-card { padding: 16px; gap: 10px; } }
/* 选关（更新） */
.chapters2 { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 6px; margin-bottom: 8px; }
.chap2 { display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 6px 2px 5px; cursor: pointer; font: inherit; color: var(--ink); background: var(--night);
  border: 2px solid var(--panel-hi); border-top: 4px solid var(--cc); box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.5); min-width: 0; }
.chap2 b { font-size: 18px; line-height: 1.1; color: var(--cc); }
.chap2 span { font-size: 12px; line-height: 1.3; white-space: nowrap; }
.chap2 small { font-size: 12px; color: var(--ink-dim); }
.chap2 .pips { display: inline-flex; gap: 2px; }
.chap2 .pips i { width: 7px; height: 7px; border: 1px solid var(--dc); }
.chap2 .pips i.on { background: var(--dc); }
.chap2.on { border-color: var(--brass); border-top-color: var(--cc); background: #2a2046; box-shadow: inset 0 0 0 1px var(--brass-dk), 2px 2px 0 rgba(0, 0, 0, 0.5); }
.chap2:hover:not(:disabled) { border-color: var(--brass); border-top-color: var(--cc); }
.chap2:disabled { cursor: default; opacity: 0.4; filter: grayscale(0.8); }
.chap2:focus-visible { outline: 3px solid var(--ink); outline-offset: 2px; }
.chhead { display: flex; flex-direction: column; gap: 2px; margin: 0 0 8px; padding: 6px 10px; background: var(--night); border-left: 5px solid var(--cc); }
.chhead b { font-size: 15px; color: var(--cc); letter-spacing: 0.04em; }
.chhead span { font-size: 12px; line-height: 1.55; color: var(--ink-dim); }
.diffs2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.diff2 { display: flex; flex-direction: column; gap: 3px; padding: 7px 10px; cursor: pointer; font: inherit; text-align: left; color: var(--ink); background: var(--night);
  border: 2px solid var(--panel-hi); border-left: 6px solid var(--dc); box-shadow: 2px 2px 0 rgba(0, 0, 0, 0.5); min-width: 0; }
.diff2 .dh { display: flex; align-items: baseline; justify-content: space-between; gap: 6px; }
.diff2 b { font-size: 16px; letter-spacing: 0.06em; color: var(--dc); }
.diff2 em { font-style: normal; font-size: 12px; color: var(--ink-dim); white-space: nowrap; }
.diff2 .dd { font-size: 12px; line-height: 1.5; color: var(--ink-dim); }
.diff2 small { font-size: 12px; color: var(--brass-hi); }
.diff2:hover:not(:disabled) { border-color: var(--brass); border-left-color: var(--dc); }
.diff2:active:not(:disabled) { transform: translate(2px, 2px); }
.diff2:disabled { cursor: default; opacity: 0.45; filter: grayscale(0.8); }
.diff2:focus-visible { outline: 3px solid var(--ink); outline-offset: 2px; }
.modal h3.pickh { margin-top: 4px; }
:root[data-lay] .modal h2 { font-size: clamp(20px, 3vw, 26px); margin-bottom: 8px; }
:root[data-lay] .modal h3 { font-size: 15px; }
:root[data-short] .modal { padding: 10px 14px; }
:root[data-short] .modal h2 { font-size: 19px; margin-bottom: 4px; }
:root[data-short] .modal p { font-size: 13px; line-height: 1.55; margin-bottom: 6px; }
:root[data-short] .overlay { padding: 6px; }
:root[data-short] #mBtn { padding: 7px; font-size: 15px; margin-top: 6px; }
:root[data-short] .chap2 { padding: 3px 2px; }
:root[data-short] .chap2 b { font-size: 14px; }
:root[data-short] .diff2 .dd { display: none; }
/* 组建军团：手机上两列 / 矮横屏三列的紧凑卡片 */
:root[data-lay] .sq-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; }
:root[data-short] .sq-grid, :root[data-wide] .sq-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
:root[data-lay] .sq-card { grid-template-columns: 32px minmax(0, 1fr); column-gap: 6px; padding: 6px; border-top-width: 4px; }
:root[data-lay] .sq-card img { width: 32px; height: 32px; }
:root[data-lay] .sq-card b { font-size: 14px; }
:root[data-lay] .sq-card .tag { font-size: 12px; line-height: 1.4; }
:root[data-lay] .sq-card .st { font-size: 12px; }
:root[data-lay] .sq-card .sk { font-size: 12px; line-height: 1.45; margin-top: 4px; }
:root[data-lay] .sq-card .tick { width: 16px; height: 16px; right: 4px; top: 4px; font-size: 12px; }
:root[data-lay] .rules { font-size: 12px; padding: 5px 8px; margin-bottom: 8px; }
:root[data-lay] .sq-bar { margin: 2px 0 6px; }
/* 装备（更新） */
.eq-list { display: flex; flex-direction: column; gap: 8px; }
.eq-row { display: grid; grid-template-columns: 150px minmax(0, 1fr); gap: 8px; align-items: center; padding: 6px 8px; background: var(--night); border: 2px solid var(--panel-hi); }
.eq-who { display: flex; align-items: center; gap: 6px; font-size: 13px; min-width: 0; }
.eq-who img { width: 32px; height: 32px; image-rendering: pixelated; flex: none; }
.eq-who small { display: block; font-size: 12px; color: var(--ink-dim); }
.eq-slots { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
.eqs { display: flex; align-items: center; gap: 4px; padding: 3px 4px; min-width: 0; background: #2a2046; border-left: 3px solid var(--qc); }
.eqs img { width: 24px; height: 24px; image-rendering: pixelated; flex: none; }
.eqs .eqn { display: flex; flex-direction: column; min-width: 0; flex: 1 1 0; }
.eqs b { font-size: 12px; color: var(--qc); }
.eqs small { font-size: 12px; line-height: 1.35; color: var(--ink-dim); }
.eqs .chip { flex: none; padding: 1px 5px; font-size: 12px; }
.eqs.empty { border-left-color: #4a3a66; opacity: 0.6; }
.eqs.empty i { width: 20px; height: 20px; border: 2px dashed #6a5a8e; flex: none; }
.minis { display: inline-flex; gap: 2px; vertical-align: -3px; margin-left: 4px; }
.minis .mini { width: 14px; height: 14px; image-rendering: pixelated; }
.minis .mini0 { width: 12px; height: 12px; border: 1px dashed #6a5a8e; display: inline-block; }
.inv-item.eqrow img + img { margin-left: 2px; }
.inv-item.eqrow small { color: var(--ink-dim); margin-left: 4px; }
@media (max-width: 640px) {
  .eq-row { grid-template-columns: 1fr; }
  .eq-slots { grid-template-columns: 1fr; }
}
/* 弹窗在手机上收紧字号 */
@media (max-width: 640px) {
  .modal { padding: 14px 14px 12px; }
  .modal h2 { font-size: 22px; margin-bottom: 8px; }
  .modal h3 { font-size: 16px; margin: 10px 0 6px; }
  .modal p { font-size: 14px; line-height: 1.6; }
  .choice b { font-size: 17px; }
  #mBtn { font-size: 16px; padding: 10px; }
  .overlay { padding: 8px; }
}
/* ===== 第三次更新：可读性、单位卡片、圣物栏、紧凑菜单 ===== */
#menuBtn { display: none; }
:root[data-compact] #menuBtn { display: inline-block; }
:root[data-compact] #homeBtn, :root[data-compact] #soundBtn, :root[data-compact] #codexBtn, :root[data-compact] #helpBtn { display: none; }
:root[data-compact] .hud { gap: 2px 8px; }
:root[data-compact] .hud-btns { margin-left: auto; }
.menu-list { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.menu-list .btn { font-size: 16px; padding: 10px 8px; }
/* 字号下限：手机上最小 12px，说明文字 13px */
:root[data-lay] .info { font-size: 13px; }
:root[data-lay] .lever small { font-size: 12px; line-height: 1.2; }
:root[data-lay] .lever .lbl { font-size: 14px; }
:root[data-lay] .stat .lbl { font-size: 12px; }
:root[data-lay] .stat b { font-size: 15px; }
:root[data-lay] #diffNum { font-size: 14px; }
:root[data-lay] .hud .chip { font-size: 13px; padding: 3px 8px; }
:root[data-lay] .marquee #nextWave { font-size: 13px; }
:root[data-lay] .modal p { font-size: 14px; }
:root[data-lay] .pick-unit { font-size: 14px; }
:root[data-lay] .pick-unit small { font-size: 12px; }
:root[data-lay] .shop-card p { font-size: 13px; }
:root[data-lay] .eqs b { font-size: 13px; }
:root[data-lay] .eqs small { font-size: 12px; }
/* 信息栏：单位卡片 */
.ucard { display: flex; flex-direction: column; gap: 4px; }
.uc-head { display: flex; align-items: center; gap: 8px; }
.uc-head img { width: 34px; height: 34px; image-rendering: pixelated; flex: none; background: #2a2046; border: 2px solid var(--panel-hi); }
.uc-nm { display: flex; flex-direction: column; min-width: 0; line-height: 1.35; }
.uc-nm b { font-size: 15px; }
.uc-nm small { font-size: 13px; color: var(--ink); }
.uc-bench { font-style: normal; font-size: 12px; color: #ff9b8c; }
.uc-exp { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.uc-exp small { font-size: 13px; color: var(--ink-dim); }
.uc-exp .supline { color: #ff7a6a; }
.xbar { position: relative; display: block; width: 96px; height: 10px; flex: none; background: #2d2245; border: 2px solid #120d22; }
.xbar i { display: block; height: 100%; background: #8fe07a; }
.xbar em { position: absolute; top: 0; bottom: 0; width: 2px; background: #120d22; }
.uc-eq { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
.uc-eq .lbl { font-size: 13px; color: var(--ink-dim); }
.ueq { display: inline-flex; align-items: center; gap: 4px; padding: 2px 6px 2px 2px; font: inherit; font-size: 13px; color: var(--qc); cursor: pointer; background: #2a2046; border: 2px solid var(--qc); pointer-events: auto; }
.ueq img { width: 24px; height: 24px; image-rendering: pixelated; }
.ueq:disabled { cursor: default; }
.ueq.empty { color: #7a6a9e; border: 2px dashed #5a4a7e; cursor: default; }
.ueq.empty i { width: 24px; height: 24px; display: inline-block; }
.uc-txt { font-size: 13px; line-height: 1.55; }
:root[data-wide] .uc-txt { font-size: 14px; }
.eqd { display: flex; align-items: center; gap: 10px; padding: 6px 8px; margin-bottom: 6px; background: var(--night); border-left: 4px solid var(--qc); }
.eqd img { width: 40px; height: 40px; image-rendering: pixelated; flex: none; }
.eqd > span { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.eqd b { font-size: 16px; color: var(--qc); }
.eqd small { font-size: 13px; color: var(--ink-dim); }
.eqd small.d { color: var(--ink); line-height: 1.5; }
.eqd-btns { display: flex; gap: 8px; flex-wrap: wrap; }
.eqd-btns .chip { font-size: 15px; padding: 6px 12px; }
.eqb { display: flex; flex-direction: column; gap: 3px; flex: none; }
/* 竖排：道具栏在老虎机里单独一行 */
.cabinet > .itembar { grid-area: items; flex-wrap: nowrap; overflow: hidden; }
.cabinet > .itembar .sep { flex-basis: auto; width: 2px; height: 22px; background: #6b4527; margin: 0 3px; }
/* 道具栏：圣物放大、带品质框，可以点开 */
:root[data-lay] .itembar .rel { width: auto; height: auto; }
.hud .chip, .itembar .lbl { white-space: nowrap; flex: none; }
:root[data-lay] .cabinet > .itembar { gap: 3px; padding: 3px 5px; }
:root[data-lay] .cabinet > .itembar .cons { padding: 1px; }
/* 信息栏放在三栏左侧时：道具栏用信息栏的颜色 */
.detail-col .itembar { flex: none; background: var(--night); border: 3px solid var(--panel); }
.detail-col .itembar .lbl { color: var(--ink-dim); }
.detail-col .itembar .rel0, .detail-col .itembar .slot0 { border-color: #4a3a66; }
.detail-col .rulebar, .field-bar .rulebar { background: var(--night); border: 3px solid var(--panel); color: var(--ink-dim); }
.field-bar .marquee { margin: 0; }
/* 三栏的信息栏比较窄（手机）：单位卡片收紧，装备只显示图标（点开看名字和说明） */
.uc-nm small.uc-st { display: flex; flex-wrap: wrap; gap: 0 10px; }
.uc-nm small .st { white-space: nowrap; }
/* 拉杆：给顶上的红球留位置，不压到跑马灯 */
:root[data-lay] .lever { padding-top: 13px; gap: 4px; }
:root[data-lay] .lever small { white-space: nowrap; }
:root[data-dnarrow] .uc-head { gap: 6px; }
:root[data-dnarrow] .uc-head img { width: 32px; height: 32px; }
:root[data-dnarrow] .uc-exp { gap: 2px 6px; }
:root[data-dnarrow] .uc-exp .xbar { width: 100%; }
:root[data-dnarrow] .uc-eq { gap: 4px; }
:root[data-dnarrow] .uc-eq .lbl { flex-basis: 100%; }
:root[data-dnarrow] .ueq { flex: 1 1 0; min-width: 0; justify-content: center; padding: 2px; }
:root[data-dnarrow] .ueq > span { display: none; }
:root[data-dnarrow] .detail-col .info { padding: 5px 7px; }
/* 三栏：左列的信息栏吃掉顶栏和规则条之外的全部剩余高度。
   窄屏（横屏手机）时这一栏只有 ~62px，战斗统计和说明都要滚动才能看全。 */
:root[data-lay="A"] .detail-col > .info { flex: 1 1 auto; min-height: 0; }
/* 第六次更新：窄信息栏（超宽比手机被安全区挤压后常见）——收紧字号与行距，
   让同样的说明文字占更少空间，把宽度让给战场；次要的「新敌人说明」最多显示 2 行。
   注意：自研 CSS 运行时不支持 -webkit-line-clamp，用 max-height + overflow 截断。 */
:root[data-dnarrow] .info { font-size: 12px; line-height: 1.42; padding: 4px 6px; }
:root[data-dnarrow] .rulebar { font-size: 11px; line-height: 1.35; padding: 2px 5px; }
:root[data-dnarrow] .info .foe-desc { display: block; max-height: 3.1em; overflow: hidden; }
.field-bar .itembar .rel0, .field-bar .itembar .slot0 { border-color: #4a3a66; }
/* 窄老虎机栏：拉杆变成转轴下面的按钮，和「开战」并排，转轴可以占满整栏宽 */
:root[data-stack] .act-row { display: flex; gap: 6px; flex: none; }
:root[data-stack] .act-row .btn { flex: 1 1 0; min-width: 0; padding: 8px 4px; letter-spacing: 0.06em; }
:root[data-stack] .act-row .lever { flex: 1 1 0; min-width: 0; width: auto; max-height: none; flex-direction: row; justify-content: center; align-items: center; padding: 4px 6px; gap: 4px;
  color: var(--night); background: var(--brass); border: 3px solid var(--night); box-shadow: inset 3px 3px 0 var(--brass-hi), inset -3px -3px 0 var(--brass-dk), 3px 3px 0 var(--night); }
:root[data-stack] .act-row .lever .track { display: none; }
:root[data-stack] .act-row .lever .lbl { display: flex; flex-direction: column; align-items: center; font-size: 15px; line-height: 1.15; color: var(--night); }
:root[data-stack] .act-row .lever small { color: #5a3a10; }
:root[data-stack] .act-row .lever.poor small { color: var(--blood-dk); }
:root[data-stack] .act-row .lever:active:not(:disabled) { transform: translate(2px, 2px); }
:root[data-stack] .cab-body { justify-content: center; }
/* 第五次更新：窄栏也保留实体拉杆（只有杆和红球，花费写在下面的「抽取」按钮上） */
:root[data-stack] .cab-body { gap: 6px; }
:root[data-stack] .cab-body .lever { width: 24px; flex: none; }
:root[data-stack] .cab-body .lever .lbl { display: none; }
:root[data-stack] .cab-body .lever .track { min-height: 0; }
/* 战场下方的「下一波敌人」：一行 */
:root[data-fbar] .field-bar .marquee { flex-direction: row; flex-wrap: wrap; align-items: center; justify-content: center; gap: 2px 8px; }
:root[data-fbar] .field-bar .marquee .t { flex: none; }
.field-bar .marquee #nextWave { font-size: 14px; }
.field-bar .marquee #nextWave .nw img { width: 26px; height: 26px; }
/* 安全区：弹窗、主页、教程提示都避开刘海 / 灵动岛 / 挖孔和底部横条 */
:root[data-lay] .overlay { padding: calc(8px + env(safe-area-inset-top, 0px)) calc(8px + env(safe-area-inset-right, 0px)) calc(8px + env(safe-area-inset-bottom, 0px)) calc(8px + env(safe-area-inset-left, 0px)); }
:root[data-lay] .modal { max-height: 100%; }
:root[data-lay] .home { padding: calc(8px + env(safe-area-inset-top, 0px)) calc(12px + env(safe-area-inset-right, 0px)) calc(8px + env(safe-area-inset-bottom, 0px)) calc(12px + env(safe-area-inset-left, 0px)); }
/* 竖屏小手机的主页：收紧，一屏放下 */
:root[data-lay="P"][data-hsmall] .home-card { padding: 14px; gap: 8px; }
:root[data-lay="P"][data-hsmall] .home-title { font-size: 40px; }
:root[data-lay="P"][data-hsmall] .home-menu { gap: 8px; }
:root[data-lay="P"][data-hsmall] .home-menu .btn { padding: 9px 12px; font-size: 16px; }
:root[data-lay="P"][data-hsmall] .hp-row { padding: 4px 8px; font-size: 13px; }
:root[data-lay="P"][data-hsmall] .home-keys { display: none; }
:root[data-lay="P"] .shop-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; }
:root[data-lay="P"] .shop-card { padding: 6px; grid-template-columns: 32px 1fr; column-gap: 6px; }
:root[data-lay="P"] .shop-card img { width: 32px; height: 32px; }
:root[data-stack] .act-row .btn { white-space: nowrap; font-size: 15px; letter-spacing: 0.02em; }
/* 准备阶段的阵容列表（信息栏没选单位时） */
.lineup { display: flex; flex-wrap: wrap; gap: 4px; margin-top: 6px; }
.lineup .lu-h { flex-basis: 100%; font-size: 12px; color: var(--ink-dim); }
.lu { display: inline-flex; align-items: center; gap: 3px; padding: 1px 6px 1px 1px; font: inherit; font-size: 12px; line-height: 1.3; cursor: pointer; color: var(--ink); background: rgba(58, 45, 82, 0.6); border: 0; border-left: 3px solid var(--qc); pointer-events: auto; }
.lu img { width: 22px; height: 22px; image-rendering: pixelated; }
.lu.bench { opacity: 0.7; }
/* 窄顶栏（手机）：去掉文字标签，数字和按钮一行放下 */
:root[data-compact] .stat .lbl { display: none; }
:root[data-compact] .hud { gap: 2px 8px; padding: 4px 6px; }
:root[data-compact] .hud .chip { padding: 3px 8px; }
:root[data-compact] #hearts { gap: 1px; }
:root[data-compact] #hearts img { width: 15px; height: 15px; }
:root[data-compact] .hud-btns { flex-wrap: nowrap; margin-left: auto; }
.itembar .rel { display: inline-flex; padding: 1px; cursor: pointer; background: var(--night); border: 2px solid var(--qc); }
.itembar .rel img { width: 24px; height: 24px; image-rendering: pixelated; }
.itembar .rel0 { width: 26px; height: 26px; display: inline-block; border: 2px dashed #6b4527; }
.itembar .cons { border-color: var(--qc); }
:root[data-lay] .itembar .rel img, :root[data-lay] .itembar .cons img { width: 22px; height: 22px; }
:root[data-lay] .itembar .rel0, :root[data-lay] .itembar .slot0 { width: 24px; height: 24px; }
:root[data-lay] .itembar { gap: 4px; font-size: 13px; }
]======]
M.body = [======[

<div id="app">
  <header class="hud">
    <h1 class="logo">拉杆军团</h1>
    <div class="stat"><span class="lbl">难度</span><b id="diffNum">普通</b></div>
    <div class="stat"><span class="lbl">波次</span><b id="waveNum">1/10</b><span id="waveTag"></span></div>
    <div class="stat"><span class="lbl">生命</span><span id="hearts"></span></div>
    <div class="stat" id="goldBox"><img id="coinIcon" alt="金币"><b id="goldNum">12</b></div>
    <div class="hud-btns">
      <button class="chip" id="homeBtn">主页</button>
      <button class="chip" id="soundBtn" aria-pressed="true">声音 开</button>
      <button class="chip" id="equipBtn">装备</button>
      <button class="chip" id="codexBtn">图鉴</button>
      <button class="chip" id="helpBtn">玩法</button>
      <button class="chip" id="menuBtn">菜单</button>
    </div>
  </header>

  <main class="board">
    <div class="detail-col" id="detailCol"></div>
    <section class="field" aria-label="战场">
      <div class="field-frame">
        <canvas id="arena" width="256" height="176" role="img" aria-label="左半边是你的阵地，右半边是下一波敌人，底部木板是备战席"></canvas>
        <div id="skillLayer" class="skill-layer" aria-hidden="true"></div>
        <div id="banner" class="banner" aria-live="assertive"></div>
        <div id="toast" class="toast" aria-live="polite"></div>
      </div>
      <div class="field-bar" id="fieldBar"></div>
      <p id="ruleBar" class="rulebar" hidden></p>
      <p id="info" class="info" aria-live="polite"></p>
      <div class="field-meta"><span id="unitCount"></span><span>左侧阵地参战，底部备战席不参战</span></div>
    </section>

    <div class="side-col" id="sideCol">
    <aside class="cabinet" id="cabinet" aria-label="召唤老虎机">
      <div class="marquee"><span class="t" id="nextLbl">下一波敌人</span><span id="nextWave"></span></div>
      <div class="cab-body">
        <div class="reels"><canvas id="slot" width="72" height="72" role="img" aria-label="3×3 老虎机转轴"></canvas></div>
        <button id="lever" class="lever" aria-label="拉杆召唤">
          <span class="track"><span class="stick"><span class="knob"></span></span></span>
          <span class="lbl">拉杆<small id="costLbl">花费 3 金币</small></span>
        </button>
      </div>
      <div class="side">
        <button id="adSpin" class="chip ad" aria-label="看广告换一次免费拉杆">广告拉杆 +1<small id="adSpinNum"></small></button>
        <div class="luck" id="luck"></div>
        <div class="itembar" id="itemBar"></div>
        <button id="fight" class="btn">开战</button>
      </div>
      <div class="act-row" id="actRow"><button id="spinBtn" class="lever spin-btn" aria-label="抽取（拉杆召唤）"><span class="lbl">抽取<small id="costLbl2">3 金币</small></span></button></div>
    </aside>
    </div>
  </main>
</div>

<div id="home" class="home" hidden>
  <div class="home-card">
    <canvas id="homeArt" class="home-art" width="192" height="56" role="img" aria-label="你的军团：战士、法师、射手，对面是七章的敌人与首领"></canvas>
    <h1 class="home-title">拉杆军团</h1>
    <p class="home-sub">拉杆召唤，吸收升星，转职成军</p>
    <div class="home-menu">
      <button class="btn" id="hPlay">开始游戏</button>
      <button class="btn alt" id="hTut">新手教程<span class="rec-tag">推荐</span></button>
      <button class="btn alt" id="hForge">军团强化<span class="soul-bal" id="hSoul"></span></button>
      <div class="home-row">
        <button class="chip" id="hCodex">图鉴</button>
        <button class="chip" id="hHelp">玩法说明</button>
        <button class="chip" id="hSound" aria-pressed="true">声音 开</button>
      </div>
    </div>
    <div class="home-prog" id="hProg"></div>
    <p class="home-keys">键盘：空格拉杆，回车开战</p>
  </div>
</div>
<div id="coach" class="coach" hidden>
  <div id="coachHole" class="coach-hole"></div>
  <div id="coachTip" class="coach-tip" role="dialog" aria-label="新手教程" aria-live="polite">
    <p id="coachText"></p>
    <div class="coach-foot"><small id="coachStep"></small><button class="chip" id="coachSkip">跳过教程</button><button class="chip go" id="coachNext">下一步</button></div>
  </div>
</div>
<div id="overlay" class="overlay" hidden>
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="mTitle">
    <h2 id="mTitle"></h2>
    <div id="mBody"></div>
    <button id="mBtn"></button>
  </div>
</div>


]======]
return M
