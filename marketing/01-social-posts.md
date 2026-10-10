# CmdTab — Paste-ready social posts

Replace `[LINK-xxx]` with the UTM link from `00-…` §4. `[ME]` = your personal detail. Only claim what the site already claims. Attach `public/showcase/overview.mp4` / `quick-actions.mp4` / `radial-menu.mp4` or the poster WebPs.

---
## 1. X / Twitter — 3 thread variants (A/B/C: run one per day, keep the winner)

### Thread A — "the 6 Chrome windows" (pain hook)
1/ Cmd+Tab on a Mac switches **apps**.
You don't have 6 apps open. You have 6 Chrome windows, 3 Terminals and 2 Finder windows.
So you Cmd+Tab, then Cmd+` , then squint. Every. Single. Time. 🧵

2/ I got tired of it and built **CmdTab**: a native macOS switcher where every *window* is its own target, with a real preview.
Hold the shortcut → see the window → release. [attach overview.mp4]

3/ Three ways to use it, because people think differently:
• Classic Grid: scan previews
• Command Palette: type "ter", hit return
• Radial Menu: flick in a direction
[attach 3 posters]

4/ You can also act without jumping in: hide, minimise, close or quit straight from the switcher. Tidying 30 windows takes seconds.

5/ Honest bits: needs Accessibility + Screen Recording permission (it can't preview windows without it). Telemetry is off by default. macOS 14+. Private beta now; planned US$12 one-time, no subscription.

6/ You can try the switcher **in your browser** right now, no install: [LINK-x_thread_a]
Join the private beta list there. I'm letting people in in waves.

### Thread B — "show, don't tell" (demo-first)
1/ 12 seconds. Same 9 windows. Two switchers. Left: Cmd+Tab. Right: CmdTab. [side-by-side video — record this; it's the strongest asset]
2/ CmdTab = exact-window switching with live previews, search, and quick actions for macOS.
3/ Try the demo in your browser (no download): [LINK-x_thread_b]

### Thread C — builder story (build-in-public)
1/ I'm [ME: e.g. a solo dev in X] building a Mac window switcher. Signups: 0 → ? in 30 days. I'll post every number, good or bad. Day 1 thread 👇
2/ What exists today: native Swift/AppKit/SwiftUI app, 3 switcher modes, 14-day trial planned. What doesn't: public notarised release (that's the beta's job — I want real Macs testing it).
3/ Today's ask: if you run 3+ browser windows on a Mac, I want your setup. Join the beta: [LINK-x_thread_c]

### Single-tweet bank (post 1/day, reply under every Mac-productivity tweet with the matching one, never spam)
- "Cmd+Tab has been a per-app switcher since 1984-ish Mac OS lineage. Your work isn't per-app anymore." *(delete the date claim if you can't source it)*
- "Hot take: if you've ever pressed Cmd+` more than twice in a row, you have a window-switching problem, not a focus problem."
- "Type 'ter' → Terminal window. Type 'fig' → Figma. Command Palette for your open windows. Beta waitlist: [LINK]"
- "Close 12 windows without ever switching into them. Quick actions in a switcher is the feature I didn't know I needed."
- "Poll: how many windows do you have open right now? <5 / 5–15 / 15–30 / I don't want to talk about it"
- "Things CmdTab will *not* do: record your screen, send your window titles anywhere, or charge a subscription. Things it will: show the right window."

---
## 2. Reddit (read each sub's self-promo rules first; lead with value; disclose you're the dev)

### r/macapps (best fit — Tue/Wed, 9–11 am US ET)
**Title:** I built a window switcher for macOS that switches *windows*, not apps — looking for beta testers
**Body:**
Hey r/macapps, dev here.
My problem: Cmd+Tab shows apps. With 6 Chrome windows and a few Terminals I was always doing Cmd+Tab then Cmd+` then guessing. I built **CmdTab** to treat every window as its own target.
What it does:
- Real window previews (Classic Grid), type-to-find (Command Palette), or Radial Menu
- Hide / minimise / close / quit from inside the switcher
- Current Space, visible Spaces, or all Spaces; picks the display you want
- Native Swift/AppKit/SwiftUI. macOS 14+
What I want you to know up front: it needs Accessibility + Screen Recording permission (previews require it), telemetry is off by default, and it's in private beta — **not a public release yet**. Planned pricing is US$12 one-time (3 Macs), no subscription.
You can try the switcher in a browser demo here: [LINK-reddit_macapps] — and join the beta list there.
I'd love brutal feedback: what would make you replace AltTab/Contexts/Cmd+Tab with this? (I know AltTab is great and free; here's how I think mine differs: …[fill with 2 honest differences].) AMA.

### r/MacOS (alt angle: "Keyboard users")
**Title:** What's your window-switching setup? I'm building a different one — feedback wanted
(Ask the question first, show the project in a comment when asked. Not a pure promo post.)

### r/productivity / r/apple (only if rules allow; use "Showcase" flair)
Short version of the r/macapps body, with the 12-sec side-by-side video.

### Comment playbook
Reply to every comment within 2 h for 48 h. Never argue with AltTab fans — "AltTab is excellent; here's the gap I'm trying to fill" wins threads.

---
## 3. Show HN (Day 6, Thu 8–9 am ET)
**Title:** Show HN: CmdTab – a macOS window switcher with exact-window previews and a command palette
**First comment (post immediately, as the author):**
I'm [ME]. Cmd+Tab on macOS switches apps, which stops working when your work is 15 windows across 4 apps. CmdTab treats each window as a separate target in a single most-recently-used sequence, shows previews, and lets you search/act without switching in.
Technical notes that might interest HN: native Swift/AppKit/SwiftUI; event tap on the main run loop kept non-blocking; Accessibility calls use a 0.25 s timeout so a hung app can't stall the tap; windows are identified as (PID, CGWindowID) pairs; preview failure changes presentation, not membership; the repo has 340+ tests.
Known limits: private beta, not notarised yet, needs Accessibility + Screen Recording, relies on some private APIs with degraded fallbacks documented on the site. I'd love feedback on the permission UX and on edge cases (Stage Manager, fullscreen Spaces, multi-display).
Demo: [LINK-hn_showhn]
*(HN hates marketing language. Keep it technical. Don't ask for upvotes. Don't use "revolutionary".)*

---
## 4. Product Hunt
- **Now:** create a "Coming soon" page → collects followers who are notified at launch (free list growth).
- **Tagline (≤60):** Switch windows, not just apps. For macOS.
- **Description:** CmdTab gives every Mac window its own spot in the switcher — with real previews, a command palette, a radial menu, and quick actions. Private beta open.
- **Maker comment:** Same as the r/macapps body. Ask: "What's your most-open-windows number?"
- Launch day only once there is a downloadable beta; don't launch a waitlist-only product on PH launch day.

---
## 5. Indie Hackers / dev.to / Hashnode (Day 7)
**Title:** Building a Mac window switcher: the 3 permission screens that cost me the most signups (and what I changed)
*(Real, honest post about Accessibility + Screen Recording UX, the AppKit sharing-indicator geometry bug in `Tests/Fixtures/AppKitSharingGeometry/README.md`, exact-window MRU. Technical content earns backlinks and trust. End with the beta link.)*

---
## 6. LinkedIn (personal profile, not company page)
I've lost hours of my life to this: Cmd+Tab → Cmd+` → squint → wrong window.
macOS switches *apps*. Your work happens in *windows*.
So I built CmdTab, a native Mac window switcher. Every window is its own target, with a real preview. You can type to find it, flick through a radial menu, or hide/close windows without opening them.
It's in private beta. If you live in browser tabs, Terminals, and Figma frames, I'd value your feedback: [LINK-linkedin]
*(Tag 3 Mac-heavy colleagues by name and ask them one specific question.)*

---
## 7. Short video scripts (TikTok / Reels / Shorts, ≤20 s, no voiceover needed, captions on)
1. **"POV: 14 windows open."** Frantic Cmd+Tab/Cmd+` footage → cut to CmdTab grid, one hold-and-release → caption "I switch windows, not apps." CTA: "Beta in bio."
2. **"Type a letter, land on the window."** Palette demo → caption "Command palette for your open windows".
3. **"Close 10 windows in 5 seconds."** Quick actions montage.
4. **"I built this because…"** Founder face-cam, 15 s, story of the Cmd+` problem.
5. **"Cmd+Tab vs CmdTab"** split screen.
Post 1/day for 14 days at different times; kill the format that gets <500 views after 5 tries.

---
## 8. Asia-specific (your edge — most Western Mac tools ignore this)
### 小红书 (Xiaohongshu) note — 效率/Mac 标签
**标题：** Mac 多窗口党救星｜Cmd+Tab 切不到想要的窗口？
**正文：**
用 Mac 的都懂：Cmd+Tab 只能切「应用」，不是「窗口」。开了 6 个 Chrome 窗口，还得 Cmd+` 再碰运气 😮‍💨
我自己做了一个原生 macOS 窗口切换器 **CmdTab** ✨
✅ 每个窗口单独预览，所见即所得
✅ 输入几个字母直接跳到目标窗口（命令面板）
✅ 环形菜单，方向感切换
✅ 不用切进去也能隐藏 / 最小化 / 关闭 / 退出
✅ 支持当前桌面 / 所有桌面，多显示器友好
⚠️ 坦白：需要「辅助功能」和「屏幕录制」权限（预览窗口必须），默认不开启遥测。目前是内测，系统要求 macOS 14+。
网页里可以直接试玩 Demo，不用下载 👉 [LINK-xhs_note1]
#Mac #效率工具 #macOS #窗口管理 #独立开发 #内测
*(配图：6 张——痛点截图、Grid、Palette、Radial、快捷操作、内测入口。封面文字：「Cmd+Tab 切不到窗口？」)*

### Bilibili / V2EX / 少数派
- V2EX（分享创造）标题：「做了一个 macOS 窗口切换器，每个窗口独立预览，求内测反馈」，正文用 §2 r/macapps 内容翻译，诚实说明权限与内测状态。
- 少数派投稿角度：「我为什么不再用 Cmd+Tab？—— macOS 窗口切换工具横评（AltTab / Contexts / CmdTab）」。**横评必须公正、可核实**，写明评测日期。
- Bilibili 30–60 s 竖屏演示，标题「Mac 切窗口，我换了这个」。

### Singapore / SEA angle
Post in SG/MY Mac & dev communities (e.g. Telegram/Discord groups, Reddit r/singapore tech threads, Hardwarezone Mac forum) with the founder-story angle. English copy as §2.

---
## 9. Warm network DM (highest-converting channel historically: direct traffic)
> Hey [name] — I built a Mac window switcher (switches *windows*, not apps, with previews). In private beta; you're one of the Mac power-users I'd trust to tell me what's broken. 20 sec to try the demo: [LINK-dm]. If you like it, add your email there and forward it to one friend who lives in 20 windows. Thank you!
Send 40 personal DMs (not a broadcast). Expected: 25–40% click, 10–20% sign up → 4–8 real signups plus feedback.

---
## 10. Reply-guy bank (X/Reddit/Threads, authentic only; max 5/day)
- Someone complaining about Cmd+` → "Same pain — I ended up building a window-level switcher. Happy to share the beta if useful."
- AltTab thread → "AltTab is great. Curious what folks miss in it — I'm collecting that for my own project."
- Mac-setup/desk-tour posts → compliment first, mention only if asked.
