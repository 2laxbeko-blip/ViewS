local MAIN_SRC = [====[
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
if not PlayerGui then return end
local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
local RUN_ID = tostring(os.clock()) .. "-" .. tostring(math.random(1, 1000000000))
ENV.HaiderViewRunId = RUN_ID
local function alive() return ENV.HaiderViewRunId == RUN_ID end
local K = {
VERSION = "2.0",
GUI_NAME = "HaiderViewUI",
SRC_FILE = "HaiderViewServer_src.lua",
DATA_FILE = "HaiderViewServer_settings.json",
PLACE_ID = game.PlaceId,
MAX_PAGES_FULL = 10,
MAX_PAGES_QUICK = 2,
MAX_PAGES_VERIFY = 6,
MAX_PAGES_SCAN = 40,
MIN_GAP = 2.2,
FAIL_COOLDOWN = 5,
STALL_SECONDS = 35,
STALL_NOEVENT = 60,
LOCK_MAX = 150,
VISITED_TTL = 1200,
FAV_STALE = 7200,
HIST_MAX = 120,
EXPORT_HIST = 60,
THEME_COUNT = 4,
}
do
local oldGui = PlayerGui:FindFirstChild(K.GUI_NAME)
if oldGui then oldGui:Destroy() end
end
local UI = {}
local F = {}
local CAPS = { onTeleportSeen = false }
local DEFAULTS = {
ver = 3,
lang = "ar",
themeIndex = 4,
anim = true,
imgBg = "",
imgCircle = "",
aiKey = "",
aiModel = "z-ai/glm-5.3-flash",
aiCtx = true,
autoHide = false,
hideAfter = 20,
activeTab = "main",
windowOpen = false,
mainPos = { 0.5, -180, 0.5, -170 },
mainSize = { 360, 340 },
togglePos = { 0, 16, 0.5, -28 },
toggleSize = { 56, 56 },
autoRefresh = false,
refreshEvery = 25,
verifyBeforeJump = true,
lowGfx = false,
gfxOrig = -1,
webhookUrl = "",
notifyArrival = false,
notifyMatch = false,
capTpSeen = false,
visited = {},
pendingVerify = false,
prevServer = false,
lastServer = false,
games = {},
}
local PROFILE_DEFAULTS = {
maxPlayers = 2,
minPlayers = 1,
maxPing = 300,
minFps = 30,
sortMode = "quality",
boardStat = "",
excludeFull = true,
maxAgeSeconds = 45,
favorites = {},
history = {},
joinStats = {},
hourly = {},
used = 0,
mapSeen = false,
ctrl = { speedOn = false, speed = 32, jumpOn = false, jump = 70, flySpeed = 60 },
esp = { on = false, names = {}, dist = 600, max = 30, arrow = true, npc = false, friends = false },
}
local VALID_TABS = {
main = true, players = true, board = true, find = true, fav = true,
stats = true, filt = true, theme = true, log = true, tools = true, set = true,
ctrl = true, esp = true, ai = true,
}
local function deepCopy(v)
if type(v) ~= "table" then return v end
local out = {}
for k, x in pairs(v) do out[k] = deepCopy(x) end
return out
end
local S = deepCopy(DEFAULTS)
local P = nil
local function canPersist()
return typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
end
local function isNumArray(t, n)
if type(t) ~= "table" or #t ~= n then return false end
for i = 1, n do
if type(t[i]) ~= "number" then return false end
end
return true
end
local function sanitizeRef(v)
if type(v) == "table" and type(v.id) == "string" and v.id ~= "" then
return { id = v.id, placeId = tonumber(v.placeId) or K.PLACE_ID, at = tonumber(v.at) or 0 }
end
return false
end
local function sanitizeProfile(p)
if type(p) ~= "table" then p = {} end
local D = PROFILE_DEFAULTS
p.maxPlayers = math.clamp(tonumber(p.maxPlayers) or D.maxPlayers, 0, 100)
p.minPlayers = math.clamp(tonumber(p.minPlayers) or D.minPlayers, 0, 100)
p.maxPing = math.clamp(tonumber(p.maxPing) or D.maxPing, 1, 5000)
p.minFps = math.clamp(tonumber(p.minFps) or D.minFps, 0, 60)
p.maxAgeSeconds = math.clamp(tonumber(p.maxAgeSeconds) or D.maxAgeSeconds, 5, 600)
if p.sortMode ~= "quality" and p.sortMode ~= "empty" then p.sortMode = "quality" end
if type(p.boardStat) ~= "string" then p.boardStat = "" end
if type(p.excludeFull) ~= "boolean" then p.excludeFull = true end
p.used = tonumber(p.used) or 0
p.mapSeen = (p.mapSeen == true)
local c = (type(p.ctrl) == "table") and p.ctrl or {}
p.ctrl = {
speedOn = (c.speedOn == true),
speed = math.clamp(tonumber(c.speed) or 32, 1, 500),
jumpOn = (c.jumpOn == true),
jump = math.clamp(tonumber(c.jump) or 70, 1, 500),
flySpeed = math.clamp(tonumber(c.flySpeed) or 60, 5, 400),
}
local e = (type(p.esp) == "table") and p.esp or {}
p.esp = {
on = (e.on == true),
names = {},
dist = math.clamp(tonumber(e.dist) or 600, 50, 5000),
max = math.clamp(tonumber(e.max) or 30, 5, 80),
arrow = (e.arrow ~= false),
npc = (e.npc == true),
friends = (e.friends == true),
}
if type(e.names) == "table" then
for _, nm in ipairs(e.names) do
if type(nm) == "string" and #nm >= 2 and #nm <= 30 and #p.esp.names < 20 then
table.insert(p.esp.names, string.lower(nm))
end
end
end
local favs = {}
if type(p.favorites) == "table" then
for _, f in ipairs(p.favorites) do
if type(f) == "table" and type(f.id) == "string" and f.id ~= "" then
table.insert(favs, {
id = f.id,
placeId = tonumber(f.placeId) or K.PLACE_ID,
note = tostring(f.note or ""),
savedAt = tonumber(f.savedAt) or os.time(),
ping = tonumber(f.ping),
miss = tonumber(f.miss) or 0,
fails = tonumber(f.fails) or 0,
})
end
if #favs >= 30 then break end
end
end
p.favorites = favs
local hist = {}
if type(p.history) == "table" then
for _, e in ipairs(p.history) do
if type(e) == "table" and type(e.at) == "number" and type(e.id) == "string" then
local okv, whyv = nil, nil
if type(e.ok) == "boolean" then okv = e.ok end
if type(e.why) == "string" then whyv = e.why end
table.insert(hist, {
at = e.at,
id = e.id,
pl = tonumber(e.pl) or -1,
mx = tonumber(e.mx) or 0,
ok = okv,
why = whyv,
ping = tonumber(e.ping),
sec = tonumber(e.sec),
star = tonumber(e.star),
hr = tonumber(e.hr) or 0,
src = (type(e.src) == "string") and e.src or "list",
})
end
if #hist >= K.HIST_MAX then break end
end
end
p.history = hist
local stats = {}
if type(p.joinStats) == "table" then
for _, js in ipairs(p.joinStats) do
if type(js) == "table" and type(js.sec) == "number" then
table.insert(stats, { sec = js.sec, ping = tonumber(js.ping) or -1, ts = tonumber(js.ts) or 0 })
end
if #stats >= 10 then break end
end
end
p.joinStats = stats
local hourly = {}
if type(p.hourly) == "table" then
for h = 0, 23 do
local cell = p.hourly[tostring(h)]
if type(cell) == "table" and type(cell.s) == "number" and type(cell.n) == "number" and cell.n > 0 then
hourly[tostring(h)] = { s = cell.s, n = math.min(cell.n, 100000) }
end
end
end
p.hourly = hourly
return p
end
local function bindProfile()
if type(S.games) ~= "table" then S.games = {} end
local key = tostring(K.PLACE_ID)
S.games[key] = sanitizeProfile(S.games[key])
S.games[key].used = os.time()
P = S.games[key]
end
local function sanitizeSettings()
S.ver = DEFAULTS.ver
if S.lang ~= "ar" and S.lang ~= "en" then S.lang = "ar" end
S.refreshEvery = math.clamp(tonumber(S.refreshEvery) or DEFAULTS.refreshEvery, 5, 300)
S.themeIndex = math.clamp(math.floor(tonumber(S.themeIndex) or 4), 1, K.THEME_COUNT)
for _, k in ipairs({ "autoRefresh", "verifyBeforeJump", "windowOpen", "lowGfx", "notifyArrival", "notifyMatch", "capTpSeen", "anim", "aiCtx", "autoHide" }) do
if type(S[k]) ~= "boolean" then S[k] = DEFAULTS[k] end
end
if type(S.activeTab) ~= "string" or not VALID_TABS[S.activeTab] then S.activeTab = "main" end
if not isNumArray(S.mainPos, 4) then S.mainPos = deepCopy(DEFAULTS.mainPos) end
if not isNumArray(S.mainSize, 2) then S.mainSize = deepCopy(DEFAULTS.mainSize) end
if not isNumArray(S.togglePos, 4) then S.togglePos = deepCopy(DEFAULTS.togglePos) end
if not isNumArray(S.toggleSize, 2) then S.toggleSize = deepCopy(DEFAULTS.toggleSize) end
if type(S.visited) ~= "table" then S.visited = {} end
if type(S.pendingVerify) ~= "table" then S.pendingVerify = false end
if type(S.webhookUrl) ~= "string" or #S.webhookUrl > 400 then S.webhookUrl = "" end
S.gfxOrig = tonumber(S.gfxOrig) or -1
S.hideAfter = math.clamp(tonumber(S.hideAfter) or 20, 5, 300)
if type(S.aiKey) ~= "string" or #S.aiKey > 200 or string.find(S.aiKey, "%s") then S.aiKey = "" end
if type(S.aiModel) ~= "string" or #S.aiModel > 80 or not string.match(S.aiModel, "^[%w%-%._:/~]+$") then
S.aiModel = DEFAULTS.aiModel
end
if type(S.imgBg) ~= "string" or #S.imgBg > 300 then S.imgBg = "" end
if type(S.imgCircle) ~= "string" or #S.imgCircle > 300 then S.imgCircle = "" end
S.prevServer = sanitizeRef(S.prevServer)
S.lastServer = sanitizeRef(S.lastServer)
if type(S.games) ~= "table" then S.games = {} end
local keys = {}
for k, _ in pairs(S.games) do table.insert(keys, k) end
if #keys > 15 then
table.sort(keys, function(a, b)
local ua = (type(S.games[a]) == "table" and tonumber(S.games[a].used)) or 0
local ub = (type(S.games[b]) == "table" and tonumber(S.games[b].used)) or 0
return ua > ub
end)
for i = 16, #keys do S.games[keys[i]] = nil end
end
for k, v in pairs(S.games) do S.games[k] = sanitizeProfile(v) end
bindProfile()
end
local function saveSettings()
if not canPersist() then return end
pcall(function() writefile(K.DATA_FILE, HttpService:JSONEncode(S)) end)
end
local function loadSettings()
if not canPersist() then return end
pcall(function()
if not isfile(K.DATA_FILE) then return end
local data = HttpService:JSONDecode(readfile(K.DATA_FILE))
if type(data) ~= "table" then return end
local oldVer = tonumber(data.ver) or 1
for k, _ in pairs(DEFAULTS) do
if data[k] ~= nil then S[k] = data[k] end
end
if oldVer < 3 then
S.games = {}
local pkey = tostring(K.PLACE_ID)
local prof = deepCopy(PROFILE_DEFAULTS)
for k, _ in pairs(PROFILE_DEFAULTS) do
if data[k] ~= nil and k ~= "favorites" and k ~= "history" and k ~= "hourly" then prof[k] = data[k] end
end
if oldVer < 2 then prof.minPlayers = math.max(tonumber(prof.minPlayers) or 0, 1) end
S.games[pkey] = prof
if type(data.favorites) == "table" then
for _, f in ipairs(data.favorites) do
if type(f) == "table" then
local fk = tostring(tonumber(f.placeId) or K.PLACE_ID)
if not S.games[fk] then S.games[fk] = deepCopy(PROFILE_DEFAULTS) end
table.insert(S.games[fk].favorites, f)
end
end
end
end
end)
end
loadSettings()
sanitizeSettings()
CAPS.onTeleportSeen = S.capTpSeen
local function resetSettings()
S = deepCopy(DEFAULTS)
bindProfile()
saveSettings()
end
local function ud2(t) return UDim2.new(t[1], t[2], t[3], t[4]) end
local function fmtClock(sec)
sec = math.max(0, math.floor(tonumber(sec) or 0))
local h = math.floor(sec / 3600)
local m = math.floor((sec % 3600) / 60)
local s = sec % 60
if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
return string.format("%02d:%02d", m, s)
end
local LOG = {}
local ERRORS = {}
local function addLog(msg)
table.insert(LOG, 1, os.date("%H:%M:%S") .. "  " .. tostring(msg))
while #LOG > 12 do table.remove(LOG) end
end
local function addError(where, err)
table.insert(ERRORS, 1, os.date("%H:%M:%S") .. " [" .. tostring(where) .. "] " .. tostring(err))
while #ERRORS > 10 do table.remove(ERRORS) end
end
local function safe(where, fn, ...)
local ok, err = pcall(fn, ...)
if not ok then addError(where, err) end
return ok
end
local L = {}
L.ar = {
tab_main = "الرئيسية", tab_players = "اللاعبون", tab_board = "الليدربورد", tab_find = "بحث",
tab_fav = "المفضّلة", tab_stats = "إحصائيات", tab_filt = "الفلاتر", tab_theme = "الثيم",
tab_log = "السجل", tab_tools = "أدوات", tab_set = "الإعدادات",
net_label = "الشبكة", net_ok = "متصل", net_slow = "بطيء", net_down = "لا استجابة",
net_unknown = "غير معروف", net_limited = "حد الطلبات", ping_you = "بنقك",
counts = "فاضي: %d  •  منخفض: %d  •  ممتلئ: %d",
counts_init = "فاضي: -  •  منخفض: -  •  ممتلئ: -",
st_idle = "اضغط تحديث لجلب السيرفرات",
st_limited = "ممنوع مؤقتًا من Roblox — أنتظر %d ثانية",
st_net_down = "الشبكة لا تستجيب — جرّب لاحقًا",
st_no_match = "لا يوجد سيرفر مطابق — حدّث أو خفف الفلتر",
st_wait_gap = "انتظر %d ثانية قبل المحاولة...",
st_changed = "السيرفر تغيّر — اختر سيرفر ثاني",
st_going = "جاري الانتقال...",
st_lock = "جاري الانتقال... %dث (%s) — لا تضغط مرة ثانية",
st_lock_timeout = "تأخر الانتقال — فُك القفل، تقدر تحاول من جديد",
st_unlocked = "تم فك القفل",
st_fail_imm = "فشل الانتقال",
st_fail_reason = "%s — أخفيت هذا السيرفر، اختر غيره",
st_refresh_pages = "Haider looking server for you  %d/%d",
why_ended = "السيرفر أُغلق",
why_full = "السيرفر امتلأ",
why_flood = "طلبات كثيرة — انتظر ثواني",
why_busy = "فيه انتقال شغّال حاليًا",
why_generic = "Roblox رفض الانتقال (غالبًا السيرفر يُغلق)",
log_aborted = "أُلغي الانتقال: السيرفر تغيّر (%s)",
log_verified = "تأكيد قبل الانتقال: %d/%d ✓",
log_noverify = "تعذّر التأكيد قبل الانتقال — نكمل بدونه",
log_fail = "فشل الانتقال: %s [%s]",
log_imm = "خطأ فوري: %s",
log_stall = "تأخر الانتقال، فُك القفل تلقائيًا بعد %dث",
log_refresh_start = "بدء %s",
log_refresh_done = "%s — %d مطابق",
log_arrive = "تأكيد الوصول: الفعلي %d/%d",
log_arrive_exp = "تأكيد الوصول: الفعلي %d/%d (المتوقع %d + أنت)",
log_arrive2 = "مدة التحميل %dث • البنق %s (%s) %s",
log_mismatch = "وصلت لسيرفر مختلف عن المطلوب",
log_near = "سيرفر قريب! تقدر تحفظه بالمفضّلة",
log_disconnect = "انقطاع: %s",
log_limited = "حد طلبات Roblox — تأخير %d ثانية",
refresh_quick = "تحديث سريع", refresh_full = "تحديث شامل",
verdict_near = "قريب ✓", verdict_mid = "متوسط", verdict_far = "بعيد ✕", verdict_unknown = "غير معروف",
btn_quick = "تحديث سريع", btn_full = "تحديث شامل", btn_best = "أفضل سيرفر هادئ",
btn_prev = "↩ السابق", btn_go = "انتقل", btn_verify = "تحقق", btn_copy = "نسخ",
btn_copy_id = "نسخ ID", btn_del = "حذف", btn_clear_log = "مسح السجل", btn_copy_log = "نسخ السجل",
prev_none = "لا يوجد سيرفر سابق محفوظ",
row_gone = "اختفى ✕",
pl_head = "اللاعبون بالسيرفر: %d/%d", pl_you = "(أنت)", pl_nostats = "لا إحصائيات ظاهرة",
bd_stat = "الإحصائية: %s  (اضغط للتبديل)", bd_none = "لا توجد إحصائيات",
bd_none_info = "هذا الماب ما يرسل إحصائيات (leaderstats) للاعبين، فما أقدر أرتّب. السكربت يقرأ فقط اللي اللعبة تعرضه لكل اللاعبين.",
bd_info = "ترتيب لاعبين هذا السيرفر (%d) حسب %s",
fd_hint = "ابحث عن صديق بين السيرفرات العامة. البحث متاح للأصدقاء فقط.",
fd_name_ph = "اسم الصديق (Username)",
fd_search = "بحث", fd_cancel = "إلغاء",
fd_depth = "العمق: %d صفحة (~%d سيرفر) — اضغط للتغيير",
fd_noreq = "منفّذك لا يدعم الطلبات الخارجية (request) — البحث غير متاح",
fd_badname = "اكتب اسم مستخدم صحيح",
fd_notfound = "ما لقيت لاعب بهذا الاسم",
fd_self = "هذا حسابك أنت",
fd_notfriend = "هذا اللاعب ليس بقائمة أصدقائك — البحث للأصدقاء فقط",
fd_thumb = "تعذّر جلب صورة اللاعب",
fd_scan = "أبحث... %d/%d صفحة",
fd_found = "لقيته! السيرفر %d/%d لاعب",
fd_nf = "ما لقيته بالصفحات الممسوحة (قد يكون خارجها أو بسيرفر خاص)",
fd_limited = "حد الطلبات — جرّب بعد قليل",
fd_err = "تعذّر البحث: %s",
fd_note = "النتيجة قد لا تكون مؤكدة 100% بسبب تخزين Roblox المؤقت للقوائم.",
fd_webhook = "وُجد الصديق %s بسيرفر %d/%d",
fv_name_ph = "اسم/ملاحظة للسيرفر (اختياري)",
fv_save = "⭐ حفظ السيرفر الحالي",
fv_check = "🔎 فحص المفضّلة",
fv_empty = "لا يوجد سيرفرات محفوظة بعد",
fv_stale = "قد يكون مغلق",
fv_ping = "بنق %dms",
fv_saved = "تم حفظ السيرفر الحالي بالمفضّلة",
fv_updated = "تم تحديث ملاحظة السيرفر المحفوظ",
fv_nojob = "لا يوجد JobId لهذا السيرفر",
fv_removed_closed = "حُذف من المفضّلة (أُغلق): %s",
fv_removed_fail = "حُذف من المفضّلة (تعذّر الدخول مرتين): %s",
fv_removed_miss = "حُذف من المفضّلة (لم يعد موجودًا): %s",
fv_checking = "أفحص المفضّلة... %d/%d صفحة",
fv_check_done = "فحص المفضّلة: %d موجود • %d حُذف • %d غير مؤكد",
fv_check_empty = "لا توجد مفضّلة لفحصها",
stt_refresh = "🔄 تحديث المعلومات",
stt_game = "الماب: %s\nاللاعبون الآن: %s  •  الزيارات: %s\nالمفضّلة: %s  •  الإعجاب: %s",
stt_game_none = "لا توجد معلومات الماب بعد — اضغط تحديث",
stt_game_fail = "تعذّر جلب معلومات الماب",
stt_status = "حالة Roblox: %s",
rs_none = "طبيعي ✓", rs_minor = "مشاكل بسيطة", rs_major = "عطل كبير", rs_critical = "عطل حرج",
rs_internal_ok = "طبيعي (تقدير داخلي)",
rs_internal_limited = "حد الطلبات (تقدير داخلي)",
rs_internal_down = "الشبكة لا تستجيب (تقدير داخلي)",
rs_internal_fails = "كثرة فشل انتقال — قد يكون عطل (تقدير داخلي)",
stt_session = "⏱ مدة بقائك بالسيرفر: %s",
stt_tp = "الانتقالات: %d  •  نجح %d  •  فشل %d  •  غير معروف %d\nنسبة النجاح: %s  •  متوسط التحميل: %s  •  متوسط البنق: %s",
stt_tp_none = "لا توجد انتقالات مسجّلة بعد",
stt_reasons = "أسباب الفشل: %s",
stt_buckets = "نجاح حسب عدد اللاعبين: %s",
stt_hours = "أهدأ الساعات: %s\nذروة الازدحام: %s",
stt_hours_wait = "أجمع بيانات الساعات... (%d عينة، تحتاج وقتًا)",
stt_hours_note = "(بتوقيت جهازك — يُسجَّل أثناء تشغيل السكربت)",
fl_max = "أقصى لاعبين بالسيرفر:", fl_min = "أقل لاعبين بالسيرفر:", fl_ping = "أعلى Ping (ms):",
fl_fps = "أقل fps للسيرفر:", fl_age = "أقصى عمر السيرفر (ث):", fl_every = "فاصل التحديث التلقائي (ث):",
fl_nofull = "استبعاد الممتلئ:", fl_auto = "تحديث تلقائي:", fl_verify = "تأكيد العدد قبل الانتقال:",
fl_quality = "ترتيب بالجودة (وإلا الأقل لاعبين):",
fl_note = "الفلاتر محفوظة لكل ماب بشكل منفصل.",
th_pick = "اختر الثيم اللوني:",
log_empty = "السجل فارغ",
tl_caps_title = "فحص المنفّذ",
tl_caps_run = "▶ تشغيل الفحص",
tl_caps_wait = "أفحص...",
tl_report = "📋 نسخ تقرير مشكلة",
tl_report_copied = "✓ نُسخ التقرير — ابعثه للمطوّر",
tl_report_manual = "الحافظة غير مدعومة — انسخ النص من الصندوق:",
tl_backup_title = "النسخ الاحتياطي (يبقى حتى لو حذفت اللعبة)",
tl_backup_copy = "📤 نسخ كود النسخة الاحتياطية",
tl_backup_copied = "✓ نُسخ الكود — احفظه بملاحظاتك",
tl_backup_manual = "الحافظة غير مدعومة — انسخ الكود من الصندوق:",
tl_restore_ph = "الصق كود النسخة الاحتياطية هنا",
tl_restore = "📥 استعادة من الكود",
tl_restore_ok = "تمت الاستعادة: %d مفضّلة • %d سجل انتقال",
tl_restore_bad = "الكود غير صالح أو تالف",
tl_backup_note = "الكود لا يحتوي رابط الـ webhook. ملف الحفظ بمجلد المنفّذ قد يُحذف مع حذف المنفّذ، لهذا خزّن الكود بمكان آمن.",
cap_exec = "المنفّذ", cap_loadstring = "تحويل الكود (loadstring)", cap_files = "حفظ الملفات",
cap_httpget = "جلب الإنترنت (HttpGet)", cap_request = "الطلبات الخارجية (request)",
cap_clip = "الحافظة (نسخ)", cap_queue = "إعادة التشغيل بعد الانتقال",
cap_tpevent = "حدث حالة الانتقال (OnTeleport)", cap_errevent = "حدث الانقطاع",
cap_gfx = "تقليل الرسوم",
cap_pending = "غير مؤكد — يُرصد بعد أول انتقال",
capn_files = "إن ناقص: ما راح تنحفظ الإعدادات",
capn_httpget = "إن ناقص: السكربت ما يقدر يجلب السيرفرات",
capn_request = "إن ناقص: البحث عن صديق وإشعارات Discord معطّلة",
capn_clip = "إن ناقص: أزرار النسخ تعرض النص بصندوق",
capn_queue = "إن ناقص: شغّل السكربت يدويًا بعد كل انتقال",
capn_tpevent = "إن ناقص: القفل يعتمد على مؤقت ثابت أطول",
capn_errevent = "إن ناقص: ما يظهر زر إعادة الدخول بعد الانقطاع",
capn_gfx = "إن ناقص: وضع توفير الأداء ما يشتغل",
set_lang = "اللغة: العربية  (اضغط للتبديل)",
set_gfx = "وضع توفير الأداء (جودة منخفضة):",
set_hook = "رابط Discord webhook (اختياري):",
set_hook_ph = "https://discord.com/api/webhooks/...",
set_notify_arrive = "إشعار عند الوصول:",
set_notify_match = "إشعار عند إيجاد سيرفر/صديق:",
set_hook_test = "اختبار الإشعار",
set_hook_ok = "✓ أُرسل", set_hook_fail = "✕ فشل (تحقق من الرابط/المنفّذ)",
set_hook_bad = "الرابط يجب أن يكون رابط Discord webhook",
set_save = "الحفظ التلقائي: %s",
set_queue = "إعادة التشغيل بعد الانتقال: %s",
yes_on = "مفعّل ✓", yes_supported = "مدعوم ✓", not_supported = "غير مدعوم بمنفّذك ✕",
set_players_now = "اللاعبون بهذا السيرفر الآن: %d/%d",
set_credits = "حقوق المطوّر Haider:",
set_reset = "إعادة تعيين كل الإعدادات",
set_join_none = "إحصائيات الانتقال: لا يوجد بعد",
set_join = "آخر %d انتقالات: متوسط التحميل %dث • متوسط البنق %s",
bn_title = "انقطع الاتصال",
bn_same = "إعادة الدخول لنفس السيرفر",
bn_prev = "السيرفر السابق",
bn_close = "إغلاق",
wh_arrive = "✅ Haider View: وصلت %d/%d • بنق %s • تحميل %dث • %s",
wh_match = "🔎 Haider View: لقيت سيرفر مطابق %d/%d",
wh_test = "🔔 Haider View: اختبار الإشعارات يعمل",
tab_ctrl = "تحكّم", tab_esp = "ESP",
ct_warn = "تنبيه: بعض الماب تكتشف السرعة والطيران وقد تطردك. استعملها بحذر.",
ct_speed_on = "تفعيل السرعة:", ct_speed = "السرعة:", ct_jump_on = "تفعيل القفز:", ct_jump = "قوة القفز:",
ct_fly = "الطيران:", ct_fly_speed = "سرعة الطيران:", ct_noclip = "اختراق الجدران:",
ct_stop = "⛔ إيقاف الكل", ct_stopped = "تم إيقاف كل التحكمات", ct_fly_fail = "تعذّر الطيران: لا توجد شخصية",
ct_fly_hint = "الطيران: ذراع الحركة للاتجاه، وأزرار ▲▼ للصعود والنزول (أو Space و Ctrl).",
es_on = "تفعيل ESP:", es_arrow = "سهم اتجاه لأقرب هدف:", es_npc = "إظهار NPC:", es_friends = "إظهار أصدقائي بالسيرفر:",
es_dist = "أقصى مسافة (م):", es_max = "أقصى عدد علامات:", es_kw_ph = "كلمة من اسم الشيء (مثل egg)",
es_add = "➕ إضافة", es_kw_title = "الكلمات المراقبة (اضغط للحذف):", es_kw_none = "لا توجد كلمات — أضف كلمة أو افحص الماب",
es_note = "الـESP للأشياء وأصدقائك فقط، ولا يعرض لاعبين غرباء.",
map_title = "اكتشاف الماب", map_scan = "🔎 فحص الماب", map_scanning = "أفحص الماب...",
map_info = "الماب: %s\nالنوع: %s\nإحصائيات (leaderstats): %s\nأدوات: %s\nRemotes: %d",
map_farm = "مزرعة/سيميولاتور", map_combat = "قتال", map_general = "عام",
map_yes = "موجودة", map_no = "غير موجودة", map_none = "لم يُفحص بعد",
map_cands = "أشياء مقترحة (اضغط للإضافة):", map_cands_none = "لم أجد أشياء متكررة واضحة",
map_copy = "📋 نسخ تقرير الماب", map_copied = "✓ نُسخ تقرير الماب", map_auto = "أُضيفت كلمات مقترحة تلقائيًا: %s",
set_anim = "حركة الدائرة:", set_img_bg = "صورة الخلفية (رابط https أو رقم رفع):",
set_img_circle = "صورة الدائرة (رابط https أو رقم رفع):", set_img_ph = "https://...png",
img_ok = "✓ تم تطبيق الصور", img_fail = "✕ تعذّر تحميل الصورة (يحتاج رابط https مباشر ومنفّذ يدعم getcustomasset)",
set_img_note = "صور ثابتة فقط (png/jpg). الـGIF غير مدعوم.",
tab_ai = "مساعد AI",
ai_note = "المساعد يعمل بدون مفتاح عبر خدمة عامة مجانية (أضعف). ضع مفتاح OpenRouter الخاص بك لنتائج أفضل. المفتاح يبقى عندك فقط.",
ai_key = "مفتاح OpenRouter (اختياري):", ai_key_ph = "sk-or-...", ai_model = "النموذج (slug):",
ai_ctx_on = "إرسال سياق الماب (الاسم والنوع والأشياء والفلاتر):",
ai_ctx = "لا يُرسل أبدًا: اسمك أو مفتاحك أو رابط الـwebhook.",
ai_btn_kw = "🎯 اقترح كلمات ESP", ai_btn_err = "🩺 اشرح آخر الأخطاء", ai_btn_filt = "🔍 اقترح فلاتر أفضل",
ai_free_ph = "اسأل عن الماب أو السكربت...", ai_ask = "إرسال السؤال",
ai_wait = "أفكر...", ai_copy = "📋 نسخ الرد", ai_copied = "✓ نُسخ الرد",
ai_apply = "➕ إضافة المقترحات: %s", ai_applied = "تمت إضافة كلمات ESP",
ai_err_key = "المفتاح مرفوض — تحقق منه", ai_err_pay = "رصيد OpenRouter غير كافٍ",
ai_err_rate = "حد الطلبات — جرّب بعد قليل", ai_err_net = "تعذّر الاتصال (يحتاج منفّذ يدعم request)",
ai_err_empty = "رد فارغ — جرّب نموذجًا آخر",
set_autohide = "إخفاء النافذة تلقائيًا عند عدم اللمس:", set_hideafter = "الإخفاء بعد (ث):",
ct_rubber = "رجّعك الماب لمكانك (حماية محتملة) — أوقفت الطيران والسرعة",
ct_combat = "هذا الماب يبدو ماب قتال — الحماية فيه غالبًا أقوى، والخطر أكبر.",
tl_selftest = "🧪 فحص ذاتي شامل", tl_selftest_wait = "أفحص...",
stn_storage = "الحفظ بالملفات", stn_json = "تحويل الإعدادات JSON", stn_backup = "كود النسخ الاحتياطي",
stn_servers = "جلب قائمة السيرفرات", stn_char = "الشخصية (للطيران)", stn_bodyvel = "قوى الحركة",
stn_camera = "الكاميرا", stn_ws = "قراءة الماب", stn_i18n = "تطابق اللغتين", stn_ui = "الواجهة",
stn_tp = "حدث فشل الانتقال", stn_img = "الصور المخصصة",
}
L.en = {
tab_main = "Home", tab_players = "Players", tab_board = "Board", tab_find = "Find",
tab_fav = "Favs", tab_stats = "Stats", tab_filt = "Filters", tab_theme = "Theme",
tab_log = "Log", tab_tools = "Tools", tab_set = "Settings",
net_label = "Network", net_ok = "OK", net_slow = "Slow", net_down = "No response",
net_unknown = "Unknown", net_limited = "Rate limited", ping_you = "Ping",
counts = "Empty: %d  •  Low: %d  •  Full: %d",
counts_init = "Empty: -  •  Low: -  •  Full: -",
st_idle = "Press refresh to load servers",
st_limited = "Rate limited by Roblox — waiting %d s",
st_net_down = "Network not responding — try later",
st_no_match = "No matching server — refresh or loosen filters",
st_wait_gap = "Waiting %d s before trying...",
st_changed = "Server changed — pick another",
st_going = "Teleporting...",
st_lock = "Teleporting... %ds (%s) — don't press again",
st_lock_timeout = "Teleport stalled — unlocked, you can retry",
st_unlocked = "Unlocked",
st_fail_imm = "Teleport failed",
st_fail_reason = "%s — hid this server, pick another",
st_refresh_pages = "Haider looking server for you  %d/%d",
why_ended = "Server closed",
why_full = "Server is full",
why_flood = "Too many requests — wait a few seconds",
why_busy = "A teleport is already running",
why_generic = "Roblox refused the teleport (server likely closing)",
log_aborted = "Teleport cancelled: server changed (%s)",
log_verified = "Verified before teleport: %d/%d ✓",
log_noverify = "Could not verify before teleport — continuing without it",
log_fail = "Teleport failed: %s [%s]",
log_imm = "Immediate error: %s",
log_stall = "Teleport stalled, lock released automatically after %ds",
log_refresh_start = "Started %s",
log_refresh_done = "%s — %d matching",
log_arrive = "Arrival confirmed: actual %d/%d",
log_arrive_exp = "Arrival confirmed: actual %d/%d (expected %d + you)",
log_arrive2 = "Load time %ds • ping %s (%s) %s",
log_mismatch = "Arrived at a different server than requested",
log_near = "Close server! You can save it to favorites",
log_disconnect = "Disconnected: %s",
log_limited = "Roblox rate limit — backing off %d s",
refresh_quick = "Quick refresh", refresh_full = "Full refresh",
verdict_near = "Near ✓", verdict_mid = "Medium", verdict_far = "Far ✕", verdict_unknown = "Unknown",
btn_quick = "Quick refresh", btn_full = "Full refresh", btn_best = "Best quiet server",
btn_prev = "↩ Previous", btn_go = "Go", btn_verify = "Check", btn_copy = "Copy",
btn_copy_id = "Copy ID", btn_del = "Delete", btn_clear_log = "Clear log", btn_copy_log = "Copy log",
prev_none = "No previous server saved",
row_gone = "Gone ✕",
pl_head = "Players in server: %d/%d", pl_you = "(you)", pl_nostats = "No visible stats",
bd_stat = "Stat: %s  (tap to switch)", bd_none = "No stats available",
bd_none_info = "This map doesn't send stats (leaderstats) for players, so I can't rank them. The script only reads what the game shows to everyone.",
bd_info = "Ranking of this server's players (%d) by %s",
fd_hint = "Find a friend among public servers. Search works for friends only.",
fd_name_ph = "Friend's username",
fd_search = "Search", fd_cancel = "Cancel",
fd_depth = "Depth: %d pages (~%d servers) — tap to change",
fd_noreq = "Your executor has no request function — search unavailable",
fd_badname = "Enter a valid username",
fd_notfound = "No player found with that name",
fd_self = "That's your own account",
fd_notfriend = "That player is not on your friends list — search is for friends only",
fd_thumb = "Could not fetch the player's avatar",
fd_scan = "Searching... %d/%d pages",
fd_found = "Found! Server %d/%d players",
fd_nf = "Not found in scanned pages (may be outside them or in a private server)",
fd_limited = "Rate limited — try again shortly",
fd_err = "Search failed: %s",
fd_note = "Result may not be 100% accurate because Roblox caches server lists.",
fd_webhook = "Friend %s found in server %d/%d",
fv_name_ph = "Server name/note (optional)",
fv_save = "⭐ Save current server",
fv_check = "🔎 Check favorites",
fv_empty = "No saved servers yet",
fv_stale = "may be closed",
fv_ping = "ping %dms",
fv_saved = "Current server saved to favorites",
fv_updated = "Saved server note updated",
fv_nojob = "This server has no JobId",
fv_removed_closed = "Removed from favorites (closed): %s",
fv_removed_fail = "Removed from favorites (couldn't join twice): %s",
fv_removed_miss = "Removed from favorites (no longer exists): %s",
fv_checking = "Checking favorites... %d/%d pages",
fv_check_done = "Favorites check: %d alive • %d removed • %d unconfirmed",
fv_check_empty = "No favorites to check",
stt_refresh = "🔄 Refresh info",
stt_game = "Map: %s\nPlayers now: %s  •  Visits: %s\nFavorites: %s  •  Likes: %s",
stt_game_none = "No map info yet — press refresh",
stt_game_fail = "Could not fetch map info",
stt_status = "Roblox status: %s",
rs_none = "Normal ✓", rs_minor = "Minor issues", rs_major = "Major outage", rs_critical = "Critical outage",
rs_internal_ok = "Normal (internal estimate)",
rs_internal_limited = "Rate limited (internal estimate)",
rs_internal_down = "Network not responding (internal estimate)",
rs_internal_fails = "Many teleport failures — maybe an outage (internal estimate)",
stt_session = "⏱ Time in this server: %s",
stt_tp = "Teleports: %d  •  ok %d  •  failed %d  •  unknown %d\nSuccess rate: %s  •  Avg load: %s  •  Avg ping: %s",
stt_tp_none = "No teleports recorded yet",
stt_reasons = "Failure reasons: %s",
stt_buckets = "Success by player count: %s",
stt_hours = "Quietest hours: %s\nBusiest hours: %s",
stt_hours_wait = "Collecting hourly data... (%d samples, needs time)",
stt_hours_note = "(your device time — recorded while the script runs)",
fl_max = "Max players in server:", fl_min = "Min players in server:", fl_ping = "Max ping (ms):",
fl_fps = "Min server fps:", fl_age = "Max server age (s):", fl_every = "Auto-refresh interval (s):",
fl_nofull = "Exclude full servers:", fl_auto = "Auto refresh:", fl_verify = "Verify count before teleport:",
fl_quality = "Sort by quality (else fewest players):",
fl_note = "Filters are saved separately for each map.",
th_pick = "Pick a color theme:",
log_empty = "Log is empty",
tl_caps_title = "Executor check",
tl_caps_run = "▶ Run check",
tl_caps_wait = "Checking...",
tl_report = "📋 Copy problem report",
tl_report_copied = "✓ Report copied — send it to the developer",
tl_report_manual = "Clipboard unsupported — copy the text from the box:",
tl_backup_title = "Backup (survives deleting the game)",
tl_backup_copy = "📤 Copy backup code",
tl_backup_copied = "✓ Code copied — save it in your notes",
tl_backup_manual = "Clipboard unsupported — copy the code from the box:",
tl_restore_ph = "Paste your backup code here",
tl_restore = "📥 Restore from code",
tl_restore_ok = "Restored: %d favorites • %d teleport records",
tl_restore_bad = "Code is invalid or corrupted",
tl_backup_note = "The code does not contain your webhook URL. The save file in the executor folder may be deleted with the executor, so store the code somewhere safe.",
cap_exec = "Executor", cap_loadstring = "Code loading (loadstring)", cap_files = "File saving",
cap_httpget = "Internet fetch (HttpGet)", cap_request = "Web requests (request)",
cap_clip = "Clipboard (copy)", cap_queue = "Restart after teleport",
cap_tpevent = "Teleport state event (OnTeleport)", cap_errevent = "Disconnect event",
cap_gfx = "Lower graphics",
cap_pending = "Unconfirmed — detected after first teleport",
capn_files = "If missing: settings won't be saved",
capn_httpget = "If missing: the script can't fetch servers",
capn_request = "If missing: friend search and Discord alerts are disabled",
capn_clip = "If missing: copy buttons show the text in a box",
capn_queue = "If missing: run the script manually after each teleport",
capn_tpevent = "If missing: the lock uses a longer fixed timer",
capn_errevent = "If missing: no rejoin button after a disconnect",
capn_gfx = "If missing: performance mode won't work",
set_lang = "Language: English  (tap to switch)",
set_gfx = "Performance mode (low graphics):",
set_hook = "Discord webhook URL (optional):",
set_hook_ph = "https://discord.com/api/webhooks/...",
set_notify_arrive = "Notify on arrival:",
set_notify_match = "Notify when a server/friend is found:",
set_hook_test = "Test notification",
set_hook_ok = "✓ Sent", set_hook_fail = "✕ Failed (check URL/executor)",
set_hook_bad = "The URL must be a Discord webhook URL",
set_save = "Auto-save: %s",
set_queue = "Restart after teleport: %s",
yes_on = "On ✓", yes_supported = "Supported ✓", not_supported = "Not supported by your executor ✕",
set_players_now = "Players in this server now: %d/%d",
set_credits = "Developer credits Haider:",
set_reset = "Reset all settings",
set_join_none = "Teleport stats: none yet",
set_join = "Last %d teleports: avg load %ds • avg ping %s",
bn_title = "Disconnected",
bn_same = "Rejoin same server",
bn_prev = "Previous server",
bn_close = "Close",
wh_arrive = "✅ Haider View: arrived %d/%d • ping %s • load %ds • %s",
wh_match = "🔎 Haider View: found a matching server %d/%d",
wh_test = "🔔 Haider View: notifications work",
tab_ctrl = "Control", tab_esp = "ESP",
ct_warn = "Warning: some maps detect speed and flying and may kick you. Use with care.",
ct_speed_on = "Enable speed:", ct_speed = "Speed:", ct_jump_on = "Enable jump:", ct_jump = "Jump power:",
ct_fly = "Fly:", ct_fly_speed = "Fly speed:", ct_noclip = "Noclip:",
ct_stop = "⛔ Stop all", ct_stopped = "All controls stopped", ct_fly_fail = "Can't fly: no character",
ct_fly_hint = "Fly: move stick for direction, ▲▼ buttons to go up/down (or Space and Ctrl).",
es_on = "Enable ESP:", es_arrow = "Arrow to nearest target:", es_npc = "Show NPCs:", es_friends = "Show my friends in server:",
es_dist = "Max distance (m):", es_max = "Max markers:", es_kw_ph = "Part of the object's name (e.g. egg)",
es_add = "➕ Add", es_kw_title = "Watched keywords (tap to remove):", es_kw_none = "No keywords — add one or scan the map",
es_note = "ESP is for objects and your friends only, it never shows strangers.",
map_title = "Map detection", map_scan = "🔎 Scan map", map_scanning = "Scanning map...",
map_info = "Map: %s\nType: %s\nStats (leaderstats): %s\nTools: %s\nRemotes: %d",
map_farm = "Farm/simulator", map_combat = "Combat", map_general = "General",
map_yes = "present", map_no = "absent", map_none = "Not scanned yet",
map_cands = "Suggested objects (tap to add):", map_cands_none = "No clear repeated objects found",
map_copy = "📋 Copy map report", map_copied = "✓ Map report copied", map_auto = "Suggested keywords added automatically: %s",
set_anim = "Circle animation:", set_img_bg = "Background image (https link or asset id):",
set_img_circle = "Circle image (https link or asset id):", set_img_ph = "https://...png",
img_ok = "✓ Images applied", img_fail = "✕ Couldn't load the image (needs a direct https link and an executor with getcustomasset)",
set_img_note = "Static images only (png/jpg). GIF is not supported.",
tab_ai = "AI helper",
ai_note = "The helper works without a key through a free public service (weaker). Add your own OpenRouter key for better results. The key stays with you only.",
ai_key = "OpenRouter key (optional):", ai_key_ph = "sk-or-...", ai_model = "Model (slug):",
ai_ctx_on = "Send map context (name, type, objects, filters):",
ai_ctx = "Never sent: your name, your key, or your webhook URL.",
ai_btn_kw = "🎯 Suggest ESP keywords", ai_btn_err = "🩺 Explain latest errors", ai_btn_filt = "🔍 Suggest better filters",
ai_free_ph = "Ask about the map or the script...", ai_ask = "Send question",
ai_wait = "Thinking...", ai_copy = "📋 Copy reply", ai_copied = "✓ Reply copied",
ai_apply = "➕ Add suggestions: %s", ai_applied = "ESP keywords added",
ai_err_key = "Key rejected — check it", ai_err_pay = "OpenRouter balance too low",
ai_err_rate = "Rate limited — try shortly", ai_err_net = "Connection failed (needs an executor with request)",
ai_err_empty = "Empty reply — try another model",
set_autohide = "Auto-hide window when untouched:", set_hideafter = "Hide after (s):",
ct_rubber = "The map pulled you back (possible protection) — I stopped fly and speed",
ct_combat = "This looks like a combat map — protection is usually stronger and the risk higher.",
tl_selftest = "🧪 Full self-test", tl_selftest_wait = "Testing...",
stn_storage = "File saving", stn_json = "Settings JSON", stn_backup = "Backup code",
stn_servers = "Server list fetch", stn_char = "Character (for fly)", stn_bodyvel = "Movement forces",
stn_camera = "Camera", stn_ws = "Map reading", stn_i18n = "Language match", stn_ui = "Interface",
stn_tp = "Teleport fail event", stn_img = "Custom images",
}
local function T(key, ...)
local pack = L[S.lang] or L.ar
local s = pack[key] or L.ar[key] or key
if select("#", ...) > 0 then
local ok, out = pcall(string.format, s, ...)
if ok then return out end
end
return s
end
local THEMES = {
{ name = "الحديد الأسود", nameEn = "Black Iron",
bg = Color3.fromRGB(12,11,10), panel = Color3.fromRGB(20,18,16),
card = Color3.fromRGB(28,25,22), accent = Color3.fromRGB(196,30,36),
gold = Color3.fromRGB(205,164,52), steel = Color3.fromRGB(120,112,100),
text = Color3.fromRGB(232,224,210), dim = Color3.fromRGB(150,140,128),
good = Color3.fromRGB(90,190,110), warn = Color3.fromRGB(220,170,60),
bad = Color3.fromRGB(210,70,70) },
{ name = "الفولاذ الأزرق", nameEn = "Blue Steel",
bg = Color3.fromRGB(10,13,18), panel = Color3.fromRGB(16,22,32),
card = Color3.fromRGB(22,30,44), accent = Color3.fromRGB(64,156,255),
gold = Color3.fromRGB(150,190,230), steel = Color3.fromRGB(95,110,130),
text = Color3.fromRGB(225,235,250), dim = Color3.fromRGB(140,150,165),
good = Color3.fromRGB(90,190,140), warn = Color3.fromRGB(220,180,70),
bad = Color3.fromRGB(220,90,90) },
{ name = "الغسق الأرجواني", nameEn = "Purple Dusk",
bg = Color3.fromRGB(14,10,18), panel = Color3.fromRGB(24,16,32),
card = Color3.fromRGB(32,22,42), accent = Color3.fromRGB(150,90,220),
gold = Color3.fromRGB(210,170,230), steel = Color3.fromRGB(110,95,130),
text = Color3.fromRGB(235,225,245), dim = Color3.fromRGB(150,138,165),
good = Color3.fromRGB(100,190,140), warn = Color3.fromRGB(220,180,80),
bad = Color3.fromRGB(220,90,110) },
{ name = "المانغا (أبيض/أسود)", nameEn = "Manga Mono", sharp = true,
bg = Color3.fromRGB(9,9,9), panel = Color3.fromRGB(15,15,15),
card = Color3.fromRGB(22,22,22), accent = Color3.fromRGB(96,96,96),
gold = Color3.fromRGB(205,205,205), steel = Color3.fromRGB(110,110,110),
text = Color3.fromRGB(232,232,232), dim = Color3.fromRGB(145,145,145),
good = Color3.fromRGB(150,190,150), warn = Color3.fromRGB(200,180,110),
bad = Color3.fromRGB(195,90,90) },
}
local function copyToClipboard(txt)
local fn = (typeof(setclipboard) == "function" and setclipboard)
or (typeof(toclipboard) == "function" and toclipboard) or nil
if not fn then return false end
return (pcall(fn, tostring(txt)))
end
local function getRequestFn()
if typeof(request) == "function" then return request end
if typeof(http_request) == "function" then return http_request end
if typeof(syn) == "table" and typeof(syn.request) == "function" then return syn.request end
if typeof(http) == "table" and typeof(http.request) == "function" then return http.request end
return nil
end
local function setStatus(text)
if UI.StatusLabel and UI.StatusLabel.Parent then UI.StatusLabel.Text = text end
end
local function setProgress(frac)
if UI.ProgressFill and UI.ProgressFill.Parent then
UI.ProgressFill.Size = UDim2.new(math.clamp(tonumber(frac) or 0, 0, 1), 0, 1, 0)
end
end
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33 }
local SUFFIX_LIST = {
{ 1e33, "Dc" }, { 1e30, "No" }, { 1e27, "Oc" }, { 1e24, "Sp" }, { 1e21, "Sx" },
{ 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" },
}
local function toNumber(raw)
if type(raw) == "number" then
if raw ~= raw then return nil end
return raw
end
if type(raw) == "boolean" then return raw and 1 or 0 end
if type(raw) ~= "string" then return nil end
local s = raw:gsub(",", ""):gsub("[%$%s]", "")
local direct = tonumber(s)
if direct then return direct end
local num, suf = s:match("^(%-?[%d%.]+)(%a+)$")
if not num then return nil end
local n = tonumber(num)
local mult = SUFFIX[suf:lower()]
if n and mult then return n * mult end
return nil
end
local function fmtNum(n)
if n ~= n then return "—" end
local a = math.abs(n)
if a < 10000 then
if n == math.floor(n) then return tostring(math.floor(n)) end
return string.format("%.1f", n)
end
for _, e in ipairs(SUFFIX_LIST) do
if a >= e[1] then
local txt = string.format("%.2f", n / e[1])
txt = txt:gsub("%.?0+$", "")
return txt .. e[2]
end
end
return string.format("%.0f", n)
end
local function fmtValue(raw)
if type(raw) == "number" then return fmtNum(raw) end
return tostring(raw)
end
local function getMyPing()
local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
if ok and type(v) == "number" and v > 0 then return math.floor(v) end
local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
if ok2 and type(p) == "number" and p > 0 then return math.floor(p * 2000) end
return nil
end
local NET = { status = "idle", fails = 0, backoffUntil = 0, backoffStep = 0, limitedCount = 0, lastLimitAt = 0 }
local function rawHttpGet(url)
local ok, res = pcall(function() return game:HttpGet(url) end)
if ok and type(res) == "string" and #res > 0 then return res, 200 end
if not ok and tostring(res):find("429", 1, true) then return nil, 429 end
local req = getRequestFn()
if req then
local ok2, r = pcall(req, { Url = url, Method = "GET" })
if ok2 and type(r) == "table" then
local code = tonumber(r.StatusCode) or 0
if code == 429 then return nil, 429 end
if type(r.Body) == "string" and #r.Body > 0 and (code == 0 or (code >= 200 and code < 300)) then
return r.Body, code
end
return nil, code
end
end
return nil, 0
end
local function httpGetTracked(url)
if tick() < NET.backoffUntil then return nil, "ratelimit" end
local t0 = tick()
local body, code = rawHttpGet(url)
local dt = tick() - t0
if body then
NET.fails = 0
NET.backoffStep = 0
NET.status = (dt > 2.5) and "slow" or "ok"
return body
end
if code == 429 then
NET.backoffStep = math.min(NET.backoffStep + 1, 5)
local wait = math.min(8 * (2 ^ (NET.backoffStep - 1)), 90)
NET.backoffUntil = tick() + wait
NET.status = "limited"
NET.limitedCount = NET.limitedCount + 1
NET.lastLimitAt = os.time()
addLog(T("log_limited", math.floor(wait)))
return nil, "ratelimit"
end
NET.fails = NET.fails + 1
NET.status = (NET.fails >= 2) and "down" or "slow"
return nil, "fail"
end
local allServers = {}
local function mergeServerList(list)
local now = os.time()
for _, s in ipairs(list) do
if type(s) == "table" and type(s.id) == "string" then
local old = allServers[s.id]
local playing = tonumber(s.playing) or 0
local rec = {
id = s.id,
placeId = K.PLACE_ID,
playing = playing,
maxPlayers = tonumber(s.maxPlayers) or 0,
ping = (type(s.ping) == "number" and s.ping > 0) and s.ping or nil,
fps = (type(s.fps) == "number" and s.fps > 0) and s.fps or nil,
fetchedAt = now,
seen = 1,
delta = nil,
}
if old then
rec.seen = (old.seen or 1) + 1
if (now - (old.fetchedAt or now)) >= 4 then
rec.delta = playing - old.playing
else
rec.delta = old.delta
end
end
allServers[s.id] = rec
end
end
end
local function pruneServers()
local now = os.time()
for id, s in pairs(allServers) do
if (now - (s.fetchedAt or 0)) > 600 then allServers[id] = nil end
end
end
local function serverListUrl(cursor)
local url = "https://games.roblox.com/v1/games/" .. K.PLACE_ID .. "/servers/Public?limit=100&sortOrder=Asc"
if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
return url
end
local function walkPages(maxPages, onPage)
local cursor = nil
for i = 1, maxPages do
local body, why = httpGetTracked(serverListUrl(cursor))
if not body then return false, why or "fail", i - 1 end
local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
if not ok or type(data) ~= "table" or type(data.data) ~= "table" then return false, "badjson", i - 1 end
mergeServerList(data.data)
if onPage and onPage(data.data, i) then return true, "stopped", i end
cursor = data.nextPageCursor
if not cursor then return true, "end", i end
task.wait(0.15)
end
return true, "limit", maxPages
end
local function pruneVisited()
local now = os.time()
for id, ts in pairs(S.visited) do
if type(ts) ~= "number" or (now - ts) > K.VISITED_TTL then S.visited[id] = nil end
end
end
pruneVisited()
local function markVisited(id)
if type(id) ~= "string" or id == "" then return end
S.visited[id] = os.time()
saveSettings()
end
local function isVisited(id)
local ts = S.visited[id]
if not ts then return false end
if (os.time() - ts) > K.VISITED_TTL then S.visited[id] = nil return false end
return true
end
markVisited(game.JobId)
local function verifyServer(s)
local result, count = "unknown", nil
local lastPlaying = 0
local expected = s.playing or 0
local okFlag, why = walkPages(K.MAX_PAGES_VERIFY, function(list)
for _, x in ipairs(list) do
lastPlaying = tonumber(x.playing) or lastPlaying
if x.id == s.id then
local playing = tonumber(x.playing) or 0
s.playing = playing
s.maxPlayers = tonumber(x.maxPlayers) or s.maxPlayers
s.verifiedAt = os.time()
count = playing
if playing > P.maxPlayers then result = "over"
elseif playing < P.minPlayers then result = "gone"
elseif (s.maxPlayers or 0) > 0 and playing >= s.maxPlayers then result = "full"
else result = "ok" end
return true
end
end
if lastPlaying > expected + 2 then
result = "gone"
return true
end
return false
end)
if result ~= "unknown" then return result, count end
if okFlag and why == "end" then return "gone" end
return "unknown"
end
local function trendOf(s)
local d = s.delta
if d == nil then return "", "dim" end
if d > 0 then return "🟢▲", "good" end
if d < 0 then return "🔴▼", "bad" end
if (s.seen or 1) >= 2 and s.playing >= 1 then return "🟡=", "warn" end
return "", "dim"
end
local function failPenalty(playing)
local bucket = math.min(math.max(playing, 0), 3)
local n, bad = 0, 0
for _, e in ipairs(P.history) do
if e.ok ~= nil and math.min(math.max(e.pl or 0, 0), 3) == bucket then
n = n + 1
if e.ok == false then bad = bad + 1 end
end
end
if n < 3 then return 0 end
return (bad / n) * 60
end
local function passesFilter(s)
if isVisited(s.id) then return false end
if s.playing < P.minPlayers or s.playing > P.maxPlayers then return false end
if s.ping and s.ping > P.maxPing then return false end
if s.fps and s.fps < P.minFps then return false end
if P.excludeFull and s.maxPlayers > 0 and s.playing >= s.maxPlayers then return false end
if (os.time() - s.fetchedAt) > P.maxAgeSeconds then return false end
return true
end
local function buildFilteredSorted()
local out = {}
for _, s in pairs(allServers) do
if passesFilter(s) then table.insert(out, s) end
end
local mode = P.sortMode
local function score(s)
local v = (s.ping or 150) + math.max(0, 60 - (s.fps or 50)) * 3 + s.playing * 8
if s.delta ~= nil then
if s.delta < 0 then v = v + 70 elseif s.delta > 0 then v = v - 15 end
end
return v + failPenalty(s.playing)
end
local scores = {}
if mode == "quality" then
for _, s in ipairs(out) do scores[s.id] = score(s) end
end
table.sort(out, function(a, b)
if mode == "quality" then
local sa, sb = scores[a.id], scores[b.id]
if sa ~= sb then return sa < sb end
if a.playing ~= b.playing then return a.playing < b.playing end
else
if a.playing ~= b.playing then return a.playing < b.playing end
local pa, pb = (a.ping or 9999), (b.ping or 9999)
if pa ~= pb then return pa < pb end
end
return a.id < b.id
end)
return out
end
local function countsBreakdown()
local empty, low, full = 0, 0, 0
local now = os.time()
for _, s in pairs(allServers) do
if (now - s.fetchedAt) <= P.maxAgeSeconds then
if s.playing == 0 then empty = empty + 1
elseif s.maxPlayers > 0 and s.playing >= s.maxPlayers then full = full + 1
else low = low + 1 end
end
end
return empty, low, full
end
local function histPush(entry)
table.insert(P.history, 1, entry)
while #P.history > K.HIST_MAX do table.remove(P.history) end
saveSettings()
end
local function histFind(at, id)
for _, e in ipairs(P.history) do
if e.at == at and e.id == id then return e end
end
return nil
end
local function starsFor(ping, sec)
local st
if not ping then st = 3
elseif ping <= 60 then st = 5
elseif ping <= 100 then st = 4
elseif ping <= 150 then st = 3
elseif ping <= 220 then st = 2
else st = 1 end
if sec and sec > 90 then st = math.max(1, st - 1) end
return st
end
local function starText(n)
n = math.clamp(math.floor(tonumber(n) or 0), 0, 5)
return string.rep("★", n) .. string.rep("☆", 5 - n)
end
local function removeFavoriteById(id)
for i, f in ipairs(P.favorites) do
if f.id == id then
table.remove(P.favorites, i)
saveSettings()
return f
end
end
return nil
end
local function findFavorite(id)
for _, f in ipairs(P.favorites) do
if f.id == id then return f end
end
return nil
end
local function addFavoriteCurrentServer(noteText)
local jobId = game.JobId
if type(jobId) ~= "string" or jobId == "" then
return false, T("fv_nojob")
end
local note = tostring(noteText or "")
note = note:gsub("^%s+", ""):gsub("%s+$", "")
if note == "" then note = os.date("%Y-%m-%d %H:%M") end
local existing = findFavorite(jobId)
if existing then
existing.note = note
existing.ping = getMyPing() or existing.ping
existing.savedAt = os.time()
existing.miss = 0
existing.fails = 0
saveSettings()
return true, T("fv_updated")
end
table.insert(P.favorites, 1, {
id = jobId, placeId = K.PLACE_ID, note = note, savedAt = os.time(), ping = getMyPing(), miss = 0, fails = 0,
})
while #P.favorites > 30 do table.remove(P.favorites) end
saveSettings()
return true, T("fv_saved")
end
local SKIP_FOLDERS = { PlayerGui = true, Backpack = true, PlayerScripts = true, StarterGear = true }
local function readStats(plr)
local out = {}
local function addValue(name, raw)
table.insert(out, { name = name, raw = raw, num = toNumber(raw), text = fmtValue(raw) })
end
pcall(function()
local ls = plr:FindFirstChild("leaderstats")
if ls then
for _, v in ipairs(ls:GetChildren()) do
if v:IsA("ValueBase") then addValue(v.Name, v.Value) end
end
end
end)
if #out == 0 then
pcall(function()
local attrs = plr:GetAttributes()
local names = {}
for k, v in pairs(attrs) do
if type(v) == "number" or type(v) == "string" then table.insert(names, k) end
end
table.sort(names)
for _, k in ipairs(names) do
addValue(k, attrs[k])
if #out >= 8 then break end
end
end)
end
if #out == 0 then
pcall(function()
for _, folder in ipairs(plr:GetChildren()) do
if folder:IsA("Folder") and not SKIP_FOLDERS[folder.Name] then
for _, v in ipairs(folder:GetChildren()) do
if v:IsA("ValueBase") then addValue(folder.Name .. "." .. v.Name, v.Value) end
if #out >= 8 then return end
end
end
end
end)
end
return out
end
local STAT_HINTS = { "strength", "power", "stren", "damage", "level", "rebirth", "wins", "kills", "eggs", "cash", "coins", "money" }
local function pickDefaultStat(names)
for _, hint in ipairs(STAT_HINTS) do
for _, n in ipairs(names) do
if n:lower():find(hint, 1, true) then return n end
end
end
return names[1]
end
local function playerLabel(plr)
local dn = tostring(plr.DisplayName or plr.Name)
if dn == plr.Name then return dn end
return dn .. " (@" .. plr.Name .. ")"
end
local function computeStats()
local r = { total = 0, okN = 0, failN = 0, unk = 0, sumSec = 0, nSec = 0, sumPing = 0, nPing = 0, why = {}, buckets = {} }
for _, e in ipairs(P.history) do
r.total = r.total + 1
local b = tostring(math.min(math.max(e.pl or 0, 0), 3))
if not r.buckets[b] then r.buckets[b] = { ok = 0, bad = 0 } end
if e.ok == true then
r.okN = r.okN + 1
r.buckets[b].ok = r.buckets[b].ok + 1
if e.sec then
r.sumSec = r.sumSec + e.sec
r.nSec = r.nSec + 1
end
if e.ping and e.ping > 0 then
r.sumPing = r.sumPing + e.ping
r.nPing = r.nPing + 1
end
elseif e.ok == false then
r.failN = r.failN + 1
r.buckets[b].bad = r.buckets[b].bad + 1
local w = e.why or "?"
r.why[w] = (r.why[w] or 0) + 1
else
r.unk = r.unk + 1
end
end
return r
end
local function hourStats()
local list, samples = {}, 0
for h = 0, 23 do
local c = P.hourly[tostring(h)]
if c and c.n > 0 then
samples = samples + c.n
if c.n >= 2 then table.insert(list, { h = h, avg = c.s / c.n, n = c.n }) end
end
end
return list, samples
end
local GI = { name = nil, playing = nil, visits = nil, favs = nil, up = nil, down = nil, at = 0, err = false }
local lastSampleAt = 0
local function sampleHourly()
if not GI.playing then return end
if (os.time() - lastSampleAt) < 240 then return end
lastSampleAt = os.time()
local h = tostring(tonumber(os.date("%H")) or 0)
local c = P.hourly[h]
if not c then
c = { s = 0, n = 0 }
P.hourly[h] = c
end
c.s = c.s + GI.playing
c.n = math.min(c.n + 1, 100000)
saveSettings()
end
local function fetchGameInfo()
local uid = game.GameId
if type(uid) ~= "number" or uid <= 0 then
GI.err = true
return false
end
local body = httpGetTracked("https://games.roblox.com/v1/games?universeIds=" .. tostring(uid))
if not body then
GI.err = true
return false
end
local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
if not ok or type(data) ~= "table" or type(data.data) ~= "table" or type(data.data[1]) ~= "table" then
GI.err = true
return false
end
local g = data.data[1]
GI.name = tostring(g.name or "?")
GI.playing = tonumber(g.playing)
GI.visits = tonumber(g.visits)
GI.favs = tonumber(g.favoritedCount)
GI.err = false
local vb = httpGetTracked("https://games.roblox.com/v1/games/votes?universeIds=" .. tostring(uid))
if vb then
local ok2, vd = pcall(function() return HttpService:JSONDecode(vb) end)
if ok2 and type(vd) == "table" and type(vd.data) == "table" and type(vd.data[1]) == "table" then
GI.up = tonumber(vd.data[1].upVotes)
GI.down = tonumber(vd.data[1].downVotes)
end
end
GI.at = os.time()
sampleHourly()
return true
end
local RS = { indicator = nil, desc = nil, source = "internal", at = 0 }
local function fetchRobloxStatus()
local body = rawHttpGet("https://status.roblox.com/api/v2/status.json")
if body then
local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
if ok and type(data) == "table" and type(data.status) == "table" and type(data.status.indicator) == "string" then
RS.indicator = data.status.indicator
RS.desc = tostring(data.status.description or "")
RS.source = "status"
RS.at = os.time()
return true
end
end
RS.source = "internal"
RS.at = os.time()
return false
end
local function robloxStatusText()
if RS.source == "status" and RS.indicator then
local key = "rs_" .. tostring(RS.indicator)
if L.ar[key] then return T(key) end
return tostring(RS.desc ~= "" and RS.desc or RS.indicator)
end
if NET.status == "limited" then return T("rs_internal_limited") end
if NET.status == "down" then return T("rs_internal_down") end
local recent, bad = 0, 0
for i = 1, math.min(5, #P.history) do
local e = P.history[i]
if e.ok ~= nil then
recent = recent + 1
if e.ok == false then bad = bad + 1 end
end
end
if recent >= 4 and bad >= 3 then return T("rs_internal_fails") end
return T("rs_internal_ok")
end
local lastHookAt = 0
local function validWebhook(url)
if type(url) ~= "string" then return false end
return url:match("^https://discord%.com/api/webhooks/") ~= nil
or url:match("^https://discordapp%.com/api/webhooks/") ~= nil
or url:match("^https://ptb%.discord%.com/api/webhooks/") ~= nil
or url:match("^https://canary%.discord%.com/api/webhooks/") ~= nil
end
local function sendWebhook(text, force)
if not validWebhook(S.webhookUrl) then return false end
local req = getRequestFn()
if not req then return false end
if not force and (os.time() - lastHookAt) < 20 then return false end
lastHookAt = os.time()
local ok, res = pcall(req, {
Url = S.webhookUrl,
Method = "POST",
Headers = { ["Content-Type"] = "application/json" },
Body = HttpService:JSONEncode({ content = string.sub(tostring(text), 1, 1800), username = "Haider View" }),
})
if not ok then return false end
local code = (type(res) == "table" and tonumber(res.StatusCode)) or 0
return code >= 200 and code < 300
end
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV = {}
for i = 1, #B64 do B64_REV[string.byte(B64, i)] = i - 1 end
local function b64encode(str)
local out = {}
for i = 1, #str, 3 do
local a, b, c = string.byte(str, i, i + 2)
local n = a * 65536 + (b or 0) * 256 + (c or 0)
local c1 = math.floor(n / 262144) % 64
local c2 = math.floor(n / 4096) % 64
local c3 = math.floor(n / 64) % 64
local c4 = n % 64
local piece = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
if b then piece = piece .. string.sub(B64, c3 + 1, c3 + 1) else piece = piece .. "=" end
if c then piece = piece .. string.sub(B64, c4 + 1, c4 + 1) else piece = piece .. "=" end
out[#out + 1] = piece
end
return table.concat(out)
end
local function b64decode(str)
str = string.gsub(str, "[^%w%+/=]", "")
local out = {}
for i = 1, #str, 4 do
local a, b, c, d = string.byte(str, i, i + 3)
local va, vb = B64_REV[a], B64_REV[b]
if not va or not vb then return nil end
local vc, vd = nil, nil
if c and c ~= 61 then vc = B64_REV[c] end
if d and d ~= 61 then vd = B64_REV[d] end
local n = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
local piece = string.char(math.floor(n / 65536) % 256)
if vc then piece = piece .. string.char(math.floor(n / 256) % 256) end
if vd then piece = piece .. string.char(n % 256) end
out[#out + 1] = piece
end
return table.concat(out)
end
local function checksum(str)
local a, b = 1, 0
for i = 1, #str do
a = (a + string.byte(str, i)) % 65521
b = (b + a) % 65521
end
return string.format("%04x%04x", b, a)
end
local function buildBackupCode()
local data = { v = 1, lang = S.lang, theme = S.themeIndex, games = {} }
for key, prof in pairs(S.games) do
local copy = deepCopy(prof)
while #copy.history > K.EXPORT_HIST do table.remove(copy.history) end
data.games[key] = copy
end
local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
if not ok or type(json) ~= "string" then return nil end
local body = b64encode(json)
return "HVB1:" .. checksum(body) .. ":" .. body
end
local function restoreBackupCode(code)
if type(code) ~= "string" then return false end
code = string.gsub(code, "%s", "")
local cs, body = string.match(code, "^HVB1:(%x+):([%w%+/=]+)$")
if not cs or not body or checksum(body) ~= cs then return false end
local json = b64decode(body)
if not json then return false end
local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
if not ok or type(data) ~= "table" or type(data.games) ~= "table" then return false end
local nFav, nHist = 0, 0
for key, prof in pairs(data.games) do
if type(key) == "string" and type(prof) == "table" then
local cur = sanitizeProfile(S.games[key] or deepCopy(PROFILE_DEFAULTS))
local imp = sanitizeProfile(prof)
local have = {}
for _, f in ipairs(cur.favorites) do have[f.id] = true end
for _, f in ipairs(imp.favorites) do
if not have[f.id] and #cur.favorites < 30 then
table.insert(cur.favorites, f)
have[f.id] = true
nFav = nFav + 1
end
end
local seen = {}
for _, e in ipairs(cur.history) do seen[tostring(e.at) .. e.id] = true end
for _, e in ipairs(imp.history) do
local sk = tostring(e.at) .. e.id
if not seen[sk] then
table.insert(cur.history, e)
seen[sk] = true
nHist = nHist + 1
end
end
table.sort(cur.history, function(x, y) return x.at > y.at end)
while #cur.history > K.HIST_MAX do table.remove(cur.history) end
for _, fk in ipairs({ "maxPlayers", "minPlayers", "maxPing", "minFps", "maxAgeSeconds", "sortMode", "excludeFull" }) do
cur[fk] = imp[fk]
end
for h = 0, 23 do
local ic = imp.hourly[tostring(h)]
local cc = cur.hourly[tostring(h)]
if ic and (not cc or ic.n > cc.n) then cur.hourly[tostring(h)] = ic end
end
if #cur.joinStats == 0 then cur.joinStats = imp.joinStats end
S.games[key] = cur
end
end
if data.lang == "ar" or data.lang == "en" then S.lang = data.lang end
sanitizeSettings()
saveSettings()
return true, nFav, nHist
end
local function executorName()
local ok, a, b = pcall(function()
if typeof(identifyexecutor) == "function" then return identifyexecutor() end
if typeof(getexecutorname) == "function" then return getexecutorname() end
return nil
end)
if ok and a then
if b then return tostring(a) .. " " .. tostring(b) end
return tostring(a)
end
return "?"
end
local function runCapsCheck()
local rows = {}
local function add(nameKey, state, noteKey, extra)
table.insert(rows, { name = T(nameKey), state = state, note = noteKey and T(noteKey) or nil, extra = extra })
end
table.insert(rows, { name = T("cap_exec"), state = true, extra = executorName() })
add("cap_loadstring", typeof(loadstring) == "function")
local filesOk = false
if canPersist() then
local tmp = "HaiderViewServer_test.txt"
filesOk = pcall(function()
writefile(tmp, "ok")
if readfile(tmp) ~= "ok" then error("mismatch") end
if typeof(delfile) == "function" then delfile(tmp) end
end)
end
add("cap_files", filesOk, "capn_files")
local t0 = tick()
local body = rawHttpGet("https://games.roblox.com/v1/games?universeIds=" .. tostring(game.GameId))
local ms = nil
if body then ms = string.format("%dms", math.floor((tick() - t0) * 1000)) end
add("cap_httpget", body ~= nil, "capn_httpget", ms)
add("cap_request", getRequestFn() ~= nil, "capn_request")
add("cap_clip", (typeof(setclipboard) == "function") or (typeof(toclipboard) == "function"), "capn_clip")
add("cap_queue", typeof(queue_on_teleport) == "function", "capn_queue")
if CAPS.onTeleportSeen then
add("cap_tpevent", true)
else
add("cap_tpevent", "pending", "capn_tpevent", T("cap_pending"))
end
local okEv, ev = pcall(function() return GuiService.ErrorMessageChanged end)
add("cap_errevent", okEv and ev ~= nil, "capn_errevent")
local okGfx = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel end)
add("cap_gfx", okGfx, "capn_gfx")
return rows
end
local function buildReport()
local lines = {}
local function put(s) table.insert(lines, s) end
put("Haider View v" .. K.VERSION .. " | " .. executorName())
put("PlaceId " .. tostring(K.PLACE_ID) .. " | JobId " .. tostring(game.JobId))
put(string.format("caps: files=%s request=%s clip=%s queue=%s tpEvent=%s",
tostring(canPersist()), tostring(getRequestFn() ~= nil),
tostring((typeof(setclipboard) == "function") or (typeof(toclipboard) == "function")),
tostring(typeof(queue_on_teleport) == "function"), tostring(CAPS.onTeleportSeen)))
put(string.format("net: %s fails=%d limited=%d | ping=%s", tostring(NET.status), NET.fails, NET.limitedCount, tostring(getMyPing())))
put(string.format("filters: min=%d max=%d ping<=%d fps>=%d age=%d sort=%s excludeFull=%s",
P.minPlayers, P.maxPlayers, P.maxPing, P.minFps, P.maxAgeSeconds, P.sortMode, tostring(P.excludeFull)))
put(string.format("opts: lang=%s auto=%s verify=%s lowGfx=%s favs=%d hist=%d",
S.lang, tostring(S.autoRefresh), tostring(S.verifyBeforeJump), tostring(S.lowGfx), #P.favorites, #P.history))
for i = 1, math.min(5, #P.history) do
local e = P.history[i]
put(string.format("hist%d: ok=%s why=%s pl=%d src=%s ping=%s sec=%s", i, tostring(e.ok), tostring(e.why), e.pl or -1,
tostring(e.src), tostring(e.ping), tostring(e.sec)))
end
if F.lastSelfTest then
put("selftest:")
put(F.lastSelfTest)
end
if #ERRORS > 0 then
put("errors:")
for _, e in ipairs(ERRORS) do put("  " .. e) end
end
if #LOG > 0 then
put("log:")
for i = 1, math.min(8, #LOG) do put("  " .. LOG[i]) end
end
return table.concat(lines, "\n")
end
local function applyLowGfx(on)
pcall(function()
local ugs = UserSettings():GetService("UserGameSettings")
if on then
if S.gfxOrig < 0 then
S.gfxOrig = ugs.SavedQualityLevel.Value
saveSettings()
end
ugs.SavedQualityLevel = Enum.SavedQualityLevel.QualityLevel1
elseif S.gfxOrig >= 0 then
for _, item in ipairs(Enum.SavedQualityLevel:GetEnumItems()) do
if item.Value == S.gfxOrig then
ugs.SavedQualityLevel = item
break
end
end
S.gfxOrig = -1
saveSettings()
end
end)
pcall(function()
local r = settings().Rendering
if on then r.QualityLevel = Enum.QualityLevel.Level01
else r.QualityLevel = Enum.QualityLevel.Automatic end
end)
end
local jumping, refreshing, searching = false, false, false
local filtered = {}
local activeTab = S.activeTab
local SESSION_START = os.time()
local attemptGen = 0
local lastTeleportCallAt = 0
local failUntil = 0
local currentTarget, currentEntry = nil, nil
local prevBackup, prevBackupSet = nil, false
local tpState, tpStateAt = "None", 0
local function setJumping(v)
jumping = v
if UI.UnlockBtn and UI.UnlockBtn.Parent then UI.UnlockBtn.Visible = v end
end
local function recomputeFiltered()
filtered = buildFilteredSorted()
if F.updateCounts then F.updateCounts() end
if activeTab == "main" and F.renderList and UI.ScrollFrame and UI.ScrollFrame.Parent then F.renderList() end
end
local function queueSelf()
if typeof(queue_on_teleport) ~= "function" then return end
local at = ENV.HaiderViewQueuedAt
if type(at) == "number" and (os.time() - at) < 300 then return end
ENV.HaiderViewQueuedAt = os.time()
local loader = table.concat({
'local e = (typeof(getgenv) == "function" and getgenv()) or _G',
'e.HaiderViewQueuedAt = nil',
'local src = e.HaiderViewSrc',
'if not src and typeof(isfile) == "function" and isfile("' .. K.SRC_FILE .. '") then src = readfile("' .. K.SRC_FILE .. '") end',
'if src then local f = loadstring(src) if f then f() end end',
}, "\n")
pcall(queue_on_teleport, loader)
end
local function failReasonText(name)
if name == "GameEnded" or name == "GameNotFound" then return T("why_ended")
elseif name == "GameFull" then return T("why_full")
elseif name == "Flooded" then return T("why_flood")
elseif name == "IsTeleporting" then return T("why_busy")
end
return T("why_generic")
end
local function doTeleportCall(s)
local pid = s.placeId or K.PLACE_ID
local ok, err = pcall(function()
TeleportService:TeleportToPlaceInstance(pid, s.id, LocalPlayer)
end)
if ok then return true end
local ok2, err2 = pcall(function()
local opts = Instance.new("TeleportOptions")
opts.ServerInstanceId = s.id
TeleportService:TeleportAsync(pid, { LocalPlayer }, opts)
end)
if ok2 then return true end
return false, tostring(err) .. " | " .. tostring(err2)
end
local function failTeleport(resultName, rawMsg, immediate)
if not jumping then return end
local target, entry = currentTarget, currentEntry
currentTarget, currentEntry = nil, nil
S.pendingVerify = false
if prevBackupSet then
S.prevServer = prevBackup
prevBackupSet = false
end
if entry then
entry.ok = false
entry.why = immediate and "immediate" or tostring(resultName)
end
local why = failReasonText(resultName)
if target and target.id and not immediate then
local fav = findFavorite(target.id)
if fav then
fav.fails = (fav.fails or 0) + 1
if resultName == "GameEnded" or resultName == "GameNotFound" then
removeFavoriteById(target.id)
addLog(T("fv_removed_closed", tostring(fav.note)))
elseif fav.fails >= 2 then
removeFavoriteById(target.id)
addLog(T("fv_removed_fail", tostring(fav.note)))
end
end
markVisited(target.id)
end
failUntil = tick() + K.FAIL_COOLDOWN
attemptGen = attemptGen + 1
setJumping(false)
saveSettings()
if immediate then
setStatus(T("st_fail_imm"))
addLog(T("log_imm", tostring(rawMsg)))
else
setStatus(T("st_fail_reason", why))
addLog(T("log_fail", why, tostring(rawMsg or resultName)))
end
if F.writeLog then F.writeLog() end
if F.renderFavorites then F.renderFavorites() end
pcall(recomputeFiltered)
end
local function unlockTeleport()
if not jumping then return end
attemptGen = attemptGen + 1
currentTarget, currentEntry = nil, nil
setJumping(false)
setStatus(T("st_unlocked"))
end
local function lockLoop(gen, t0)
while gen == attemptGen and jumping and alive() do
local now = tick()
local elapsed = now - t0
local idle = now - math.max(tpStateAt, t0)
local stall
if tpState == "InProgress" then
stall = K.LOCK_MAX
elseif CAPS.onTeleportSeen then
stall = K.STALL_SECONDS
else
stall = K.STALL_NOEVENT
end
if elapsed >= K.LOCK_MAX or idle >= stall then return "stall", elapsed end
setStatus(T("st_lock", math.floor(elapsed), (tpState == "None") and "…" or tpState))
task.wait(1)
end
return "done", 0
end
local function teleportToServer(s)
if jumping then return end
setJumping(true)
attemptGen = attemptGen + 1
local gen = attemptGen
task.spawn(function()
local gap = math.max(K.MIN_GAP - (tick() - lastTeleportCallAt), failUntil - tick())
if gap > 0 then
setStatus(T("st_wait_gap", math.ceil(gap)))
task.wait(gap)
if gen ~= attemptGen then return end
end
if S.verifyBeforeJump and not s.skipVerify then
setStatus("Haider verifying server...")
local res, cnt = verifyServer(s)
if gen ~= attemptGen then return end
if res == "gone" or res == "over" or res == "full" then
setStatus(T("st_changed"))
addLog(T("log_aborted", tostring(res) .. (cnt and (" " .. cnt) or "")))
if F.writeLog then F.writeLog() end
markVisited(s.id)
recomputeFiltered()
setJumping(false)
return
end
if res == "ok" then
addLog(T("log_verified", cnt, s.maxPlayers or 0))
else
addLog(T("log_noverify"))
end
if F.writeLog then F.writeLog() end
end
local entry = {
at = os.time(), id = s.id, pl = s.playing or -1, mx = s.maxPlayers or 0,
hr = tonumber(os.date("%H")) or 0, src = s.source or "list",
}
histPush(entry)
currentTarget, currentEntry = s, entry
lastTeleportCallAt = tick()
prevBackup = S.prevServer
prevBackupSet = false
if type(game.JobId) == "string" and game.JobId ~= "" and game.JobId ~= s.id then
S.prevServer = { id = game.JobId, placeId = K.PLACE_ID, at = os.time() }
prevBackupSet = true
end
S.pendingVerify = { expected = s.playing or -1, at = os.time(), id = s.id, hat = entry.at }
saveSettings()
queueSelf()
tpState, tpStateAt = "None", tick()
setStatus(T("st_going"))
local ok, err = doTeleportCall(s)
if not ok then
failTeleport("immediate", err, true)
return
end
markVisited(s.id)
local t0 = tick()
local outcome, elapsed = lockLoop(gen, t0)
if outcome == "stall" and gen == attemptGen and jumping then
setJumping(false)
currentTarget, currentEntry = nil, nil
setStatus(T("st_lock_timeout"))
addLog(T("log_stall", math.floor(elapsed)))
if F.writeLog then F.writeLog() end
end
end)
end
local function attemptTeleport(s)
teleportToServer(s)
end
local function rejoinSame()
if type(game.JobId) ~= "string" or game.JobId == "" then return end
attemptTeleport({ id = game.JobId, placeId = K.PLACE_ID, skipVerify = true, source = "rejoin" })
end
local function rejoinPrev()
local ref = S.prevServer
if not ref then
setStatus(T("prev_none"))
return
end
attemptTeleport({ id = ref.id, placeId = ref.placeId or K.PLACE_ID, skipVerify = true, source = "prev" })
end
local function onTeleportInitFailed(player, teleportResult, errorMessage)
if player ~= LocalPlayer then return end
local name = (typeof(teleportResult) == "EnumItem") and teleportResult.Name or tostring(teleportResult)
failTeleport(name, errorMessage or name, false)
end
local function onTeleportState(state)
CAPS.onTeleportSeen = true
if not S.capTpSeen then
S.capTpSeen = true
saveSettings()
end
tpState = (typeof(state) == "EnumItem") and state.Name or tostring(state)
tpStateAt = tick()
if tpState == "Failed" and jumping then
task.delay(0.8, function()
if jumping and alive() then failTeleport("Failure", "OnTeleport: Failed", false) end
end)
end
end
local function onGuiError()
local ok, msg = pcall(function() return GuiService:GetErrorMessage() end)
if not ok or type(msg) ~= "string" or msg == "" then return end
if jumping then return end
if string.find(string.lower(msg), "teleport", 1, true) then return end
addLog(T("log_disconnect", string.sub(msg, 1, 60)))
if F.writeLog then F.writeLog() end
if F.showBanner then F.showBanner(msg) end
end
local function doRefresh(kind)
if refreshing or jumping or searching then return end
refreshing = true
setProgress(0)
local labelText = (kind == "quick") and T("refresh_quick") or T("refresh_full")
task.spawn(function()
while alive() and tick() < NET.backoffUntil do
setStatus(T("st_limited", math.ceil(NET.backoffUntil - tick())))
task.wait(1)
end
setStatus("Haider looking server for you")
addLog(T("log_refresh_start", labelText))
if F.writeLog then F.writeLog() end
local maxPages = (kind == "quick") and K.MAX_PAGES_QUICK or K.MAX_PAGES_FULL
local limited = false
local ok, err = pcall(function()
local okFlag, why = walkPages(maxPages, function(_, i)
setProgress(i / maxPages)
setStatus(T("st_refresh_pages", i, maxPages))
return false
end)
if not okFlag and why == "ratelimit" then limited = true end
pruneServers()
filtered = buildFilteredSorted()
end)
if not ok then addError("refresh", err) end
if F.updateNet then pcall(F.updateNet) end
if F.updateCounts then pcall(F.updateCounts) end
if activeTab == "main" and F.renderList and UI.ScrollFrame and UI.ScrollFrame.Parent then pcall(F.renderList) end
if limited then
setStatus(T("st_limited", math.max(1, math.ceil(NET.backoffUntil - tick()))))
elseif #filtered > 0 then
setStatus("Haider found server")
elseif NET.status == "down" then
setStatus(T("st_net_down"))
else
setStatus("Haider found no server")
end
addLog(T("log_refresh_done", labelText, #filtered))
if F.writeLog then F.writeLog() end
setProgress(1)
task.delay(0.8, function() if not refreshing then setProgress(0) end end)
refreshing = false
end)
end
local function refreshAll() doRefresh("full") end
local function quickRefreshAll() doRefresh("quick") end
local function checkFavorites()
if refreshing or jumping or searching then return end
if #P.favorites == 0 then
setStatus(T("fv_check_empty"))
return
end
refreshing = true
setProgress(0)
task.spawn(function()
while alive() and tick() < NET.backoffUntil do
setStatus(T("st_limited", math.ceil(NET.backoffUntil - tick())))
task.wait(1)
end
local want = {}
for _, f in ipairs(P.favorites) do want[f.id] = true end
local found = {}
if type(game.JobId) == "string" and game.JobId ~= "" then found[game.JobId] = true end
local okFlag, why = false, "fail"
local ok, err = pcall(function()
okFlag, why = walkPages(K.MAX_PAGES_SCAN, function(list, i)
setProgress(i / K.MAX_PAGES_SCAN)
setStatus(T("fv_checking", i, K.MAX_PAGES_SCAN))
for _, x in ipairs(list) do
if want[x.id] then found[x.id] = true end
end
local all = true
for id, _ in pairs(want) do
if not found[id] then
all = false
break
end
end
return all
end)
end)
if not ok then addError("favcheck", err) end
local complete = okFlag and (why == "end" or why == "stopped")
local aliveN, removedN, unconfN = 0, 0, 0
local keep = {}
for _, f in ipairs(P.favorites) do
if found[f.id] then
f.miss = 0
f.fails = 0
aliveN = aliveN + 1
table.insert(keep, f)
elseif complete and why == "end" then
f.miss = (f.miss or 0) + 1
if f.miss >= 2 then
removedN = removedN + 1
addLog(T("fv_removed_miss", tostring(f.note)))
else
unconfN = unconfN + 1
table.insert(keep, f)
end
else
unconfN = unconfN + 1
table.insert(keep, f)
end
end
P.favorites = keep
saveSettings()
setStatus(T("fv_check_done", aliveN, removedN, unconfN))
addLog(T("fv_check_done", aliveN, removedN, unconfN))
if F.writeLog then F.writeLog() end
if F.renderFavorites then pcall(F.renderFavorites) end
setProgress(1)
task.delay(0.8, function() if not refreshing then setProgress(0) end end)
refreshing = false
end)
end
local searchGen = 0
local SEARCH_DEPTHS = { 10, 20, 40 }
local function cancelFriendSearch()
searchGen = searchGen + 1
searching = false
end
local function friendSearch(rawName, depth, hooks)
if refreshing or jumping or searching then return false end
searching = true
searchGen = searchGen + 1
local gen = searchGen
task.spawn(function()
local function finish(msg)
if gen == searchGen then
searching = false
if msg then hooks.status(msg) end
hooks.done()
end
end
local req = getRequestFn()
if not req then return finish(T("fd_noreq")) end
local name = string.gsub(tostring(rawName or ""), "^%s+", "")
name = string.gsub(name, "%s+$", "")
if #name < 3 or #name > 20 or not string.match(name, "^[%w_]+$") then return finish(T("fd_badname")) end
local okId, uid = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
if not okId or type(uid) ~= "number" then return finish(T("fd_notfound")) end
if uid == LocalPlayer.UserId then return finish(T("fd_self")) end
local okF, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(uid) end)
if not okF or isFriend ~= true then return finish(T("fd_notfriend")) end
local thumbUrl = nil
local tb = httpGetTracked("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(uid) .. "&size=150x150&format=Png&isCircular=false")
if not tb and NET.status == "limited" then return finish(T("fd_limited")) end
if tb then
local okj, td = pcall(function() return HttpService:JSONDecode(tb) end)
if okj and type(td) == "table" and type(td.data) == "table" and type(td.data[1]) == "table"
and td.data[1].state == "Completed" then
thumbUrl = td.data[1].imageUrl
end
end
if type(thumbUrl) ~= "string" then return finish(T("fd_thumb")) end
local found, limitedNow, postFailed = nil, false, false
local okFlag, why = walkPages(depth, function(list, i)
if gen ~= searchGen or not alive() then return true end
hooks.status(T("fd_scan", i, depth))
hooks.progress(i / depth)
local tokens, owner = {}, {}
for _, srv in ipairs(list) do
if type(srv.playerTokens) == "table" then
for _, tk in ipairs(srv.playerTokens) do
if type(tk) == "string" then
table.insert(tokens, tk)
owner[#tokens] = srv
end
end
end
end
local idx = 1
while idx <= #tokens do
if gen ~= searchGen or not alive() then return true end
local last = math.min(idx + 99, #tokens)
local batch = {}
for j = idx, last do
table.insert(batch, {
requestId = tokens[j], token = tokens[j], type = "AvatarHeadShot",
size = "150x150", format = "png", isCircular = false,
})
end
local okR, res = pcall(req, {
Url = "https://thumbnails.roblox.com/v1/batch",
Method = "POST",
Headers = { ["Content-Type"] = "application/json" },
Body = HttpService:JSONEncode(batch),
})
if not okR or type(res) ~= "table" then
postFailed = true
return true
end
local code = tonumber(res.StatusCode) or 0
if code == 429 then
limitedNow = true
return true
end
if code >= 200 and code < 300 and type(res.Body) == "string" then
local okj, bd = pcall(function() return HttpService:JSONDecode(res.Body) end)
if okj and type(bd) == "table" and type(bd.data) == "table" then
for _, item in ipairs(bd.data) do
if type(item) == "table" and item.imageUrl == thumbUrl then
for j = idx, last do
if tokens[j] == item.requestId then
found = owner[j]
break
end
end
if found then return true end
end
end
end
else
postFailed = true
return true
end
idx = last + 1
task.wait(0.4)
end
return false
end)
if gen ~= searchGen then return end
hooks.progress(0)
if found then
local rec = allServers[found.id]
if not rec then
rec = {
id = found.id, placeId = K.PLACE_ID, playing = tonumber(found.playing) or 0,
maxPlayers = tonumber(found.maxPlayers) or 0, fetchedAt = os.time(), seen = 1,
}
end
rec.source = "friend"
hooks.found(rec)
addLog(T("fd_found", rec.playing, rec.maxPlayers))
if S.notifyMatch then
task.spawn(function()
sendWebhook(T("fd_webhook", name, rec.playing, rec.maxPlayers), true)
end)
end
return finish(T("fd_found", rec.playing, rec.maxPlayers))
end
if limitedNow or (not okFlag and why == "ratelimit") then return finish(T("fd_limited")) end
if postFailed or (not okFlag) then return finish(T("fd_err", tostring(why))) end
return finish(T("fd_nf"))
end)
return true
end
local function postArrivalCheck()
local pv = S.pendingVerify
if type(pv) ~= "table" then return end
S.pendingVerify = false
saveSettings()
if (os.time() - (pv.at or 0)) > 900 then return end
if not game:IsLoaded() then game.Loaded:Wait() end
local loadSec = os.time() - (pv.at or os.time())
task.wait(5)
if not alive() then return end
local actual = #Players:GetPlayers()
local maxP = Players.MaxPlayers
local ping = nil
for _ = 1, 4 do
ping = getMyPing()
if ping then break end
task.wait(1.5)
if not alive() then return end
end
local verdict = T("verdict_unknown")
if ping then
if ping <= 100 then verdict = T("verdict_near")
elseif ping <= 200 then verdict = T("verdict_mid")
else verdict = T("verdict_far") end
end
local star = starsFor(ping, loadSec)
local arrivedOk = (pv.id == nil) or (pv.id == game.JobId)
local entry = nil
if pv.hat and pv.id then entry = histFind(pv.hat, pv.id) end
if entry then
entry.ok = arrivedOk
if not arrivedOk then entry.why = "other" end
entry.ping = ping
entry.sec = loadSec
entry.star = star
end
if pv.id and arrivedOk then
local fav = findFavorite(pv.id)
if fav then
fav.fails = 0
fav.miss = 0
end
end
setStatus(string.format("Haider confirmed: %d/%d • %s %s", actual, maxP, T("ping_you"), ping and (ping .. "ms") or "—"))
if pv.expected and pv.expected >= 0 then
addLog(T("log_arrive_exp", actual, maxP, pv.expected))
else
addLog(T("log_arrive", actual, maxP))
end
addLog(T("log_arrive2", loadSec, ping and (ping .. "ms") or "—", verdict, starText(star)))
if not arrivedOk then addLog(T("log_mismatch")) end
if ping and ping <= 100 then addLog(T("log_near")) end
table.insert(P.joinStats, 1, { sec = loadSec, ping = ping or -1, ts = os.time() })
while #P.joinStats > 10 do table.remove(P.joinStats) end
saveSettings()
if F.writeLog then F.writeLog() end
if S.notifyArrival then
task.spawn(function()
sendWebhook(T("wh_arrive", actual, maxP, ping and (ping .. "ms") or "—", loadSec, starText(star)), true)
end)
end
end
local CT = { flying = false, noclip = false, origSpeed = nil, origJump = nil, origUseJP = nil, flyUp = false, flyDown = false, bv = nil, bg = nil }
CT.cc = setmetatable({}, { __mode = "k" })
local function getHum()
local c = LocalPlayer.Character
return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
local c = LocalPlayer.Character
return c and c:FindFirstChild("HumanoidRootPart")
end
local function restoreSpeed()
local h = getHum()
if h and CT.origSpeed then h.WalkSpeed = CT.origSpeed end
CT.origSpeed = nil
end
local function restoreJump()
local h = getHum()
if h and CT.origJump then
pcall(function()
h.UseJumpPower = CT.origUseJP
h.JumpPower = CT.origJump
end)
end
CT.origJump = nil
end
local function stopFly()
CT.flying = false
if CT.bv then CT.bv:Destroy() CT.bv = nil end
if CT.bg then CT.bg:Destroy() CT.bg = nil end
local h = getHum()
if h then pcall(function() h.PlatformStand = false end) end
if F.flyUi then F.flyUi(false) end
end
local function startFly()
local root, h = getRoot(), getHum()
if not root or not h then return false end
stopFly()
local bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
bv.Velocity = Vector3.zero
bv.Parent = root
local bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
bg.P = 90000
bg.CFrame = root.CFrame
bg.Parent = root
CT.bv, CT.bg = bv, bg
h.PlatformStand = true
CT.flying = true
if F.flyUi then F.flyUi(true) end
return true
end
local function setNoclip(v)
CT.noclip = v
if not v then
for part, old in pairs(CT.cc) do
if part.Parent then part.CanCollide = old end
end
CT.cc = setmetatable({}, { __mode = "k" })
end
end
local function stopAllControls()
P.ctrl.speedOn = false
P.ctrl.jumpOn = false
stopFly()
setNoclip(false)
restoreSpeed()
restoreJump()
saveSettings()
end
local function ctrlStep(dt)
local c = P.ctrl
local h = getHum()
if h then
if c.speedOn then
if not CT.origSpeed then CT.origSpeed = h.WalkSpeed end
h.WalkSpeed = c.speed
elseif CT.origSpeed then
restoreSpeed()
end
if c.jumpOn then
if not CT.origJump then
CT.origJump = h.JumpPower
CT.origUseJP = h.UseJumpPower
end
h.UseJumpPower = true
h.JumpPower = c.jump
elseif CT.origJump then
restoreJump()
end
end
if not CT.flying then CT.lastPos = nil end
if CT.flying then
local root = getRoot()
local cam = workspace.CurrentCamera
if not root or not h or not cam or h.Health <= 0 or not CT.bv or CT.bv.Parent ~= root then
stopFly()
else
local pos = root.Position
if CT.lastPos and dt and (pos - CT.lastPos).Magnitude > math.max(c.flySpeed, 80) * math.max(dt, 0.03) * 5 + 25 then
CT.lastPos = nil
stopAllControls()
setStatus(T("ct_rubber"))
addLog(T("ct_rubber"))
return
end
CT.lastPos = pos
local cf = cam.CFrame
local md = h.MoveDirection
local dir = Vector3.zero
if md.Magnitude > 0 then
local mv = cf:VectorToObjectSpace(md / md.Magnitude)
dir = cf.RightVector * mv.X + cf.LookVector * (-mv.Z)
if dir.Magnitude > 0 then dir = dir.Unit end
end
local up = 0
local typing = UserInputService:GetFocusedTextBox() ~= nil
if CT.flyUp or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.Space)) then up = up + 1 end
if CT.flyDown or (not typing and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)) then up = up - 1 end
CT.bv.Velocity = dir * c.flySpeed + Vector3.new(0, up * c.flySpeed, 0)
CT.bg.CFrame = cf
end
end
if CT.noclip then
local ch = LocalPlayer.Character
if ch then
for _, part in ipairs(ch:GetDescendants()) do
if part:IsA("BasePart") then
if CT.cc[part] == nil then CT.cc[part] = part.CanCollide end
part.CanCollide = false
end
end
end
end
end
local ESP = { targets = {}, scanning = false, dirty = true, tags = {}, friendTags = {}, friendCache = {} }
ESP.folder = Instance.new("Folder")
ESP.folder.Name = "HaiderViewESP"
ESP.folder.Parent = PlayerGui
local function nameMatches(name, keys)
for _, k in ipairs(keys) do
if string.find(name, k, 1, true) then return true end
end
return false
end
local function isPlayerChar(inst)
local a = inst
while a and a ~= workspace do
if Players:GetPlayerFromCharacter(a) then return true end
a = a.Parent
end
return false
end
local function ancestorMatches(inst, keys)
local a = inst.Parent
while a and a ~= workspace do
if a:IsA("Model") and nameMatches(string.lower(a.Name), keys) then return true end
a = a.Parent
end
return false
end
local function espScan()
if ESP.scanning then return end
ESP.scanning = true
local keys = P.esp.names
local useNpc = P.esp.npc
local list = {}
local n = 0
local ok, err = pcall(function()
for _, inst in ipairs(workspace:GetDescendants()) do
n = n + 1
if n % 1500 == 0 then task.wait() end
if #list >= 400 then break end
local isModel, isPart = inst:IsA("Model"), inst:IsA("BasePart")
if isModel or isPart then
local kind = nil
if #keys > 0 and nameMatches(string.lower(inst.Name), keys) and not ancestorMatches(inst, keys) then
kind = "obj"
elseif useNpc and isModel and inst:FindFirstChildOfClass("Humanoid") then
kind = "npc"
end
if kind and not isPlayerChar(inst) then
table.insert(list, { inst = inst, name = inst.Name, kind = kind })
end
end
end
end)
if not ok then addError("esp", err) end
ESP.targets = list
ESP.scanning = false
end
local function adorneeOf(inst)
if inst:IsA("BasePart") then return inst end
return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end
local function targetPos(inst)
if inst:IsA("BasePart") then return inst.Position end
local ok, cf = pcall(function() return inst:GetPivot() end)
if ok and cf then return cf.Position end
return nil
end
local function makeTag(adornee, color, maxDist)
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.new(0, 120, 0, 30)
bb.AlwaysOnTop = true
bb.StudsOffset = Vector3.new(0, 2, 0)
bb.MaxDistance = maxDist
bb.Adornee = adornee
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.Size = UDim2.new(1, 0, 1, 0)
l.Font = Enum.Font.GothamBold
l.TextSize = 12
l.TextColor3 = color
l.TextStrokeTransparency = 0.3
l.Text = ""
l.Parent = bb
bb.Parent = ESP.folder
return { gui = bb, label = l }
end
local function espClear()
for _, t in pairs(ESP.tags) do t.gui:Destroy() end
for _, t in pairs(ESP.friendTags) do t.gui:Destroy() end
ESP.tags, ESP.friendTags = {}, {}
if UI.ArrowLbl and UI.ArrowLbl.Parent then UI.ArrowLbl.Visible = false end
if UI.ArrowTxt and UI.ArrowTxt.Parent then UI.ArrowTxt.Visible = false end
end
local function friendStatus(plr)
local v = ESP.friendCache[plr.UserId]
if v == nil then
ESP.friendCache[plr.UserId] = "wait"
task.spawn(function()
local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
ESP.friendCache[plr.UserId] = (ok and res == true)
end)
return false
end
return v == true
end
local function espStep()
local th = THEMES[S.themeIndex] or THEMES[1]
local e = P.esp
local root = getRoot()
local cam = workspace.CurrentCamera
if not root or not cam then return end
local entries = {}
if e.on then
for _, t in ipairs(ESP.targets) do
local inst = t.inst
if inst.Parent then
local pos = targetPos(inst)
if pos then
local d = (pos - root.Position).Magnitude
if d <= e.dist then table.insert(entries, { t = t, pos = pos, d = d }) end
end
end
end
table.sort(entries, function(a, b) return a.d < b.d end)
while #entries > e.max do table.remove(entries) end
end
local keep = {}
for _, en in ipairs(entries) do
local inst = en.t.inst
keep[inst] = true
local tag = ESP.tags[inst]
if not tag then
local ad = adorneeOf(inst)
if ad then
tag = makeTag(ad, (en.t.kind == "npc") and th.warn or th.gold, e.dist)
ESP.tags[inst] = tag
end
end
if tag then tag.label.Text = en.t.name .. "\n" .. math.floor(en.d) .. " m" end
end
for inst, tag in pairs(ESP.tags) do
if not keep[inst] then
tag.gui:Destroy()
ESP.tags[inst] = nil
end
end
local fkeep = {}
if e.friends then
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer and friendStatus(plr) then
local head = plr.Character and plr.Character:FindFirstChild("Head")
if head then
fkeep[plr] = true
local tag = ESP.friendTags[plr]
if not tag then
tag = makeTag(head, th.good, 5000)
ESP.friendTags[plr] = tag
end
local d = (head.Position - root.Position).Magnitude
tag.label.Text = plr.DisplayName .. "\n" .. math.floor(d) .. " m"
end
end
end
end
for plr, tag in pairs(ESP.friendTags) do
if not fkeep[plr] then
tag.gui:Destroy()
ESP.friendTags[plr] = nil
end
end
local arrow, arrowTxt = UI.ArrowLbl, UI.ArrowTxt
if arrow and arrow.Parent and arrowTxt then
local first = entries[1]
if e.on and e.arrow and first then
local _, onScreen = cam:WorldToViewportPoint(first.pos)
if onScreen then
arrow.Visible = false
else
local rel = cam.CFrame:PointToObjectSpace(first.pos)
local vx, vy = rel.X, -rel.Y
local mag = math.sqrt(vx * vx + vy * vy)
if mag < 0.001 then
vx, vy, mag = 0, 1, 1
end
vx, vy = vx / mag, vy / mag
local size = UI.ScreenGui.AbsoluteSize
local radius = math.min(size.X, size.Y) * 0.36
local px, py = size.X / 2 + vx * radius, size.Y / 2 + vy * radius
arrow.Position = UDim2.new(0, px, 0, py)
arrow.Rotation = math.deg(math.atan2(vy, vx))
arrowTxt.Position = UDim2.new(0, px, 0, py + 24)
arrowTxt.Text = first.t.name .. " • " .. math.floor(first.d) .. " m"
arrow.Visible = true
end
else
arrow.Visible = false
end
arrowTxt.Visible = arrow.Visible
end
end
local MAPINFO = { name = nil, leader = false, tools = {}, remotes = 0, genre = "general", cands = {}, at = 0 }
local PRESETS = { "egg", "chest", "crate", "coin", "cash", "gem", "orb", "key", "fruit", "present" }
local GENERIC = {
part = true, baseplate = true, wedge = true, model = true, union = true, mesh = true, handle = true,
terrain = true, spawn = true, wall = true, floor = true, tree = true, grass = true, rock = true,
brick = true, block = true, folder = true, base = true, fence = true, road = true, stone = true,
}
local function detectMap()
local info = { name = nil, leader = false, tools = {}, remotes = 0, genre = "general", cands = {}, at = os.time() }
pcall(function()
info.name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)
if not info.name then info.name = GI.name or tostring(game.PlaceId) end
for _, plr in ipairs(Players:GetPlayers()) do
if plr:FindFirstChild("leaderstats") then
info.leader = true
break
end
end
pcall(function()
for _, parent in ipairs({ LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character }) do
if parent then
for _, it in ipairs(parent:GetChildren()) do
if it:IsA("Tool") and #info.tools < 8 then table.insert(info.tools, it.Name) end
end
end
end
end)
pcall(function()
local n = 0
for _, inst in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
n = n + 1
if n % 2000 == 0 then task.wait() end
if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then info.remotes = info.remotes + 1 end
end
end)
local counts = {}
local n = 0
pcall(function()
for _, inst in ipairs(workspace:GetDescendants()) do
n = n + 1
if n % 1500 == 0 then task.wait() end
if (inst:IsA("Model") or inst:IsA("BasePart")) and not isPlayerChar(inst) then
local nm = string.lower(inst.Name)
nm = string.gsub(nm, "[%d_%s%-%.]+$", "")
if #nm >= 3 and #nm <= 24 and not GENERIC[nm] then counts[nm] = (counts[nm] or 0) + 1 end
end
end
end)
local list = {}
for nm, c in pairs(counts) do
local preset = false
for _, p in ipairs(PRESETS) do
if string.find(nm, p, 1, true) then preset = true end
end
if preset or c >= 6 then table.insert(list, { name = nm, count = c, preset = preset }) end
end
table.sort(list, function(a, b)
if a.preset ~= b.preset then return a.preset end
if a.count ~= b.count then return a.count > b.count end
return a.name < b.name
end)
while #list > 12 do table.remove(list) end
info.cands = list
local lname = string.lower(info.name or "")
local blob = lname .. " " .. string.lower(table.concat(info.tools, " "))
local genre = "general"
for _, w in ipairs({ "egg", "farm", "tycoon", "simulator", "garden", "grow", "pet" }) do
if string.find(blob, w, 1, true) then genre = "farm" end
end
for _, w in ipairs({ "sword", "gun", "rifle", "pistol", "blaster", "war", "fight", "battle", "shoot", "murder" }) do
if string.find(blob, w, 1, true) then genre = "combat" end
end
info.genre = genre
MAPINFO = info
return info
end
local function mapReport()
local lines = { "Haider View map report | PlaceId " .. tostring(game.PlaceId) .. " | " .. tostring(MAPINFO.name) }
table.insert(lines, "genre=" .. MAPINFO.genre .. " leaderstats=" .. tostring(MAPINFO.leader) .. " remotes=" .. MAPINFO.remotes)
table.insert(lines, "tools: " .. table.concat(MAPINFO.tools, ", "))
local c = {}
for _, x in ipairs(MAPINFO.cands) do table.insert(c, x.name .. "x" .. x.count) end
table.insert(lines, "objects: " .. table.concat(c, ", "))
table.insert(lines, "esp keywords: " .. table.concat(P.esp.names, ", "))
return table.concat(lines, "\n")
end
local function addEspKeyword(word)
word = string.lower(string.gsub(tostring(word or ""), "%s", ""))
if #word < 2 or #word > 30 or #P.esp.names >= 20 then return false end
for _, k in ipairs(P.esp.names) do
if k == word then return false end
end
table.insert(P.esp.names, word)
ESP.dirty = true
saveSettings()
return true
end
local function autoAdaptMap()
if P.mapSeen then return end
P.mapSeen = true
local added = {}
for _, x in ipairs(MAPINFO.cands) do
if x.preset and #added < 6 and addEspKeyword(x.name) then table.insert(added, x.name) end
end
saveSettings()
if #added > 0 then addLog(T("map_auto", table.concat(added, ", "))) end
end
local IMG_CACHE = {}
local function resolveImage(url)
if type(url) ~= "string" or url == "" then return nil end
if string.match(url, "^rbxassetid://%d+$") then return url end
if string.match(url, "^%d+$") then return "rbxassetid://" .. url end
if not string.match(url, "^https://") then return nil end
if IMG_CACHE[url] then return IMG_CACHE[url] end
if not canPersist() or typeof(getcustomasset) ~= "function" then return nil end
local req = getRequestFn()
if not req then return nil end
local ok, res = pcall(req, { Url = url, Method = "GET" })
if not ok or type(res) ~= "table" or tonumber(res.StatusCode) ~= 200 then return nil end
local body = res.Body
if type(body) ~= "string" or #body < 100 or #body > 8000000 then return nil end
local fname = "HaiderView_img_" .. checksum(url) .. ".png"
if not pcall(writefile, fname, body) then return nil end
local okc, asset = pcall(getcustomasset, fname)
if okc and type(asset) == "string" then
IMG_CACHE[url] = asset
return asset
end
return nil
end
local AI = { busy = false, last = "" }
function AI.context()
local parts = { "Map: " .. tostring(MAPINFO.name or GI.name or game.PlaceId) }
if MAPINFO.at > 0 then
table.insert(parts, "Genre: " .. MAPINFO.genre)
local c = {}
for _, x in ipairs(MAPINFO.cands) do table.insert(c, x.name .. " x" .. x.count) end
if #c > 0 then table.insert(parts, "Frequent objects: " .. table.concat(c, ", ")) end
end
table.insert(parts, string.format("Filters: players %d-%d, ping<=%d, fps>=%d", P.minPlayers, P.maxPlayers, P.maxPing, P.minFps))
if #P.esp.names > 0 then table.insert(parts, "ESP keywords: " .. table.concat(P.esp.names, ", ")) end
return table.concat(parts, "\n")
end
-- ===== AI Multi Search (ULTRA) — free, no user key needed =====
local AIMS = {
    token = nil,
    expiry = 0,
    key = "AIzaSyA27E7jUV8osRY7NzwP2fZwGoTkp5gJhZw",
    url = "https://ai-multi-search-backend-321697147922.europe-west6.run.app/ask",
    providers = {
        { name = "claude",     ver = "1.2.8",    sid = "825a35c5-aac2-49d7-8317-5b7a68ae6cae" },
        { name = "deepseek",   ver = "1.2.8",    sid = "f0a6705c-e33e-4288-a3ef-c91cd6564b59" },
        { name = "openai",     ver = "DEV_TEST", sid = "f0a6705c-e33e-4288-a3ef-c91cd6564b59" },
        { name = "gemini",     ver = "1.2.8",    sid = "b2ed082e-5793-4de0-9e42-c8c7fb57b5d5" },
        { name = "perplexity", ver = "1.2.8",    sid = "825a35c5-aac2-49d7-8317-5b7a68ae6cae" },
        { name = "llama",      ver = "1.2.8",    sid = "b2ed082e-5793-4de0-9e42-c8c7fb57b5d5" },
    },
}
local function aimsToken()
    if AIMS.token and os.time() < AIMS.expiry - 60 then return AIMS.token end
    local req = getRequestFn()
    if not req then return nil end
    local ok, res = pcall(req, {
        Url = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=" .. AIMS.key,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = '{"clientType":"CLIENT_TYPE_ANDROID"}',
    })
    if not ok or type(res) ~= "table" then return nil end
    local code = tonumber(res.StatusCode) or 0
    if code < 200 or code >= 300 or type(res.Body) ~= "string" then return nil end
    local okj, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not okj or type(data) ~= "table" or type(data.idToken) ~= "string" then return nil end
    AIMS.token = "Bearer " .. data.idToken
    AIMS.expiry = os.time() + tonumber(data.expiresIn or 3600)
    return AIMS.token
end
local function aimsAsk(p, prompt)
    local token = aimsToken()
    if not token then return nil, "ai_err_net" end
    local req = getRequestFn()
    if not req then return nil, "ai_err_net" end
    local ok, res = pcall(req, {
        Url = AIMS.url,
        Method = "POST",
        Headers = {
            ["User-Agent"] = "okhttp/4.12.0",
            ["Accept-Encoding"] = "gzip",
            ["authorization"] = token,
            ["x-plan"] = "ULTRA",
            ["x-app-version"] = p.ver,
            ["x-search-id"] = p.sid,
            ["x-search-expected"] = "2",
            ["content-type"] = "application/json; charset=utf-8",
        },
        Body = HttpService:JSONEncode({
            provider = p.name,
            prompt = prompt,
            plan = "ULTRA",
            app_version = p.ver,
        }),
    })
    if not ok or type(res) ~= "table" then return nil, "ai_err_net" end
    local code = tonumber(res.StatusCode) or 0
    if code == 429 then return nil, "ai_err_rate" end
    if code < 200 or code >= 300 or type(res.Body) ~= "string" then return nil, "ai_err_net" end
    local okj, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not okj or type(data) ~= "table" then return nil, "ai_err_net" end
    if data.ok and type(data.answer) == "string" and data.answer ~= "" then
        return data.answer
    end
    return nil, "ai_err_empty"
end
function AI.call(userText, withCtx)
local sys = "You are a helper inside a Roblox server-hopper script. Be brief. Reply in "
.. ((S.lang == "ar") and "Arabic" or "English")
.. ". Never write code to execute and never help harm or track other players."
local content = userText
if withCtx then content = AI.context() .. "\n\n" .. userText end

-- 1) ULTRA providers (free, no user key)
local fullPrompt = string.sub(sys .. "\n\n" .. content, 1, 3000)
local lastErr = "ai_err_net"
for _, p in ipairs(AIMS.providers) do
    local txt, err = aimsAsk(p, fullPrompt)
    if txt then return txt end
    if err then lastErr = err end
    task.wait(0.2)
end

-- 2) User OpenRouter key (if provided)
if S.aiKey ~= "" then
    local req = getRequestFn()
    if req then
        local ok, res = pcall(req, {
            Url = "https://openrouter.ai/api/v1/chat/completions",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. S.aiKey },
            Body = HttpService:JSONEncode({
                model = S.aiModel,
                max_tokens = 500,
                messages = { { role = "system", content = sys }, { role = "user", content = content } },
            }),
        })
        if ok and type(res) == "table" then
            local code = tonumber(res.StatusCode) or 0
            if code == 401 or code == 403 then return nil, "ai_err_key" end
            if code == 402 then return nil, "ai_err_pay" end
            if code == 429 then return nil, "ai_err_rate" end
            if code >= 200 and code < 300 and type(res.Body) == "string" then
                local okj, d = pcall(function() return HttpService:JSONDecode(res.Body) end)
                local msg = okj and type(d) == "table" and type(d.choices) == "table"
                    and type(d.choices[1]) == "table" and type(d.choices[1].message) == "table"
                    and d.choices[1].message.content
                if type(msg) == "string" and msg ~= "" then return msg end
            end
        end
    end
end

-- 3) Final fallback: pollinations
local prompt = string.sub(sys .. "\n\n" .. content, 1, 1500)
local body = rawHttpGet("https://text.pollinations.ai/" .. HttpService:UrlEncode(prompt))
if type(body) == "string" and body ~= "" then return body end

return nil, lastErr
end
function AI.ask(userText, withCtx, onDone)
if AI.busy then return false end
AI.busy = true
task.spawn(function()
local ok, text, err = pcall(AI.call, userText, withCtx)
AI.busy = false
if not ok then
addError("ai", text)
text, err = nil, "ai_err_net"
end
onDone(text, err)
end)
return true
end
function AI.parseKeywords(text)
local out, seen = {}, {}
for w in string.gmatch(string.lower(text), "[a-z][a-z0-9_]+") do
if #w >= 2 and #w <= 20 and not seen[w] and w ~= "keywords" and w ~= "and" and w ~= "the" then
seen[w] = true
table.insert(out, w)
if #out >= 6 then break end
end
end
return out
end
function F.selfTest()
local rows = {}
local function add(key, ok, note)
table.insert(rows, { name = T(key), ok = ok, note = note })
end
local okS = false
if canPersist() then
okS = pcall(function()
local tmp = "HaiderViewServer_test.txt"
writefile(tmp, "ok")
if readfile(tmp) ~= "ok" then error("mismatch") end
if typeof(delfile) == "function" then delfile(tmp) end
end)
end
add("stn_storage", okS)
add("stn_json", (pcall(function()
local d = HttpService:JSONDecode(HttpService:JSONEncode(S))
if type(d) ~= "table" then error("bad") end
end)))
local okB = false
local code = buildBackupCode()
if code then
local cs, body = string.match(code, "^HVB1:(%x+):([%w%+/=]+)$")
if cs and checksum(body) == cs then
local j = b64decode(body)
okB = (j ~= nil) and (pcall(function() HttpService:JSONDecode(j) end))
end
end
add("stn_backup", okB)
local body, why = httpGetTracked(serverListUrl(nil))
local okSv, note = false, tostring(why or "")
if body then
local okj, d = pcall(function() return HttpService:JSONDecode(body) end)
if okj and type(d) == "table" and type(d.data) == "table" then
okSv = true
note = tostring(#d.data)
end
end
add("stn_servers", okSv, note)
add("stn_char", getHum() ~= nil and getRoot() ~= nil)
add("stn_bodyvel", (pcall(function()
local bv = Instance.new("BodyVelocity")
local bg = Instance.new("BodyGyro")
bv:Destroy()
bg:Destroy()
end)))
add("stn_camera", workspace.CurrentCamera ~= nil)
local okW, nW = pcall(function() return #workspace:GetDescendants() end)
add("stn_ws", okW, okW and tostring(nW) or nil)
local miss = 0
for k, _ in pairs(L.ar) do
if L.en[k] == nil then miss = miss + 1 end
end
for k, _ in pairs(L.en) do
if L.ar[k] == nil then miss = miss + 1 end
end
add("stn_i18n", miss == 0, (miss > 0) and tostring(miss) or nil)
add("stn_ui", UI.ScreenGui ~= nil and UI.ScreenGui.Parent ~= nil)
add("stn_tp", (pcall(function() return TeleportService.TeleportInitFailed end)))
add("stn_img", typeof(getcustomasset) == "function" and canPersist() and getRequestFn() ~= nil)
local lines = {}
for _, r in ipairs(rows) do
table.insert(lines, (r.ok and "OK " or "FAIL ") .. r.name .. (r.note and (" (" .. r.note .. ")") or ""))
end
F.lastSelfTest = table.concat(lines, "\n")
return rows
end
local TABS = {
{ key = "main",    icon = "🏠", tk = "tab_main" },
{ key = "players", icon = "👥", tk = "tab_players" },
{ key = "board",   icon = "🏆", tk = "tab_board" },
{ key = "find",    icon = "🔎", tk = "tab_find" },
{ key = "fav",     icon = "⭐", tk = "tab_fav" },
{ key = "stats",   icon = "📊", tk = "tab_stats" },
{ key = "filt",    icon = "🔍", tk = "tab_filt" },
{ key = "theme",   icon = "🎨", tk = "tab_theme" },
{ key = "log",     icon = "📜", tk = "tab_log" },
{ key = "ctrl",    icon = "🎮", tk = "tab_ctrl" },
{ key = "esp",     icon = "🎯", tk = "tab_esp" },
{ key = "ai",      icon = "🤖", tk = "tab_ai" },
{ key = "tools",   icon = "🧰", tk = "tab_tools" },
{ key = "set",     icon = "⚙",  tk = "tab_set" },
}
local UI_CONNS = {}
local function buildUI()
for _, c in ipairs(UI_CONNS) do pcall(function() c:Disconnect() end) end
UI_CONNS = {}
if UI.ScreenGui then UI.ScreenGui:Destroy() end
local theme = THEMES[S.themeIndex] or THEMES[1]
local function track(conn) table.insert(UI_CONNS, conn) return conn end
local function corner(p, r)
if theme.sharp and r < 100 then r = math.min(r, 3) end
local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c
end
local function strokeF(p, col, th)
local s = Instance.new("UIStroke")
s.Color = col
s.Thickness = th or 1
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Parent = p
return s
end
local function padF(p, a)
local u = Instance.new("UIPadding")
u.PaddingTop, u.PaddingBottom, u.PaddingLeft, u.PaddingRight = UDim.new(0,a), UDim.new(0,a), UDim.new(0,a), UDim.new(0,a)
u.Parent = p
return u
end
local function label(p, props)
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.Font = props.font or Enum.Font.GothamBold
l.TextColor3 = props.color or theme.text
l.TextTransparency = props.transparency or 0
l.TextSize = props.size or 14
l.Text = props.text or ""
l.TextXAlignment = props.align or Enum.TextXAlignment.Left
l.TextYAlignment = props.valign or Enum.TextYAlignment.Center
l.TextWrapped = true
if props.truncate then
l.TextWrapped = false
l.TextTruncate = Enum.TextTruncate.AtEnd
end
l.ZIndex = props.z or 1
l.Size = props.size2 or UDim2.new(1, 0, 1, 0)
l.Position = props.pos or UDim2.new(0, 0, 0, 0)
l.Parent = p
return l
end
local function button(p, text, bg, size, pos)
local b = Instance.new("TextButton")
b.AutoButtonColor = false
b.Text = text
b.Font = Enum.Font.GothamBold
b.TextSize = 12
b.TextColor3 = theme.text
b.BackgroundColor3 = bg
b.Size = size
b.Position = pos
b.Parent = p
corner(b, 6)
strokeF(b, theme.steel, 1)
return b
end
local function toggleSwitch(p, pos, initial, onChange)
local holder = Instance.new("Frame")
holder.Size = UDim2.new(0, 42, 0, 22)
holder.Position = pos
holder.BackgroundColor3 = initial and theme.accent or theme.steel
holder.Parent = p
corner(holder, 11)
local knob = Instance.new("Frame")
knob.Size = UDim2.new(0, 18, 0, 18)
knob.Position = initial and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
knob.BackgroundColor3 = theme.text
knob.Parent = holder
corner(knob, 9)
local state = initial
local btn = Instance.new("TextButton")
btn.BackgroundTransparency = 1
btn.Text = ""
btn.Size = UDim2.new(1, 0, 1, 0)
btn.Parent = holder
btn.MouseButton1Click:Connect(function()
state = not state
TweenService:Create(holder, TweenInfo.new(0.15), { BackgroundColor3 = state and theme.accent or theme.steel }):Play()
TweenService:Create(knob, TweenInfo.new(0.15), { Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }):Play()
onChange(state)
end)
return holder
end
local function viewportSize()
local cam = workspace.CurrentCamera
if cam then return cam.ViewportSize end
return Vector2.new(800, 400)
end
local function clampToScreen(frame)
if not UI.ScreenGui then return end
local screen = UI.ScreenGui.AbsoluteSize
local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
local minVis = 56
local dx, dy = 0, 0
if pos.X + size.X < minVis then dx = minVis - (pos.X + size.X)
elseif pos.X > screen.X - minVis then dx = (screen.X - minVis) - pos.X end
if pos.Y < 0 then dy = -pos.Y
elseif pos.Y > screen.Y - 40 then dy = (screen.Y - 40) - pos.Y end
if dx ~= 0 or dy ~= 0 then
frame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset + dx,
frame.Position.Y.Scale, frame.Position.Y.Offset + dy)
end
end
local function isPointerInput(input)
return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isMoveInput(input)
return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end
local function makeDraggable(frame, handle, onEnd)
local dragging, dragStart, startPos, moved = false, nil, nil, false
handle.InputBegan:Connect(function(input)
if isPointerInput(input) then
dragging = true
moved = false
dragStart = input.Position
startPos = frame.Position
end
end)
track(UserInputService.InputChanged:Connect(function(input)
if dragging and isMoveInput(input) then
local delta = input.Position - dragStart
if delta.Magnitude > 6 then moved = true end
if moved then
frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
clampToScreen(frame)
end
end
end))
track(UserInputService.InputEnded:Connect(function(input)
if dragging and isPointerInput(input) then
dragging = false
if moved and onEnd then onEnd() end
end
end))
return function() return moved end
end
local function makeResizable(frame, handle, minSize, maxSizeFn, onEnd, axis)
axis = axis or "xy"
local resizing, dragStart, startSize = false, nil, nil
handle.InputBegan:Connect(function(input)
if isPointerInput(input) then
resizing = true
dragStart = input.Position
startSize = frame.Size
end
end)
track(UserInputService.InputChanged:Connect(function(input)
if resizing and isMoveInput(input) then
local delta = input.Position - dragStart
local mx = maxSizeFn()
local newW, newH = startSize.X.Offset, startSize.Y.Offset
if axis ~= "y" then newW = math.clamp(startSize.X.Offset + delta.X, minSize.X, mx.X) end
if axis ~= "x" then newH = math.clamp(startSize.Y.Offset + delta.Y, minSize.Y, mx.Y) end
frame.Size = UDim2.new(0, newW, 0, newH)
end
end))
track(UserInputService.InputEnded:Connect(function(input)
if resizing and isPointerInput(input) then
resizing = false
if onEnd then onEnd() end
end
end))
end
local function makeResizableSquare(frame, handle, minSize, maxSize, onResize, onEnd)
local resizing, dragStart, startSize = false, nil, nil
handle.InputBegan:Connect(function(input)
if isPointerInput(input) then
resizing = true
dragStart = input.Position
startSize = frame.Size
end
end)
track(UserInputService.InputChanged:Connect(function(input)
if resizing and isMoveInput(input) then
local delta = input.Position - dragStart
local d = math.clamp(startSize.X.Offset + math.max(delta.X, delta.Y), minSize, maxSize)
frame.Size = UDim2.new(0, d, 0, d)
if onResize then onResize(d) end
end
end))
track(UserInputService.InputEnded:Connect(function(input)
if resizing and isPointerInput(input) then
resizing = false
if onEnd then onEnd() end
end
end))
end
local function sizeLevelText(w)
if w <= 320 then return S.lang == "ar" and "صغير" or "S"
elseif w <= 420 then return S.lang == "ar" and "متوسط" or "M"
elseif w <= 500 then return S.lang == "ar" and "كبير" or "L"
else return S.lang == "ar" and "ضخم" or "XL" end
end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = K.GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui
UI.ScreenGui = ScreenGui
local Toggle = Instance.new("Frame")
Toggle.Name = "ToggleCircle"
Toggle.Size = UDim2.new(0, S.toggleSize[1], 0, S.toggleSize[2])
Toggle.Position = ud2(S.togglePos)
Toggle.BackgroundColor3 = theme.bg
Toggle.ZIndex = 20
Toggle.Parent = ScreenGui
corner(Toggle, 1000)
local ringStroke = strokeF(Toggle, theme.text, 3)
local ringGrad = Instance.new("UIGradient")
ringGrad.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0),
})
ringGrad.Parent = ringStroke
local Disc = Instance.new("Frame")
Disc.AnchorPoint = Vector2.new(0.5, 0.5)
Disc.Position = UDim2.new(0.5, 0, 0.5, 0)
Disc.Size = UDim2.new(0.62, 0, 0.62, 0)
Disc.BackgroundColor3 = Color3.new(0, 0, 0)
Disc.ZIndex = 21
Disc.Parent = Toggle
corner(Disc, 1000)
strokeF(Disc, theme.steel, 1)
local ToggleIcon = label(Toggle, { text = "HV", size = 14, color = theme.gold, font = Enum.Font.Antique,
align = Enum.TextXAlignment.Center, z = 22 })
ToggleIcon.TextSize = math.floor(S.toggleSize[1] * 0.26)
local ToggleImage = Instance.new("ImageLabel")
ToggleImage.BackgroundTransparency = 1
ToggleImage.Size = UDim2.new(0.8, 0, 0.8, 0)
ToggleImage.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
ToggleImage.ScaleType = Enum.ScaleType.Crop
ToggleImage.ZIndex = 22
ToggleImage.Visible = false
ToggleImage.Parent = Toggle
corner(ToggleImage, 1000)
UI.ToggleImage, UI.ToggleIcon = ToggleImage, ToggleIcon
local animT, lastHot = 0, false
track(RunService.Heartbeat:Connect(function(dt)
if not S.anim then
ringStroke.Thickness = 3
return
end
animT = animT + dt
local hot = #filtered > 0
if hot ~= lastHot then
lastHot = hot
ringStroke.Color = hot and theme.bad or theme.text
end
ringGrad.Rotation = (animT * 70) % 360
ringStroke.Thickness = 3 + math.sin(animT * (hot and 4 or 2)) * (hot and 1.8 or 0.8)
local sz = 0.62 + math.sin(animT * 2) * 0.015
Disc.Size = UDim2.new(sz, 0, sz, 0)
end))
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = ""
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.ZIndex = 22
ToggleBtn.Active = true
ToggleBtn.Parent = Toggle
local ToggleResizeHandle = Instance.new("Frame")
ToggleResizeHandle.Size = UDim2.new(0, 16, 0, 16)
ToggleResizeHandle.AnchorPoint = Vector2.new(1, 1)
ToggleResizeHandle.Position = UDim2.new(1, 2, 1, 2)
ToggleResizeHandle.BackgroundColor3 = theme.gold
ToggleResizeHandle.BackgroundTransparency = 0.3
ToggleResizeHandle.Active = true
ToggleResizeHandle.ZIndex = 23
ToggleResizeHandle.Parent = Toggle
corner(ToggleResizeHandle, 1000)
local toggleWasDragged = makeDraggable(Toggle, ToggleBtn, function()
S.togglePos = { Toggle.Position.X.Scale, Toggle.Position.X.Offset, Toggle.Position.Y.Scale, Toggle.Position.Y.Offset }
saveSettings()
end)
makeResizableSquare(Toggle, ToggleResizeHandle, 40, 100, function(d)
ToggleIcon.TextSize = math.floor(d * 0.26)
end, function()
S.toggleSize = { Toggle.Size.X.Offset, Toggle.Size.Y.Offset }
saveSettings()
end)
local vp = viewportSize()
local startW = math.clamp(S.mainSize[1], 300, math.max(300, vp.X - 10))
local startH = math.clamp(S.mainSize[2], 260, math.max(260, vp.Y - 10))
local Main = Instance.new("Frame")
Main.Name = "MainWindow"
Main.Size = UDim2.new(0, startW, 0, startH)
Main.Position = ud2(S.mainPos)
Main.BackgroundColor3 = theme.bg
Main.Visible = S.windowOpen
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 10)
strokeF(Main, theme.gold, 2)
local mainGrad = Instance.new("UIGradient")
mainGrad.Rotation = 90
mainGrad.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, theme.bg), ColorSequenceKeypoint.new(1, theme.panel),
})
mainGrad.Parent = Main
local BgImage = Instance.new("ImageLabel")
BgImage.BackgroundTransparency = 1
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.ImageTransparency = 0.8
BgImage.ScaleType = Enum.ScaleType.Crop
BgImage.ZIndex = 0
BgImage.Visible = false
BgImage.Parent = Main
UI.BgImage = BgImage
local function setWindowOpen(v)
Main.Visible = v
S.windowOpen = v
saveSettings()
if v then clampToScreen(Main) end
end
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = theme.panel
Header.Active = true
Header.Parent = Main
corner(Header, 10)
makeDraggable(Main, Header, function()
S.mainPos = { Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset }
saveSettings()
end)
label(Header, { text = "HAIDER VIEW SERVER", size = 17, color = theme.gold, font = Enum.Font.Antique, align = Enum.TextXAlignment.Center })
local resizeParts = {}
local minimized = false
local savedH = startH
local CloseBtn = button(Header, "✕", theme.accent, UDim2.new(0, 26, 0, 22), UDim2.new(1, -32, 0, 7))
local MinBtn = button(Header, "—", theme.steel, UDim2.new(0, 26, 0, 22), UDim2.new(1, -62, 0, 7))
CloseBtn.MouseButton1Click:Connect(function() setWindowOpen(false) end)
MinBtn.MouseButton1Click:Connect(function()
minimized = not minimized
if minimized then
savedH = Main.Size.Y.Offset
for _, rp in ipairs(resizeParts) do rp.Visible = false end
TweenService:Create(Main, TweenInfo.new(0.18), { Size = UDim2.new(0, Main.Size.X.Offset, 0, 36) }):Play()
MinBtn.Text = "▢"
else
TweenService:Create(Main, TweenInfo.new(0.18), { Size = UDim2.new(0, Main.Size.X.Offset, 0, savedH) }):Play()
MinBtn.Text = "—"
task.delay(0.2, function() for _, rp in ipairs(resizeParts) do rp.Visible = true end end)
end
end)
for _, d in ipairs({ { 0.07, 8 }, { 0.19, 14 }, { 0.31, 6 }, { 0.46, 12 }, { 0.60, 9 }, { 0.72, 15 } }) do
local drip = Instance.new("Frame")
drip.Size = UDim2.new(0, 4, 0, d[2])
drip.Position = UDim2.new(d[1], 0, 0, 34)
drip.BackgroundColor3 = theme.accent
drip.BorderSizePixel = 0
drip.Parent = Main
corner(drip, 2)
end
local DragStrip = Instance.new("Frame")
DragStrip.Size = UDim2.new(1, 0, 0, 64)
DragStrip.Position = UDim2.new(0, 0, 0, 36)
DragStrip.BackgroundTransparency = 1
DragStrip.Active = true
DragStrip.Parent = Main
makeDraggable(Main, DragStrip, function()
S.mainPos = { Main.Position.X.Scale, Main.Position.X.Offset, Main.Position.Y.Scale, Main.Position.Y.Offset }
saveSettings()
end)
local NetDot = Instance.new("Frame")
NetDot.Size = UDim2.new(0, 9, 0, 9)
NetDot.Position = UDim2.new(0, 10, 0, 44)
NetDot.BackgroundColor3 = theme.steel
NetDot.Parent = Main
corner(NetDot, 1000)
local NetLabel = label(Main, { text = T("net_label") .. ": —", size = 10, color = theme.dim,
size2 = UDim2.new(1, -124, 0, 16), pos = UDim2.new(0, 24, 0, 40) })
UI.NetDot, UI.NetLabel = NetDot, NetLabel
local MinusBtn = button(Main, "－", theme.steel, UDim2.new(0, 22, 0, 18), UDim2.new(1, -88, 0, 41))
local SizeLabel = label(Main, { text = sizeLevelText(startW), size = 9, color = theme.dim,
align = Enum.TextXAlignment.Center, size2 = UDim2.new(0, 40, 0, 18), pos = UDim2.new(1, -62, 0, 41) })
local PlusBtn = button(Main, "＋", theme.steel, UDim2.new(0, 22, 0, 18), UDim2.new(1, -18, 0, 41))
local function maxWindowSize()
local v = viewportSize()
return Vector2.new(math.min(700, v.X - 10), math.min(900, v.Y - 10))
end
local MIN_WIN = Vector2.new(300, 260)
local function saveMainSize()
S.mainSize = { Main.Size.X.Offset, Main.Size.Y.Offset }
SizeLabel.Text = sizeLevelText(Main.Size.X.Offset)
saveSettings()
end
local function applySizeScale(factor)
if minimized then return end
local mx = maxWindowSize()
local newW = math.clamp(math.floor(Main.Size.X.Offset * factor), MIN_WIN.X, math.max(MIN_WIN.X, mx.X))
local newH = math.clamp(math.floor(Main.Size.Y.Offset * factor), MIN_WIN.Y, math.max(MIN_WIN.Y, mx.Y))
Main.Size = UDim2.new(0, newW, 0, newH)
saveMainSize()
clampToScreen(Main)
end
MinusBtn.MouseButton1Click:Connect(function() applySizeScale(0.88) end)
PlusBtn.MouseButton1Click:Connect(function() applySizeScale(1 / 0.88) end)
UI.StatusLabel = label(Main, { text = T("st_idle"), size = 11, color = theme.dim,
size2 = UDim2.new(1, -48, 0, 16), pos = UDim2.new(0, 10, 0, 62) })
UI.CountsLabel = label(Main, { text = T("counts_init"), size = 10, color = theme.text,
size2 = UDim2.new(1, -20, 0, 16), pos = UDim2.new(0, 10, 0, 79) })
local UnlockBtn = button(Main, "🔓", theme.accent, UDim2.new(0, 28, 0, 17), UDim2.new(1, -36, 0, 61))
UnlockBtn.TextSize = 11
UnlockBtn.Visible = jumping
UnlockBtn.MouseButton1Click:Connect(function() unlockTeleport() end)
UI.UnlockBtn = UnlockBtn
local ProgressTrack = Instance.new("Frame")
ProgressTrack.Size = UDim2.new(1, -20, 0, 3)
ProgressTrack.Position = UDim2.new(0, 10, 0, 96)
ProgressTrack.BackgroundColor3 = theme.panel
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Parent = Main
corner(ProgressTrack, 2)
local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = theme.accent
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressTrack
corner(ProgressFill, 2)
UI.ProgressFill = ProgressFill
local SIDEBAR_W = 64
local SPLIT_Y = 102
local BOTTOM_GAP = 16
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -(SPLIT_Y + BOTTOM_GAP))
Sidebar.Position = UDim2.new(0, 6, 0, SPLIT_Y)
Sidebar.BackgroundColor3 = theme.panel
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 2
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.Parent = Main
corner(Sidebar, 8)
strokeF(Sidebar, theme.steel, 1)
local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 4)
SideLayout.Parent = Sidebar
padF(Sidebar, 3)
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -(SIDEBAR_W + 18), 1, -(SPLIT_Y + BOTTOM_GAP))
ContentArea.Position = UDim2.new(0, SIDEBAR_W + 12, 0, SPLIT_Y)
ContentArea.BackgroundColor3 = theme.panel
ContentArea.BackgroundTransparency = 0.25
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true
ContentArea.Parent = Main
corner(ContentArea, 8)
strokeF(ContentArea, theme.steel, 1)
UI.ContentArea = ContentArea
label(Main, { text = string.rep("· ", 40), size = 10, color = theme.steel, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, -20, 0, 12), pos = UDim2.new(0, 10, 1, -14) })
local SkullGlow = Instance.new("Frame")
SkullGlow.Name = "SkullGlow"
SkullGlow.AnchorPoint = Vector2.new(0.5, 0.5)
SkullGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
SkullGlow.Size = UDim2.new(0, 150, 0, 150)
SkullGlow.BackgroundColor3 = theme.accent
SkullGlow.BackgroundTransparency = 0.86
SkullGlow.BorderSizePixel = 0
SkullGlow.ZIndex = 0
SkullGlow.Parent = ContentArea
corner(SkullGlow, 1000)
local SkullMark = label(ContentArea, { text = "💀", size = 110, color = theme.accent, transparency = 0.8,
align = Enum.TextXAlignment.Center, z = 0 })
SkullMark.Name = "SkullMark"
local tabButtons = {}
for _, t in ipairs(TABS) do
local tb = Instance.new("TextButton")
tb.AutoButtonColor = false
tb.Size = UDim2.new(1, 0, 0, 46)
tb.BackgroundColor3 = (activeTab == t.key) and theme.accent or theme.card
tb.Text = ""
tb.Parent = Sidebar
corner(tb, 8)
label(tb, { text = t.icon, size = 17, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, 0, 0, 22), pos = UDim2.new(0, 0, 0, 3) })
label(tb, { text = T(t.tk), size = 9, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, 0, 0, 16), pos = UDim2.new(0, 0, 1, -17) })
tabButtons[t.key] = tb
tb.MouseButton1Click:Connect(function() F.switchTab(t.key) end)
end
local Banner = Instance.new("Frame")
Banner.Name = "DisconnectBanner"
Banner.AnchorPoint = Vector2.new(0.5, 0)
Banner.Position = UDim2.new(0.5, 0, 0, 10)
Banner.Size = UDim2.new(0, 300, 0, 100)
Banner.BackgroundColor3 = theme.panel
Banner.ZIndex = 50
Banner.Visible = false
Banner.Parent = ScreenGui
corner(Banner, 10)
strokeF(Banner, theme.accent, 2)
local bnTitle = label(Banner, { text = T("bn_title"), size = 13, color = theme.accent, z = 51,
size2 = UDim2.new(1, -40, 0, 20), pos = UDim2.new(0, 10, 0, 6) })
local bnMsg = label(Banner, { text = "", size = 10, color = theme.dim, font = Enum.Font.Gotham, z = 51,
valign = Enum.TextYAlignment.Top, size2 = UDim2.new(1, -20, 0, 28), pos = UDim2.new(0, 10, 0, 26) })
local bnSame = button(Banner, T("bn_same"), theme.accent, UDim2.new(0.54, -12, 0, 28), UDim2.new(0, 10, 1, -36))
local bnPrev = button(Banner, T("bn_prev"), theme.steel, UDim2.new(0.46, -12, 0, 28), UDim2.new(0.54, 2, 1, -36))
local bnClose = button(Banner, "✕", theme.steel, UDim2.new(0, 24, 0, 20), UDim2.new(1, -32, 0, 6))
bnSame.ZIndex, bnPrev.ZIndex, bnClose.ZIndex = 52, 52, 52
bnSame.TextSize, bnPrev.TextSize = 10, 10
bnClose.MouseButton1Click:Connect(function() Banner.Visible = false end)
bnSame.MouseButton1Click:Connect(function()
Banner.Visible = false
rejoinSame()
end)
bnPrev.MouseButton1Click:Connect(function()
Banner.Visible = false
rejoinPrev()
end)
F.showBanner = function(msg)
if not Banner.Parent then return end
bnMsg.Text = string.sub(tostring(msg or ""), 1, 120)
bnPrev.Visible = S.prevServer ~= false
Banner.Visible = true
end
local function rowFrame(parent, order, barColor, chipText)
local R = Instance.new("Frame")
R.Size = UDim2.new(1, 0, 0, 44)
R.BackgroundColor3 = theme.card
R.LayoutOrder = order
R.Parent = parent
corner(R, 8)
strokeF(R, theme.steel, 1)
local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(0, 4, 1, 0)
Bar.BackgroundColor3 = barColor
Bar.BorderSizePixel = 0
Bar.Parent = R
corner(Bar, 4)
local Chip = Instance.new("Frame")
Chip.Size = UDim2.new(0, 26, 0, 26)
Chip.Position = UDim2.new(0, 10, 0.5, -13)
Chip.BackgroundColor3 = theme.panel
Chip.Parent = R
corner(Chip, 1000)
label(Chip, { text = chipText, size = 13, align = Enum.TextXAlignment.Center })
return R
end
local function rowButton(parent, text, bg, rightOffset, width)
local b = button(parent, text, bg, UDim2.new(0, width, 0, 28), UDim2.new(1, -rightOffset, 0.5, 0))
b.AnchorPoint = Vector2.new(1, 0.5)
b.TextSize = 11
return b
end
local function makeList(parent, topOffset)
local sf = Instance.new("ScrollingFrame")
sf.Size = UDim2.new(1, 0, 1, -topOffset)
sf.Position = UDim2.new(0, 0, 0, topOffset)
sf.BackgroundTransparency = 1
sf.BorderSizePixel = 0
sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
sf.CanvasSize = UDim2.new(0, 0, 0, 0)
sf.ScrollBarThickness = 4
sf.ScrollBarImageColor3 = theme.gold
sf.Parent = parent
local LL = Instance.new("UIListLayout")
LL.Padding = UDim.new(0, 6)
LL.SortOrder = Enum.SortOrder.LayoutOrder
LL.Parent = sf
return sf
end
local function clearRows(sf)
for _, c in ipairs(sf:GetChildren()) do
if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
end
end
local function nextOrder(sf)
local n = (sf:GetAttribute("ord") or 0) + 1
sf:SetAttribute("ord", n)
return n
end
local function newPanel(parent)
local sf = Instance.new("ScrollingFrame")
sf.Size = UDim2.new(1, 0, 1, 0)
sf.BackgroundTransparency = 1
sf.BorderSizePixel = 0
sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
sf.CanvasSize = UDim2.new(0, 0, 0, 0)
sf.ScrollBarThickness = 4
sf.ScrollBarImageColor3 = theme.gold
sf.Parent = parent
local LL = Instance.new("UIListLayout")
LL.Padding = UDim.new(0, 6)
LL.SortOrder = Enum.SortOrder.LayoutOrder
LL.Parent = sf
return sf
end
local function addHolder(sf, h)
local holder = Instance.new("Frame")
holder.Size = UDim2.new(1, -6, 0, h)
holder.BackgroundTransparency = 1
holder.LayoutOrder = nextOrder(sf)
holder.Parent = sf
return holder
end
local function addText(sf, text, opts)
opts = opts or {}
local holder = addHolder(sf, opts.h or 20)
local l = label(holder, { text = text, size = opts.size or 11, color = opts.color or theme.text,
font = opts.font, valign = opts.valign or Enum.TextYAlignment.Top, align = opts.align })
return l, holder
end
local function addButton(sf, text, bg, onClick, h)
local holder = addHolder(sf, h or 28)
local b = button(holder, text, bg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
b.MouseButton1Click:Connect(onClick)
return b, holder
end
local function addToggle(sf, text, initial, onChange)
local holder = addHolder(sf, 26)
label(holder, { text = text, size = 11, size2 = UDim2.new(1, -52, 1, 0) })
toggleSwitch(holder, UDim2.new(1, -44, 0.5, -11), initial, onChange)
return holder
end
local function addInput(sf, text, value)
local holder = addHolder(sf, 26)
label(holder, { text = text, size = 11, size2 = UDim2.new(0.6, 0, 1, 0) })
local b = Instance.new("TextBox")
b.Size = UDim2.new(0.38, 0, 0, 22)
b.Position = UDim2.new(0.62, 0, 0.5, -11)
b.Text = tostring(value)
b.BackgroundColor3 = theme.card
b.TextColor3 = theme.text
b.ClearTextOnFocus = false
b.Font = Enum.Font.Gotham
b.TextSize = 12
b.Parent = holder
corner(b, 5)
return b
end
local function addBox(sf, placeholder, h, multiline, text)
local holder = addHolder(sf, h)
local b = Instance.new("TextBox")
b.Size = UDim2.new(1, 0, 1, 0)
b.BackgroundColor3 = theme.card
b.TextColor3 = theme.text
b.PlaceholderText = placeholder or ""
b.PlaceholderColor3 = theme.dim
b.Text = text or ""
b.ClearTextOnFocus = false
b.Font = Enum.Font.Gotham
b.TextSize = 11
b.TextXAlignment = Enum.TextXAlignment.Left
b.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
b.TextWrapped = multiline and true or false
b.MultiLine = multiline and true or false
b.Parent = holder
corner(b, 6)
return b, holder
end
local function addCard(sf, text, opts)
opts = opts or {}
local fr = Instance.new("Frame")
fr.Size = UDim2.new(1, -6, 0, 0)
fr.AutomaticSize = Enum.AutomaticSize.Y
fr.BackgroundColor3 = theme.card
fr.LayoutOrder = nextOrder(sf)
fr.Parent = sf
corner(fr, 6)
padF(fr, 6)
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.Size = UDim2.new(1, 0, 0, 0)
l.AutomaticSize = Enum.AutomaticSize.Y
l.Font = opts.font or Enum.Font.Gotham
l.TextSize = opts.size or 11
l.TextColor3 = opts.color or theme.text
l.TextWrapped = true
l.TextXAlignment = Enum.TextXAlignment.Left
l.TextYAlignment = Enum.TextYAlignment.Top
l.Text = text
l.Parent = fr
return l, fr
end
local function numInput(sf, text, value, lo, hi, apply)
local cur = value
local box = addInput(sf, text, value)
box.FocusLost:Connect(function()
local n = tonumber(box.Text)
if n then
n = math.clamp(math.floor(n), lo, hi)
cur = n
apply(n)
saveSettings()
end
box.Text = tostring(cur)
end)
return box
end
local TabHolder = nil
local TAB_BUILDERS = {}
local function newHolder()
if TabHolder then TabHolder:Destroy() end
local hd = Instance.new("Frame")
hd.Size = UDim2.new(1, -8, 1, -8)
hd.Position = UDim2.new(0, 4, 0, 4)
hd.BackgroundTransparency = 1
hd.Parent = ContentArea
TabHolder = hd
return hd
end
local function verifyRow(s)
if refreshing or jumping or searching then return end
refreshing = true
setStatus("Haider verifying server...")
task.spawn(function()
local okp, res, cnt = pcall(verifyServer, s)
refreshing = false
if not okp then
addError("verify", res)
return
end
if res == "ok" then
setStatus(string.format("Haider confirmed: %d/%d", cnt or 0, s.maxPlayers or 0))
elseif res == "unknown" then
setStatus(T("log_noverify"))
else
setStatus(T("st_changed"))
if res == "gone" then allServers[s.id] = nil end
end
pcall(recomputeFiltered)
end)
end
TAB_BUILDERS.main = function(h)
local bQuick = button(h, T("btn_quick"), theme.accent, UDim2.new(0.5, -3, 0, 28), UDim2.new(0, 0, 0, 0))
local bFull = button(h, T("btn_full"), theme.steel, UDim2.new(0.5, -3, 0, 28), UDim2.new(0.5, 3, 0, 0))
local bBest = button(h, T("btn_best"), theme.steel, UDim2.new(0.62, -3, 0, 28), UDim2.new(0, 0, 0, 32))
local bPrev = button(h, T("btn_prev"), theme.steel, UDim2.new(0.38, -3, 0, 28), UDim2.new(0.62, 3, 0, 32))
bQuick.TextSize, bFull.TextSize, bBest.TextSize, bPrev.TextSize = 11, 11, 11, 11
bQuick.MouseButton1Click:Connect(function() quickRefreshAll() end)
bFull.MouseButton1Click:Connect(function() refreshAll() end)
bBest.MouseButton1Click:Connect(function()
if #filtered == 0 then
setStatus(T("st_no_match"))
return
end
attemptTeleport(filtered[1])
end)
bPrev.MouseButton1Click:Connect(function() rejoinPrev() end)
local sf = makeList(h, 66)
UI.ScrollFrame = sf
F.renderList = function()
if not sf.Parent then return end
clearRows(sf)
if #filtered == 0 then
local msg = (next(allServers) == nil) and T("st_idle") or T("st_no_match")
local l = label(sf, { text = msg, size = 11, color = theme.dim, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, -6, 0, 40) })
l.LayoutOrder = 1
return
end
for i, s in ipairs(filtered) do
if i > 40 then break end
local trendTxt, ck = trendOf(s)
local line1 = string.format("%s%d/%d", (trendTxt ~= "") and (trendTxt .. " ") or "", s.playing, s.maxPlayers)
local parts = {}
if s.ping then table.insert(parts, math.floor(s.ping) .. "ms") end
if s.fps then table.insert(parts, math.floor(s.fps) .. "fps") end
local line2 = (#parts > 0) and table.concat(parts, " • ") or "—"
local R = rowFrame(sf, i, theme[ck] or theme.steel, tostring(i))
label(R, { text = line1 .. "\n" .. line2, size = 10, size2 = UDim2.new(1, -150, 1, 0), pos = UDim2.new(0, 42, 0, 0) })
local goB = rowButton(R, T("btn_go"), theme.accent, 6, 46)
local vB = rowButton(R, T("btn_verify"), theme.steel, 56, 46)
goB.MouseButton1Click:Connect(function() attemptTeleport(s) end)
vB.MouseButton1Click:Connect(function() verifyRow(s) end)
end
end
F.renderList()
end
TAB_BUILDERS.players = function(h)
local head = label(h, { text = "", size = 11, color = theme.gold, size2 = UDim2.new(1, 0, 0, 22) })
local sf = makeList(h, 26)
local function render()
if not sf.Parent then return end
local list = Players:GetPlayers()
head.Text = T("pl_head", #list, Players.MaxPlayers)
clearRows(sf)
table.sort(list, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
local any = false
for i, plr in ipairs(list) do
local st = readStats(plr)
local bits = {}
for j = 1, math.min(3, #st) do
table.insert(bits, st[j].name .. ": " .. st[j].text)
end
if #bits > 0 then any = true end
local R = rowFrame(sf, i, (plr == LocalPlayer) and theme.gold or theme.steel, tostring(i))
local nm = playerLabel(plr)
if plr == LocalPlayer then nm = nm .. " " .. T("pl_you") end
label(R, { text = nm .. "\n" .. table.concat(bits, " • "), size = 10, size2 = UDim2.new(1, -48, 1, 0),
pos = UDim2.new(0, 42, 0, 0) })
end
if not any then
local l = label(sf, { text = T("pl_nostats"), size = 10, color = theme.dim, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, -6, 0, 24) })
l.LayoutOrder = #list + 1
end
end
F.refreshLive = function() pcall(render) end
render()
end
TAB_BUILDERS.board = function(h)
local statBtn = button(h, "", theme.steel, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0))
statBtn.TextSize = 11
local info = label(h, { text = "", size = 9, color = theme.dim, font = Enum.Font.Gotham,
size2 = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 0, 28), valign = Enum.TextYAlignment.Top })
local sf = makeList(h, 54)
local names = {}
local function collect()
local set, data = {}, {}
for _, plr in ipairs(Players:GetPlayers()) do
local st = readStats(plr)
data[plr] = st
for _, x in ipairs(st) do set[x.name] = true end
end
names = {}
for n, _ in pairs(set) do table.insert(names, n) end
table.sort(names)
return data
end
local function currentStat()
for _, n in ipairs(names) do
if n == P.boardStat then return n end
end
return pickDefaultStat(names)
end
local function render()
if not sf.Parent then return end
local data = collect()
clearRows(sf)
if #names == 0 then
statBtn.Text = T("bd_none")
info.Text = T("bd_none_info")
return
end
local sel = currentStat()
statBtn.Text = T("bd_stat", sel)
local rows = {}
for plr, st in pairs(data) do
local val = nil
for _, x in ipairs(st) do
if x.name == sel then val = x end
end
table.insert(rows, { plr = plr, val = val })
end
table.sort(rows, function(a, b)
local na = a.val and a.val.num or -math.huge
local nb = b.val and b.val.num or -math.huge
if na ~= nb then return na > nb end
return string.lower(a.plr.Name) < string.lower(b.plr.Name)
end)
info.Text = T("bd_info", #rows, sel)
for i, r in ipairs(rows) do
local R = rowFrame(sf, i, (r.plr == LocalPlayer) and theme.gold or theme.steel, tostring(i))
local nm = playerLabel(r.plr)
if r.plr == LocalPlayer then nm = nm .. " " .. T("pl_you") end
label(R, { text = nm .. "\n" .. (r.val and r.val.text or "—"), size = 10, size2 = UDim2.new(1, -48, 1, 0),
pos = UDim2.new(0, 42, 0, 0) })
end
end
statBtn.MouseButton1Click:Connect(function()
if #names == 0 then return end
local cur = currentStat()
local idx = 1
for i, n in ipairs(names) do
if n == cur then idx = i end
end
P.boardStat = names[(idx % #names) + 1]
saveSettings()
render()
end)
F.refreshLive = function() pcall(render) end
render()
end
TAB_BUILDERS.find = function(h)
local sf = newPanel(h)
addText(sf, T("fd_hint"), { h = 30, color = theme.dim, size = 10 })
local nameBox = addBox(sf, T("fd_name_ph"), 26, false, UI.findName or "")
UI.findDepth = UI.findDepth or 1
local depthBtn = addButton(sf, "", theme.steel, function() end, 26)
local function depthText()
local d = SEARCH_DEPTHS[UI.findDepth]
depthBtn.Text = T("fd_depth", d, d * 100)
end
depthBtn.TextSize = 10
depthText()
depthBtn.MouseButton1Click:Connect(function()
UI.findDepth = (UI.findDepth % #SEARCH_DEPTHS) + 1
depthText()
end)
local searchBtn, btnHolder = addButton(sf, T("fd_search"), theme.accent, function() end, 30)
local cancelBtn = button(btnHolder, T("fd_cancel"), theme.steel, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
cancelBtn.Visible = false
local result = addCard(sf, "", { size = 11 })
local foundHolder = addHolder(sf, 34)
foundHolder.Visible = false
local foundRec = nil
local goBtn = button(foundHolder, T("btn_go"), theme.good, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0))
goBtn.MouseButton1Click:Connect(function()
if foundRec then attemptTeleport(foundRec) end
end)
addText(sf, T("fd_note"), { h = 30, color = theme.dim, size = 9 })
local function resetButtons()
searchBtn.Visible = true
cancelBtn.Visible = false
end
local hooks = {
status = function(msg)
result.Text = tostring(msg)
setStatus(tostring(msg))
end,
progress = function(frac) setProgress(frac) end,
found = function(rec)
foundRec = rec
foundHolder.Visible = true
end,
done = function() resetButtons() end,
}
searchBtn.MouseButton1Click:Connect(function()
UI.findName = nameBox.Text
foundRec = nil
foundHolder.Visible = false
local started = friendSearch(nameBox.Text, SEARCH_DEPTHS[UI.findDepth], hooks)
if started then
searchBtn.Visible = false
cancelBtn.Visible = true
end
end)
cancelBtn.MouseButton1Click:Connect(function()
cancelFriendSearch()
setProgress(0)
resetButtons()
result.Text = T("st_unlocked")
end)
end
TAB_BUILDERS.fav = function(h)
local noteBox = Instance.new("TextBox")
noteBox.Size = UDim2.new(1, 0, 0, 24)
noteBox.BackgroundColor3 = theme.card
noteBox.TextColor3 = theme.text
noteBox.PlaceholderText = T("fv_name_ph")
noteBox.PlaceholderColor3 = theme.dim
noteBox.Text = ""
noteBox.ClearTextOnFocus = false
noteBox.Font = Enum.Font.Gotham
noteBox.TextSize = 11
noteBox.TextXAlignment = Enum.TextXAlignment.Left
noteBox.Parent = h
corner(noteBox, 6)
local saveBtn = button(h, T("fv_save"), theme.accent, UDim2.new(0.56, -3, 0, 26), UDim2.new(0, 0, 0, 28))
local checkBtn = button(h, T("fv_check"), theme.steel, UDim2.new(0.44, -3, 0, 26), UDim2.new(0.56, 3, 0, 28))
saveBtn.TextSize, checkBtn.TextSize = 10, 10
local sf = makeList(h, 60)
F.renderFavorites = function()
if not sf.Parent then return end
clearRows(sf)
if #P.favorites == 0 then
local l = label(sf, { text = T("fv_empty"), size = 11, color = theme.dim, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, -6, 0, 40) })
l.LayoutOrder = 1
return
end
for i, f in ipairs(P.favorites) do
local stale = (os.time() - (f.savedAt or 0)) > K.FAV_STALE
local here = (f.id == game.JobId)
local R = rowFrame(sf, i, here and theme.gold or (stale and theme.warn or theme.good), "⭐")
local second = {}
if f.ping then table.insert(second, T("fv_ping", f.ping)) end
if here then table.insert(second, "●") end
if stale then table.insert(second, T("fv_stale")) end
label(R, { text = tostring(f.note) .. "\n" .. table.concat(second, " • "), size = 10,
size2 = UDim2.new(1, -108, 1, 0), pos = UDim2.new(0, 42, 0, 0), truncate = false })
local goB = rowButton(R, T("btn_go"), theme.accent, 36, 46)
local delB = rowButton(R, "✕", theme.steel, 6, 26)
goB.MouseButton1Click:Connect(function()
attemptTeleport({ id = f.id, placeId = f.placeId or K.PLACE_ID, skipVerify = true, source = "fav" })
end)
delB.MouseButton1Click:Connect(function()
removeFavoriteById(f.id)
F.renderFavorites()
end)
end
end
saveBtn.MouseButton1Click:Connect(function()
local _, msg = addFavoriteCurrentServer(noteBox.Text)
setStatus(tostring(msg))
noteBox.Text = ""
F.renderFavorites()
end)
checkBtn.MouseButton1Click:Connect(function() checkFavorites() end)
F.renderFavorites()
end
local WHY_TEXT = { immediate = "st_fail_imm", other = "log_mismatch" }
TAB_BUILDERS.stats = function(h)
local sf = newPanel(h)
local lSession = addCard(sf, "", { color = theme.gold })
local lTp = addCard(sf, "", { size = 10 })
local lWhy = addCard(sf, "", { size = 10 })
local lBuck = addCard(sf, "", { size = 10 })
local lHours = addCard(sf, "", { size = 10 })
local lGame = addCard(sf, "", { size = 10 })
local lStatus = addCard(sf, "", { size = 10 })
local refreshBtn = addButton(sf, T("stt_refresh"), theme.steel, function() end, 28)
local function pct(a, b)
if b <= 0 then return "—" end
return string.format("%d%%", math.floor(a / b * 100 + 0.5))
end
F.updateStats = function()
if not lSession.Parent then return end
lSession.Text = T("stt_session", fmtClock(os.time() - SESSION_START))
local r = computeStats()
if r.total == 0 then
lTp.Text = T("stt_tp_none")
else
local avgLoad = (r.nSec > 0) and (math.floor(r.sumSec / r.nSec) .. "s") or "—"
local avgPing = (r.nPing > 0) and (math.floor(r.sumPing / r.nPing) .. "ms") or "—"
lTp.Text = T("stt_tp", r.total, r.okN, r.failN, r.unk, pct(r.okN, r.okN + r.failN), avgLoad, avgPing)
end
local whyList = {}
for code, n in pairs(r.why) do table.insert(whyList, { code = code, n = n }) end
table.sort(whyList, function(a, b)
if a.n ~= b.n then return a.n > b.n end
return a.code < b.code
end)
local wt = {}
for i = 1, math.min(4, #whyList) do
local w = whyList[i]
local txt
if WHY_TEXT[w.code] then txt = T(WHY_TEXT[w.code]) else txt = failReasonText(w.code) end
table.insert(wt, txt .. " ×" .. w.n)
end
lWhy.Text = (#wt > 0) and T("stt_reasons", table.concat(wt, " | ")) or ""
lWhy.Parent.Visible = #wt > 0
local bt = {}
for _, b in ipairs({ "0", "1", "2", "3" }) do
local c = r.buckets[b]
if c and (c.ok + c.bad) > 0 then
table.insert(bt, b .. ((b == "3") and "+" or "") .. "=" .. pct(c.ok, c.ok + c.bad) .. "(" .. (c.ok + c.bad) .. ")")
end
end
lBuck.Text = (#bt > 0) and T("stt_buckets", table.concat(bt, "  ")) or ""
lBuck.Parent.Visible = #bt > 0
local hl, samples = hourStats()
if #hl < 3 then
lHours.Text = T("stt_hours_wait", samples)
else
table.sort(hl, function(a, b) return a.avg < b.avg end)
local quiet, busy = {}, {}
for i = 1, math.min(3, #hl) do
table.insert(quiet, string.format("%02d:00", hl[i].h))
table.insert(busy, string.format("%02d:00", hl[#hl - i + 1].h))
end
lHours.Text = T("stt_hours", table.concat(quiet, "  "), table.concat(busy, "  ")) .. "\n" .. T("stt_hours_note")
end
if GI.name then
local likes = "—"
if GI.up and GI.down then likes = fmtNum(GI.up) .. "👍 " .. fmtNum(GI.down) .. "👎" end
lGame.Text = T("stt_game", GI.name, GI.playing and fmtNum(GI.playing) or "—",
GI.visits and fmtNum(GI.visits) or "—", GI.favs and fmtNum(GI.favs) or "—", likes)
elseif GI.err then
lGame.Text = T("stt_game_fail")
else
lGame.Text = T("stt_game_none")
end
lStatus.Text = T("stt_status", robloxStatusText())
end
local busy = false
refreshBtn.MouseButton1Click:Connect(function()
if busy then return end
busy = true
task.spawn(function()
pcall(fetchGameInfo)
pcall(fetchRobloxStatus)
busy = false
if F.updateStats then pcall(F.updateStats) end
end)
end)
F.updateStats()
end
TAB_BUILDERS.filt = function(h)
local sf = newPanel(h)
numInput(sf, T("fl_max"), P.maxPlayers, 0, 100, function(n) P.maxPlayers = n recomputeFiltered() end)
numInput(sf, T("fl_min"), P.minPlayers, 0, 100, function(n) P.minPlayers = n recomputeFiltered() end)
numInput(sf, T("fl_ping"), P.maxPing, 1, 5000, function(n) P.maxPing = n recomputeFiltered() end)
numInput(sf, T("fl_fps"), P.minFps, 0, 60, function(n) P.minFps = n recomputeFiltered() end)
numInput(sf, T("fl_age"), P.maxAgeSeconds, 5, 600, function(n) P.maxAgeSeconds = n recomputeFiltered() end)
numInput(sf, T("fl_every"), S.refreshEvery, 5, 300, function(n) S.refreshEvery = n end)
addToggle(sf, T("fl_nofull"), P.excludeFull, function(v) P.excludeFull = v saveSettings() recomputeFiltered() end)
addToggle(sf, T("fl_auto"), S.autoRefresh, function(v) S.autoRefresh = v saveSettings() end)
addToggle(sf, T("fl_verify"), S.verifyBeforeJump, function(v) S.verifyBeforeJump = v saveSettings() end)
addToggle(sf, T("fl_quality"), P.sortMode == "quality", function(v)
P.sortMode = v and "quality" or "empty"
saveSettings()
recomputeFiltered()
end)
addText(sf, T("fl_note"), { h = 28, color = theme.dim, size = 10 })
end
TAB_BUILDERS.theme = function(h)
local sf = newPanel(h)
addText(sf, T("th_pick"), { h = 20, color = theme.gold })
for i, th in ipairs(THEMES) do
local nm = (S.lang == "ar") and th.name or th.nameEn
local b = addButton(sf, ((i == S.themeIndex) and "✓ " or "") .. nm, th.accent, function()
S.themeIndex = i
saveSettings()
F.rebuild()
end, 34)
b.TextSize = 13
end
end
TAB_BUILDERS.log = function(h)
local clearB = button(h, T("btn_clear_log"), theme.steel, UDim2.new(0.5, -3, 0, 26), UDim2.new(0, 0, 0, 0))
local copyB = button(h, T("btn_copy_log"), theme.steel, UDim2.new(0.5, -3, 0, 26), UDim2.new(0.5, 3, 0, 0))
clearB.TextSize, copyB.TextSize = 11, 11
local sf = makeList(h, 30)
F.writeLog = function()
if not sf.Parent then return end
clearRows(sf)
if #LOG == 0 then
local l = label(sf, { text = T("log_empty"), size = 11, color = theme.dim, align = Enum.TextXAlignment.Center,
size2 = UDim2.new(1, -6, 0, 30) })
l.LayoutOrder = 1
return
end
for i, line in ipairs(LOG) do
local l = Instance.new("TextLabel")
l.BackgroundTransparency = 1
l.Size = UDim2.new(1, -6, 0, 0)
l.AutomaticSize = Enum.AutomaticSize.Y
l.Font = Enum.Font.Gotham
l.TextSize = 10
l.TextColor3 = theme.text
l.TextWrapped = true
l.TextXAlignment = Enum.TextXAlignment.Left
l.TextYAlignment = Enum.TextYAlignment.Top
l.Text = line
l.LayoutOrder = i
l.Parent = sf
end
end
clearB.MouseButton1Click:Connect(function()
for i = #LOG, 1, -1 do table.remove(LOG, i) end
F.writeLog()
end)
copyB.MouseButton1Click:Connect(function()
if copyToClipboard(table.concat(LOG, "\n")) then setStatus("✓") end
end)
F.writeLog()
end
TAB_BUILDERS.tools = function(h)
local sf = newPanel(h)
addText(sf, T("tl_caps_title"), { h = 18, color = theme.gold, size = 12 })
local capsLabel, capsCard = addCard(sf, "", { size = 10 })
capsCard.Visible = false
local runBtn = addButton(sf, T("tl_caps_run"), theme.accent, function() end, 28)
runBtn.MouseButton1Click:Connect(function()
capsCard.Visible = true
capsLabel.Text = T("tl_caps_wait")
task.spawn(function()
local ok, rows = pcall(runCapsCheck)
if not ok then
capsLabel.Text = tostring(rows)
return
end
local lines = {}
for _, r in ipairs(rows) do
local icon = (r.state == true) and "✅" or ((r.state == "pending") and "⏳" or "❌")
local line = icon .. " " .. r.name
if r.extra then line = line .. " — " .. tostring(r.extra) end
if r.state ~= true and r.note then line = line .. "\n      " .. r.note end
table.insert(lines, line)
end
capsLabel.Text = table.concat(lines, "\n")
end)
end)
local stBtn = addButton(sf, T("tl_selftest"), theme.accent, function() end, 28)
local stLabel, stCard = addCard(sf, "", { size = 10 })
stCard.Visible = false
stBtn.MouseButton1Click:Connect(function()
stCard.Visible = true
stLabel.Text = T("tl_selftest_wait")
task.spawn(function()
local ok, rows = pcall(F.selfTest)
if not ok then
stLabel.Text = tostring(rows)
return
end
local lines = {}
for _, r in ipairs(rows) do
table.insert(lines, (r.ok and "✅ " or "❌ ") .. r.name .. (r.note and (" — " .. r.note) or ""))
end
stLabel.Text = table.concat(lines, "\n")
end)
end)
local repBtn = addButton(sf, T("tl_report"), theme.steel, function() end, 28)
local repBox, repHolder = addBox(sf, "", 110, true, "")
repHolder.Visible = false
repBtn.MouseButton1Click:Connect(function()
local txt = buildReport()
if copyToClipboard(txt) then
setStatus(T("tl_report_copied"))
else
setStatus(T("tl_report_manual"))
repBox.Text = txt
repHolder.Visible = true
end
end)
addText(sf, T("tl_backup_title"), { h = 18, color = theme.gold, size = 12 })
local bkBtn = addButton(sf, T("tl_backup_copy"), theme.steel, function() end, 28)
local bkBox, bkHolder = addBox(sf, "", 80, true, "")
bkHolder.Visible = false
bkBtn.MouseButton1Click:Connect(function()
local code = buildBackupCode()
if not code then
setStatus(T("tl_restore_bad"))
return
end
if copyToClipboard(code) then
setStatus(T("tl_backup_copied"))
else
setStatus(T("tl_backup_manual"))
bkBox.Text = code
bkHolder.Visible = true
end
end)
local rsBox = addBox(sf, T("tl_restore_ph"), 44, true, "")
local rsBtn = addButton(sf, T("tl_restore"), theme.accent, function() end, 28)
rsBtn.MouseButton1Click:Connect(function()
local oldLang = S.lang
local ok, nf, nh = restoreBackupCode(rsBox.Text)
if ok then
setStatus(T("tl_restore_ok", nf or 0, nh or 0))
rsBox.Text = ""
pcall(recomputeFiltered)
if S.lang ~= oldLang then F.rebuild() end
else
setStatus(T("tl_restore_bad"))
end
end)
addText(sf, T("tl_backup_note"), { h = 56, color = theme.dim, size = 9 })
end
TAB_BUILDERS.set = function(h)
local sf = newPanel(h)
addButton(sf, T("set_lang"), theme.steel, function()
S.lang = (S.lang == "ar") and "en" or "ar"
saveSettings()
F.rebuild()
end, 28)
addToggle(sf, T("set_gfx"), S.lowGfx, function(v)
S.lowGfx = v
applyLowGfx(v)
saveSettings()
end)
addToggle(sf, T("set_anim"), S.anim, function(v) S.anim = v saveSettings() end)
addToggle(sf, T("set_autohide"), S.autoHide, function(v) S.autoHide = v UI.lastActive = tick() saveSettings() end)
numInput(sf, T("set_hideafter"), S.hideAfter, 5, 300, function(n) S.hideAfter = n end)
local function cleanUrl(t)
local x = string.gsub(t, "%s", "")
if #x > 300 then x = "" end
return x
end
addText(sf, T("set_img_bg"), { h = 16, size = 10 })
local bgBox = addBox(sf, T("set_img_ph"), 26, false, S.imgBg)
addText(sf, T("set_img_circle"), { h = 16, size = 10 })
local ciBox = addBox(sf, T("set_img_ph"), 26, false, S.imgCircle)
local function applyBoxes()
S.imgBg = cleanUrl(bgBox.Text)
S.imgCircle = cleanUrl(ciBox.Text)
saveSettings()
task.spawn(function()
local a, b = F.applyImages()
if S.imgBg == "" and S.imgCircle == "" then
setStatus(T("img_ok"))
elseif (S.imgBg ~= "" and not a) or (S.imgCircle ~= "" and not b) then
setStatus(T("img_fail"))
else
setStatus(T("img_ok"))
end
end)
end
bgBox.FocusLost:Connect(applyBoxes)
ciBox.FocusLost:Connect(applyBoxes)
addText(sf, T("set_img_note"), { h = 16, size = 9, color = theme.dim })
addText(sf, T("set_hook"), { h = 16, size = 10 })
local hookBox = addBox(sf, T("set_hook_ph"), 26, false, S.webhookUrl)
hookBox.FocusLost:Connect(function()
local txt = string.gsub(hookBox.Text, "%s", "")
if txt == "" then
S.webhookUrl = ""
saveSettings()
elseif validWebhook(txt) and #txt <= 400 then
S.webhookUrl = txt
saveSettings()
else
setStatus(T("set_hook_bad"))
hookBox.Text = S.webhookUrl
end
end)
addToggle(sf, T("set_notify_arrive"), S.notifyArrival, function(v) S.notifyArrival = v saveSettings() end)
addToggle(sf, T("set_notify_match"), S.notifyMatch, function(v) S.notifyMatch = v saveSettings() end)
addButton(sf, T("set_hook_test"), theme.steel, function()
if not validWebhook(S.webhookUrl) then
setStatus(T("set_hook_bad"))
return
end
task.spawn(function()
local ok = sendWebhook(T("wh_test"), true)
setStatus(ok and T("set_hook_ok") or T("set_hook_fail"))
end)
end, 26)
local persistTxt = canPersist() and T("yes_supported") or T("not_supported")
local queueTxt = (typeof(queue_on_teleport) == "function") and T("yes_supported") or T("not_supported")
addCard(sf, T("set_save", persistTxt) .. "\n" .. T("set_queue", queueTxt) .. "\n"
.. T("set_players_now", #Players:GetPlayers(), Players.MaxPlayers), { size = 10 })
local joinTxt
if #P.joinStats == 0 then
joinTxt = T("set_join_none")
else
local sumS, nS, sumP, nP = 0, 0, 0, 0
for _, js in ipairs(P.joinStats) do
sumS = sumS + js.sec
nS = nS + 1
if js.ping and js.ping > 0 then
sumP = sumP + js.ping
nP = nP + 1
end
end
joinTxt = T("set_join", nS, math.floor(sumS / math.max(nS, 1)), (nP > 0) and (math.floor(sumP / nP) .. "ms") or "—")
end
addCard(sf, joinTxt, { size = 10 })
addCard(sf, T("set_credits") .. "\nInstagram: l.9_1 | Telegram: QPPPPX | Discord: 3h._ | TikTok: ofme\nv" .. K.VERSION,
{ size = 10, color = theme.gold })
addButton(sf, T("set_reset"), theme.accent, function()
applyLowGfx(false)
resetSettings()
S.windowOpen = true
saveSettings()
activeTab = "main"
S.activeTab = "main"
pcall(recomputeFiltered)
F.rebuild()
end, 28)
end
local ArrowLbl = Instance.new("TextLabel")
ArrowLbl.BackgroundTransparency = 1
ArrowLbl.AnchorPoint = Vector2.new(0.5, 0.5)
ArrowLbl.Size = UDim2.new(0, 34, 0, 34)
ArrowLbl.Font = Enum.Font.GothamBold
ArrowLbl.TextSize = 30
ArrowLbl.Text = "➤"
ArrowLbl.TextColor3 = theme.gold
ArrowLbl.TextStrokeTransparency = 0.3
ArrowLbl.ZIndex = 40
ArrowLbl.Visible = false
ArrowLbl.Parent = ScreenGui
local ArrowTxt = Instance.new("TextLabel")
ArrowTxt.BackgroundTransparency = 1
ArrowTxt.AnchorPoint = Vector2.new(0.5, 0.5)
ArrowTxt.Size = UDim2.new(0, 160, 0, 16)
ArrowTxt.Font = Enum.Font.GothamBold
ArrowTxt.TextSize = 11
ArrowTxt.TextColor3 = theme.gold
ArrowTxt.TextStrokeTransparency = 0.3
ArrowTxt.ZIndex = 40
ArrowTxt.Visible = false
ArrowTxt.Parent = ScreenGui
UI.ArrowLbl, UI.ArrowTxt = ArrowLbl, ArrowTxt
local function holdButton(txt, yOff, key)
local b = Instance.new("TextButton")
b.Size = UDim2.new(0, 46, 0, 46)
b.Position = UDim2.new(1, -66, 0.5, yOff)
b.BackgroundColor3 = theme.panel
b.Text = txt
b.TextColor3 = theme.gold
b.Font = Enum.Font.GothamBold
b.TextSize = 22
b.AutoButtonColor = false
b.ZIndex = 40
b.Visible = false
b.Parent = ScreenGui
corner(b, 1000)
strokeF(b, theme.gold, 2)
b.InputBegan:Connect(function(input)
if isPointerInput(input) then CT[key] = true end
end)
b.InputEnded:Connect(function(input)
if isPointerInput(input) then CT[key] = false end
end)
return b
end
local upB = holdButton("▲", -56, "flyUp")
local dnB = holdButton("▼", 4, "flyDown")
F.flyUi = function(on)
upB.Visible = on
dnB.Visible = on
if not on then
CT.flyUp = false
CT.flyDown = false
end
end
TAB_BUILDERS.ctrl = function(h)
local sf = newPanel(h)
addCard(sf, T("ct_warn"), { size = 10, color = theme.warn })
if MAPINFO.genre == "combat" then addCard(sf, T("ct_combat"), { size = 10, color = theme.bad }) end
addToggle(sf, T("ct_speed_on"), P.ctrl.speedOn, function(v) P.ctrl.speedOn = v saveSettings() end)
numInput(sf, T("ct_speed"), P.ctrl.speed, 1, 500, function(n) P.ctrl.speed = n end)
addToggle(sf, T("ct_jump_on"), P.ctrl.jumpOn, function(v) P.ctrl.jumpOn = v saveSettings() end)
numInput(sf, T("ct_jump"), P.ctrl.jump, 1, 500, function(n) P.ctrl.jump = n end)
addToggle(sf, T("ct_fly"), CT.flying, function(v)
if v then
if not startFly() then
setStatus(T("ct_fly_fail"))
F.switchTab("ctrl")
end
else
stopFly()
end
end)
numInput(sf, T("ct_fly_speed"), P.ctrl.flySpeed, 5, 400, function(n) P.ctrl.flySpeed = n end)
addToggle(sf, T("ct_noclip"), CT.noclip, function(v) setNoclip(v) end)
addText(sf, T("ct_fly_hint"), { h = 30, color = theme.dim, size = 9 })
addButton(sf, T("ct_stop"), theme.accent, function()
stopAllControls()
setStatus(T("ct_stopped"))
F.switchTab("ctrl")
end, 28)
end
TAB_BUILDERS.esp = function(h)
local sf = newPanel(h)
addToggle(sf, T("es_on"), P.esp.on, function(v)
P.esp.on = v
ESP.dirty = true
saveSettings()
if not v then espClear() end
end)
addToggle(sf, T("es_arrow"), P.esp.arrow, function(v) P.esp.arrow = v saveSettings() end)
addToggle(sf, T("es_npc"), P.esp.npc, function(v) P.esp.npc = v ESP.dirty = true saveSettings() end)
addToggle(sf, T("es_friends"), P.esp.friends, function(v) P.esp.friends = v saveSettings() end)
numInput(sf, T("es_dist"), P.esp.dist, 50, 5000, function(n) P.esp.dist = n end)
numInput(sf, T("es_max"), P.esp.max, 5, 80, function(n) P.esp.max = n end)
local kwBox = addBox(sf, T("es_kw_ph"), 26, false, "")
addButton(sf, T("es_add"), theme.steel, function()
if addEspKeyword(kwBox.Text) then F.switchTab("esp") end
end, 26)
addText(sf, T("es_kw_title"), { h = 16, size = 10, color = theme.gold })
if #P.esp.names == 0 then addText(sf, T("es_kw_none"), { h = 18, size = 10, color = theme.dim }) end
for i, k in ipairs(P.esp.names) do
addButton(sf, "✕  " .. k, theme.card, function()
table.remove(P.esp.names, i)
ESP.dirty = true
saveSettings()
F.switchTab("esp")
end, 24)
end
addText(sf, T("map_title"), { h = 18, size = 12, color = theme.gold })
local infoTxt
if MAPINFO.at == 0 then
infoTxt = T("map_none")
else
infoTxt = T("map_info", tostring(MAPINFO.name), T("map_" .. MAPINFO.genre),
MAPINFO.leader and T("map_yes") or T("map_no"),
(#MAPINFO.tools > 0) and table.concat(MAPINFO.tools, ", ") or "—", MAPINFO.remotes)
end
local infoLbl = addCard(sf, infoTxt, { size = 10 })
addButton(sf, T("map_scan"), theme.accent, function()
infoLbl.Text = T("map_scanning")
task.spawn(function()
pcall(detectMap)
autoAdaptMap()
if activeTab == "esp" then F.switchTab("esp") end
end)
end, 28)
if MAPINFO.at > 0 then
addText(sf, T("map_cands"), { h = 16, size = 10, color = theme.gold })
if #MAPINFO.cands == 0 then addText(sf, T("map_cands_none"), { h = 18, size = 10, color = theme.dim }) end
for _, cd in ipairs(MAPINFO.cands) do
addButton(sf, "+ " .. cd.name .. "  ×" .. cd.count, theme.steel, function()
addEspKeyword(cd.name)
F.switchTab("esp")
end, 24)
end
addButton(sf, T("map_copy"), theme.steel, function()
if copyToClipboard(mapReport()) then setStatus(T("map_copied")) end
end, 26)
end
addText(sf, T("es_note"), { h = 30, color = theme.dim, size = 9 })
end
TAB_BUILDERS.ai = function(h)
local sf = newPanel(h)
addCard(sf, T("ai_note"), { size = 10, color = theme.dim })
addText(sf, T("ai_key"), { h = 16, size = 10 })
local keyBox = addBox(sf, T("ai_key_ph"), 26, false, S.aiKey)
keyBox.FocusLost:Connect(function()
local x = string.gsub(keyBox.Text, "%s", "")
if #x > 200 then x = "" end
S.aiKey = x
keyBox.Text = x
saveSettings()
end)
addText(sf, T("ai_model"), { h = 16, size = 10 })
local modelBox = addBox(sf, "provider/model", 26, false, S.aiModel)
modelBox.FocusLost:Connect(function()
local x = string.gsub(modelBox.Text, "%s", "")
if #x >= 3 and #x <= 80 and string.match(x, "^[%w%-%._:/~]+$") then
S.aiModel = x
saveSettings()
end
modelBox.Text = S.aiModel
end)
addToggle(sf, T("ai_ctx_on"), S.aiCtx, function(v) S.aiCtx = v saveSettings() end)
addText(sf, T("ai_ctx"), { h = 16, size = 9, color = theme.dim })
local ans = addCard(sf, "", { size = 11 })
local applyBtn, applyHolder = addButton(sf, "", theme.good, function() end, 28)
applyHolder.Visible = false
local lastKw = {}
applyBtn.MouseButton1Click:Connect(function()
for _, w in ipairs(lastKw) do addEspKeyword(w) end
applyHolder.Visible = false
setStatus(T("ai_applied"))
end)
local function run(prompt, isKw)
applyHolder.Visible = false
ans.Text = T("ai_wait")
local started = AI.ask(prompt, S.aiCtx, function(text, err)
if text then
ans.Text = text
AI.last = text
if isKw then
lastKw = AI.parseKeywords(text)
if #lastKw > 0 then
applyBtn.Text = T("ai_apply", table.concat(lastKw, ", "))
applyHolder.Visible = true
end
end
else
ans.Text = T(err or "ai_err_net")
end
end)
if not started then ans.Text = T("ai_wait") end
end
addButton(sf, T("ai_btn_kw"), theme.steel, function()
run("Task: suggest up to 6 short lowercase English keywords (letters only) that likely appear in the names of collectible or important objects on this map. Reply with ONLY the keywords separated by commas.", true)
end, 28)
addButton(sf, T("ai_btn_err"), theme.steel, function()
local lines = {}
for i = 1, math.min(8, #ERRORS) do table.insert(lines, ERRORS[i]) end
for i = 1, math.min(8, #LOG) do table.insert(lines, LOG[i]) end
run("Task: explain in simple words the likely cause of these recent error and log lines of my script and what I should do:\n" .. table.concat(lines, "\n"), false)
end, 28)
addButton(sf, T("ai_btn_filt"), theme.steel, function()
run("Task: I hunt big or rare eggs by hopping between servers. Suggest better numbers for min and max players, max ping and min fps, with a short reason in 4 lines.", false)
end, 28)
local qBox = addBox(sf, T("ai_free_ph"), 50, true, "")
addButton(sf, T("ai_ask"), theme.accent, function()
local q = string.sub(qBox.Text, 1, 300)
if #q >= 2 then run("Question: " .. q, false) end
end, 28)
addButton(sf, T("ai_copy"), theme.steel, function()
if AI.last ~= "" and copyToClipboard(AI.last) then setStatus(T("ai_copied")) end
end, 26)
end
F.switchTab = function(key)
if not VALID_TABS[key] then key = "main" end
activeTab = key
S.activeTab = key
saveSettings()
F.renderList, F.renderFavorites, F.updateStats, F.writeLog, F.refreshLive = nil, nil, nil, nil, nil
UI.ScrollFrame = nil
for k, tb in pairs(tabButtons) do
tb.BackgroundColor3 = (k == key) and theme.accent or theme.card
end
local hd = newHolder()
local builder = TAB_BUILDERS[key]
if builder then
local ok, err = pcall(builder, hd)
if not ok then
addError("tab:" .. key, err)
label(hd, { text = "⚠ " .. tostring(err), size = 10, color = theme.bad, font = Enum.Font.Gotham,
valign = Enum.TextYAlignment.Top })
end
end
end
NetLabel.TextWrapped = false
NetLabel.TextTruncate = Enum.TextTruncate.AtEnd
UI.StatusLabel.TextWrapped = false
UI.StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
UI.CountsLabel.TextWrapped = false
UI.CountsLabel.TextTruncate = Enum.TextTruncate.AtEnd
F.updateNet = function()
if not NetLabel.Parent then return end
local st = NET.status
local col, txt = theme.steel, T("net_unknown")
if st == "ok" then col, txt = theme.good, T("net_ok")
elseif st == "slow" then col, txt = theme.warn, T("net_slow")
elseif st == "down" then col, txt = theme.bad, T("net_down")
elseif st == "limited" then col, txt = theme.warn, T("net_limited") end
NetDot.BackgroundColor3 = col
local ping = getMyPing()
NetLabel.Text = T("net_label") .. ": " .. txt .. " • " .. (ping and (ping .. "ms") or "—")
.. " • ⏱" .. fmtClock(os.time() - SESSION_START)
end
F.updateCounts = function()
if not UI.CountsLabel or not UI.CountsLabel.Parent then return end
if next(allServers) == nil then
UI.CountsLabel.Text = T("counts_init")
return
end
local e, l, f = countsBreakdown()
UI.CountsLabel.Text = T("counts", e, l, f)
end
UI.Main = Main
UI.lastActive = tick()
local function insideMain(pos)
local ap, sz = Main.AbsolutePosition, Main.AbsoluteSize
return pos.X >= ap.X - 45 and pos.X <= ap.X + sz.X + 45 and pos.Y >= ap.Y - 45 and pos.Y <= ap.Y + sz.Y + 45
end
track(UserInputService.InputBegan:Connect(function(input)
if isPointerInput(input) and insideMain(input.Position) then UI.lastActive = tick() end
end))
track(UserInputService.InputChanged:Connect(function(input)
if isMoveInput(input) and insideMain(input.Position) then UI.lastActive = tick() end
end))
F.hideWindow = function() setWindowOpen(false) end
ToggleBtn.MouseButton1Click:Connect(function()
if toggleWasDragged() then return end
UI.lastActive = tick()
TweenService:Create(Toggle, TweenInfo.new(0.08), { Rotation = 10 }):Play()
task.delay(0.08, function()
TweenService:Create(Toggle, TweenInfo.new(0.12), { Rotation = 0 }):Play()
end)
setWindowOpen(not Main.Visible)
end)
local function makeEdge(size, pos, axis, visual)
local e = Instance.new("Frame")
e.Size = size
e.Position = pos
e.BackgroundColor3 = theme.gold
e.BackgroundTransparency = visual and 0.35 or 1
e.BorderSizePixel = 0
e.Active = true
e.ZIndex = 30
e.Parent = Main
if visual then corner(e, 1000) end
makeResizable(Main, e, MIN_WIN, maxWindowSize, function()
saveMainSize()
clampToScreen(Main)
end, axis)
table.insert(resizeParts, e)
return e
end
makeEdge(UDim2.new(0, 16, 0, 16), UDim2.new(1, -18, 1, -18), "xy", true)
makeEdge(UDim2.new(0, 8, 1, -150), UDim2.new(1, -8, 0, 110), "x", false)
makeEdge(UDim2.new(1, -90, 0, 10), UDim2.new(0, 0, 1, -10), "y", false)
F.applyImages = function()
local bg = resolveImage(S.imgBg)
if UI.BgImage and UI.BgImage.Parent then
if bg then
UI.BgImage.Image = bg
UI.BgImage.Visible = true
else
UI.BgImage.Visible = false
end
end
local ci = resolveImage(S.imgCircle)
if UI.ToggleImage and UI.ToggleImage.Parent then
if ci then
UI.ToggleImage.Image = ci
UI.ToggleImage.Visible = true
UI.ToggleIcon.Visible = false
else
UI.ToggleImage.Visible = false
UI.ToggleIcon.Visible = true
end
end
return bg ~= nil, ci ~= nil
end
F.updateNet()
F.updateCounts()
F.flyUi(CT.flying)
F.switchTab(activeTab)
task.spawn(F.applyImages)
end
F.rebuild = function()
task.defer(function()
if not alive() then return end
local ok, err = pcall(buildUI)
if not ok then
addError("rebuild", err)
warn("[HaiderView] UI rebuild error: " .. tostring(err))
end
end)
end
do
local old = PlayerGui:FindFirstChild("IronHunterUI")
if old then old:Destroy() end
end
local okUI, errUI = pcall(buildUI)
if not okUI then
addError("ui", errUI)
warn("[HaiderView] UI error: " .. tostring(errUI))
end
addLog("Haider View v" .. K.VERSION .. " — Instagram: l.9_1 | Telegram: QPPPPX | Discord: 3h._ | TikTok: ofme")
queueSelf()
if type(game.JobId) == "string" and game.JobId ~= "" then
S.lastServer = { id = game.JobId, placeId = K.PLACE_ID, at = os.time() }
saveSettings()
end
pcall(function()
TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
if alive() then onTeleportInitFailed(player, result, msg) end
end)
end)
pcall(function()
LocalPlayer.OnTeleport:Connect(function(state)
if alive() then onTeleportState(state) end
end)
end)
pcall(function()
GuiService.ErrorMessageChanged:Connect(function()
if alive() then onGuiError() end
end)
end)
if S.lowGfx then applyLowGfx(true) end
task.spawn(function()
local n = 0
while alive() do
n = n + 1
if F.updateNet then pcall(F.updateNet) end
if F.updateStats then pcall(F.updateStats) end
if n % 6 == 0 and F.refreshLive then pcall(F.refreshLive) end
task.wait(1)
end
end)
task.spawn(function()
local lastNotified = nil
local nextAt = tick() + S.refreshEvery
while alive() do
task.wait(1)
if S.autoRefresh and tick() >= nextAt and not jumping and not refreshing and not searching
and tick() >= NET.backoffUntil then
quickRefreshAll()
local waited = 0
while alive() and refreshing and waited < 90 do
task.wait(1)
waited = waited + 1
end
local top = filtered[1]
if S.notifyMatch and top and top.id ~= lastNotified then
lastNotified = top.id
task.spawn(function()
sendWebhook(T("wh_match", top.playing, top.maxPlayers), false)
end)
end
nextAt = tick() + S.refreshEvery
elseif not S.autoRefresh then
nextAt = tick() + S.refreshEvery
end
end
end)
task.spawn(function()
task.wait(12)
while alive() do
if tick() >= NET.backoffUntil then
pcall(fetchGameInfo)
pcall(fetchRobloxStatus)
end
for _ = 1, 300 do
if not alive() then return end
task.wait(1)
end
end
end)
pcall(function()
RunService.Heartbeat:Connect(function(dt)
if alive() then ctrlStep(dt) end
end)
end)
task.spawn(function()
local lastScan = 0
while alive() do
if ESP.dirty then
ESP.dirty = false
lastScan = 0
end
if P.esp.on and tick() - lastScan > 3 then
lastScan = tick()
pcall(espScan)
end
if P.esp.on or P.esp.friends then
pcall(espStep)
elseif next(ESP.tags) ~= nil or next(ESP.friendTags) ~= nil then
espClear()
end
task.wait(0.4)
end
end)
task.spawn(function()
task.wait(4)
if not alive() then return end
pcall(detectMap)
autoAdaptMap()
end)
task.spawn(function()
while alive() do
task.wait(1)
if S.autoHide and UI.Main and UI.Main.Parent and UI.Main.Visible and not refreshing and not searching
and not jumping and UserInputService:GetFocusedTextBox() == nil
and tick() - (UI.lastActive or 0) > S.hideAfter and F.hideWindow then
F.hideWindow()
end
end
end)
task.spawn(refreshAll)
task.spawn(postArrivalCheck)
]====]

-- ============================================================
-- المُحمِّل: يحفظ المصدر ليعاد تشغيله بعد كل انتقال، ثم يشغّل السكربت
-- ============================================================
local OUTER_ENV = (typeof(getgenv) == "function" and getgenv()) or _G
OUTER_ENV.HaiderViewSrc = MAIN_SRC
if typeof(writefile) == "function" then
    pcall(writefile, "HaiderViewServer_src.lua", MAIN_SRC)
end

if typeof(loadstring) ~= "function" then
    warn("Haider View: منفّذك لا يدعم loadstring — تعذّر تشغيل السكربت.")
    return
end

local compiled, compileErr = loadstring(MAIN_SRC)
if not compiled then
    warn("Haider View: فشل تحويل الكود — " .. tostring(compileErr))
    return
end

local ok, runErr = pcall(compiled)
if not ok then
    warn("Haider View: فشل التشغيل — " .. tostring(runErr))
end