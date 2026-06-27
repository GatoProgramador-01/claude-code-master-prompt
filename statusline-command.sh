#!/usr/bin/env bash
# Claude Code status line — 3-line layout
# Line 1: dir | model | git branch | effort | vim | clock
# Line 2: context bar % | remaining tokens | rate limit
# Line 3: token counters (in/out/cache) + cost estimate + analytics
export PATH="$PATH:/c/Users/lanitaEmperadora/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"

input=$(cat)

# --- Parse JSON ---
model=$(echo "$input"        | jq -r '.model.display_name // "Claude"')
model_id=$(echo "$input"     | jq -r '.model.id // ""')
cwd=$(echo "$input"          | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")
pct=$(echo "$input"          | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
rem_pct=$(echo "$input"      | jq -r '.context_window.remaining_percentage // empty')
ctx_size=$(echo "$input"     | jq -r '.context_window.context_window_size // 0')
total_in=$(echo "$input"     | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input"    | jq -r '.context_window.total_output_tokens // 0')
cur_in=$(echo "$input"       | jq -r '.context_window.current_usage.input_tokens // 0')
cur_out=$(echo "$input"      | jq -r '.context_window.current_usage.output_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input"   | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
session_id=$(echo "$input"   | jq -r '.session_id // "default"')
session_name=$(echo "$input" | jq -r '.session_name // empty')
effort=$(echo "$input"       | jq -r '.effort.level // empty')
vim_mode=$(echo "$input"     | jq -r '.vim.mode // empty')
five_h=$(echo "$input"       | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input"      | jq -r '.rate_limits.seven_day.used_percentage // empty')
version=$(echo "$input"      | jq -r '.version // empty')

# --- Colors ---
CYAN='\033[0;36m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; WHITE='\033[0;37m'
DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'

clock=$(date +"%H:%M:%S")

# --- Context bar (20 chars, traffic-light) ---
pct_int=${pct:-0}
filled=$((pct_int * 20 / 100)); empty=$((20 - filled)); bar=""
[ "$filled" -gt 0 ] && printf -v _f "%${filled}s" && bar="${_f// /█}"
[ "$empty"  -gt 0 ] && printf -v _e "%${empty}s"  && bar="${bar}${_e// /░}"
if   [ "$pct_int" -ge 90 ]; then bar_color="$RED"
elif [ "$pct_int" -ge 70 ]; then bar_color="$YELLOW"
else bar_color="$GREEN"; fi

# --- Remaining tokens (human-readable k) ---
remaining_tok=""
if [ -n "$rem_pct" ] && [ "$ctx_size" -gt 0 ]; then
    rem_raw=$(awk -v r="$rem_pct" -v s="$ctx_size" 'BEGIN{printf "%.0f", r/100*s}')
    remaining_tok=$(awk -v v="$rem_raw" 'BEGIN{
        if (v >= 1000) printf "%.0fk rem", v/1000
        else printf "%d rem", v
    }')
fi

# --- Cost estimate from cumulative token counts ---
# Prices per 1M tokens (Sonnet 4.x: $3 in / $15 out; Haiku 3.5: $0.80/$4; Opus: $15/$75)
# We key on model_id substring for routing; default to Sonnet pricing.
cost_est=""
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    cost_est=$(awk -v ti="$total_in" -v to="$total_out" \
                   -v cr="$cache_read" -v cc="$cache_create" \
                   -v mid="$model_id" \
    'BEGIN {
        # Default: claude-sonnet-4 pricing
        p_in=3.00; p_out=15.00; p_cache_w=3.75; p_cache_r=0.30
        if (mid ~ /haiku/) { p_in=0.80; p_out=4.00; p_cache_w=1.00; p_cache_r=0.08 }
        if (mid ~ /opus/)  { p_in=15.0; p_out=75.0; p_cache_w=18.75; p_cache_r=1.50 }
        # cache_read tokens billed at cache_read rate (not full input rate)
        billable_in = ti - cr - cc
        if (billable_in < 0) billable_in = 0
        cost = (billable_in/1e6)*p_in + (to/1e6)*p_out \
             + (cc/1e6)*p_cache_w + (cr/1e6)*p_cache_r
        if (cost < 0.001) printf "~$0"
        else if (cost < 1.0) printf "$%.3f", cost
        else printf "$%.2f", cost
    }')
fi

# --- Cache hit rate ---
cache_hit=""
if [ "$total_in" -gt 0 ] && [ "$cache_read" -gt 0 ]; then
    cache_hit=$(awk -v cr="$cache_read" -v ti="$total_in" \
        'BEGIN{printf "%.0f%%", cr/ti*100}')
fi

# --- Git (5s cache keyed by session_id) ---
CACHE_FILE="/tmp/claude-sl-git-${session_id}"
cache_is_stale() {
    [ ! -f "$CACHE_FILE" ] && return 0
    [ $(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) )) -gt 5 ]
}
if cache_is_stale; then
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
        staged=$(git --no-optional-locks -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        modified=$(git --no-optional-locks -C "$cwd" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        printf '%s|%s|%s' "$branch" "$staged" "$modified" > "$CACHE_FILE"
    else printf '||' > "$CACHE_FILE"; fi
fi
IFS='|' read -r branch staged modified < "$CACHE_FILE"

# --- Helper: join non-empty parts with " | " ---
join_parts() {
    local first=1
    for p in "$@"; do
        [ -z "$p" ] && continue
        if [ $first -eq 1 ]; then printf '%b' "$p"; first=0
        else printf ' | %b' "$p"; fi
    done
    printf '\n'
}

# awk comparison helper: returns 0 (true) if $1 op $2
awk_cmp() { awk "BEGIN{exit !($1 $2 $3)}"; }

# ── LINE 1: navigation ────────────────────────────────────────────
p1_dir="${CYAN}${BOLD}(Φ.Φ) 🐾 ${dir}${RESET}"
[ -n "$session_name" ] && p1_dir+=" ${DIM}(${session_name})${RESET}"
p1_model="${YELLOW}🐈‍⬛ ${model}${RESET}"
p1_git=""
if [ -n "$branch" ]; then
    p1_git="${GREEN}⎇ ${branch}${RESET}"
    [ "${staged:-0}"   -gt 0 ] && p1_git+=" ${GREEN}📦 ${staged} staged${RESET}"
    [ "${modified:-0}" -gt 0 ] && p1_git+=" ${YELLOW}✏️  ${modified} modified${RESET}"
fi
p1_effort=""; [ -n "$effort"   ] && p1_effort="${DIM}🐾 effort: ${effort}${RESET}"
p1_vim="";    [ -n "$vim_mode" ] && p1_vim="${GREEN}⌨️  [${vim_mode}]${RESET}"
p1_clock="${BLUE}😺 ${clock}${RESET}"
join_parts "$p1_dir" "$p1_model" "$p1_git" "$p1_effort" "$p1_vim" "$p1_clock"

# ── LINE 2: context window ────────────────────────────────────────
p2_ctx="🐾 ${bar_color}${bar}${RESET} ${BOLD}${pct_int}% usado${RESET}"
p2_rem=""; [ -n "$remaining_tok" ] && p2_rem="${DIM}💾 ${remaining_tok/rem/libres}${RESET}"
p2_rate=""
if [ -n "$five_h" ]; then
    five_fmt=$(printf '%.0f' "$five_h")
    if   [ "$five_fmt" -ge 90 ]; then rc="$RED"
    elif [ "$five_fmt" -ge 70 ]; then rc="$YELLOW"
    else rc="$GREEN"; fi
    p2_rate="${DIM}⏱️  5h:${RESET}${rc} ${five_fmt}%${RESET}"
fi
if [ -n "$seven_d" ]; then
    seven_fmt=$(printf '%.0f' "$seven_d")
    if   [ "$seven_fmt" -ge 90 ]; then rc7="$RED"
    elif [ "$seven_fmt" -ge 70 ]; then rc7="$YELLOW"
    else rc7="$GREEN"; fi
    [ -n "$p2_rate" ] && p2_rate+=" " || true
    p2_rate+="${DIM}📅 semana:${RESET}${rc7} ${seven_fmt}%${RESET}"
fi
join_parts "$p2_ctx" "$p2_rem" "$p2_rate"

# ── LINE 3: cost + token analytics ───────────────────────────────
p3=()

# Cost estimate (from token counts + model pricing table)
if [ -n "$cost_est" ]; then
    if echo "$cost_est" | grep -q '~\$0'; then ce_color="$DIM"
    elif echo "$cost_est" | grep -qE '^\$[0-9]'; then
        val=$(echo "$cost_est" | sed 's/\$//')
        if awk_cmp "$val" ">=" 1.0; then ce_color="$RED"
        elif awk_cmp "$val" ">=" 0.10; then ce_color="$YELLOW"
        else ce_color="$GREEN"; fi
    else ce_color="$GREEN"; fi
    p3+=("${ce_color}💰 ${cost_est} gastado${RESET}")
fi

# Cumulative tokens in / out (compact k notation)
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    tok_fmt=$(awk -v ti="$total_in" -v to="$total_out" 'BEGIN{
        sub = (ti >= 1000) ? sprintf("%.0fk", ti/1000) : sprintf("%d", ti)
        pub = (to >= 1000) ? sprintf("%.0fk", to/1000) : sprintf("%d", to)
        printf "📨 %s enviados · 📤 %s generados", sub, pub
    }')
    p3+=("${DIM}${tok_fmt}${RESET}")
fi

# Cache read hit rate
if [ -n "$cache_hit" ]; then
    hit_num=$(echo "$cache_hit" | tr -d '%')
    if   [ "$hit_num" -ge 60 ]; then chc="$GREEN"
    elif [ "$hit_num" -ge 30 ]; then chc="$YELLOW"
    else chc="$RED"; fi
    p3+=("${DIM}🐾 caché:${RESET} ${chc}${cache_hit}${RESET}")
fi

if [ ${#p3[@]} -gt 0 ]; then
    printf '%b' "${DIM}🐾${RESET} "
    join_parts "${p3[@]}"
fi

# ── LINE 4: black panther bar ────────────────────────────────
term_w=$(tput cols 2>/dev/null || echo 80)
PANTHER_FACE="(ΦωΦ) 🐈‍⬛"
pf_len=9
stripe_len=$(( term_w - pf_len - 3 ))
[ "$stripe_len" -lt 4 ] && stripe_len=4

# Dark purple → dim purple → dark cycle for panther stripes
panther_colors=(
    "\033[0;35m"    # magenta/purple
    "\033[2;35m"    # dim purple
    "\033[1;35m"    # bold purple
    "\033[0;34m"    # dark blue
    "\033[2;34m"    # dim blue
    "\033[0;30m"    # dark/black
)
pc_count=${#panther_colors[@]}
panther_bar=""
for (( i=0; i<stripe_len; i++ )); do
    panther_bar+="${panther_colors[$((i % pc_count))]}═"
done
panther_bar+="${RESET}"
printf '%b  %b\n' "$panther_bar" "\033[1;35m${PANTHER_FACE}\033[0m"
