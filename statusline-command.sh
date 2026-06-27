#!/usr/bin/env bash
# Claude Code status line — 3 lines + panther bar
# Line 1: IDENTIDAD   — project | session (elapsed) | model | branch | effort | clock
# Line 2: CONTEXTO    — bar % | libres | 5h | semana | costo | caché hit
# Line 3: CÓDIGO      — +añadidas | -borradas | archivos | edits | entrada | salida
# Line 4: panther bar

export PATH="$PATH:/c/Users/lanitaEmperadora/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_Microsoft.Winget.Source_8wekyb3d8bbwe"

input=$(cat)

# ── Parse JSON ─────────────────────────────────────────────
model=$(echo "$input"        | jq -r '.model.display_name // "Claude"')
model_id=$(echo "$input"     | jq -r '.model.id // ""')
cwd=$(echo "$input"          | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")
pct=$(echo "$input"          | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
rem_pct=$(echo "$input"      | jq -r '.context_window.remaining_percentage // empty')
ctx_size=$(echo "$input"     | jq -r '.context_window.context_window_size // 0')
total_in=$(echo "$input"     | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input"    | jq -r '.context_window.total_output_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input"   | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
session_id=$(echo "$input"   | jq -r '.session_id // "default"')
session_name=$(echo "$input" | jq -r '.session_name // empty')
effort=$(echo "$input"       | jq -r '.effort.level // empty')
vim_mode=$(echo "$input"     | jq -r '.vim.mode // empty')
five_h=$(echo "$input"       | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input"      | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── Colors ─────────────────────────────────────────────────
CYAN='\033[0;36m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'
DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'

clock=$(date +"%H:%M:%S")
term_w=$(tput cols 2>/dev/null || echo 100)

# ── Context bar (16 blocks) ────────────────────────────────
pct_int=${pct:-0}
filled=$((pct_int * 16 / 100)); empty=$((16 - filled))
[ "$filled" -gt 0 ] && printf -v _f "%${filled}s" && bar="${_f// /█}" || bar=""
[ "$empty"  -gt 0 ] && printf -v _e "%${empty}s"  && bar="${bar}${_e// /░}"
if   [ "$pct_int" -ge 90 ]; then bar_color="$RED"
elif [ "$pct_int" -ge 70 ]; then bar_color="$YELLOW"
else bar_color="$GREEN"; fi

# ── Remaining tokens ───────────────────────────────────────
remaining_tok=""
if [ -n "$rem_pct" ] && [ "$ctx_size" -gt 0 ]; then
    rem_raw=$(awk -v r="$rem_pct" -v s="$ctx_size" 'BEGIN{printf "%.0f", r/100*s}')
    remaining_tok=$(awk -v v="$rem_raw" 'BEGIN{
        if (v>=1000000) printf "%.1fM",v/1000000
        else if (v>=1000) printf "%.0fk",v/1000
        else printf "%d",v
    }')
fi

# ── Cost estimate ──────────────────────────────────────────
cost_est=""
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    cost_est=$(awk -v ti="$total_in" -v to="$total_out" \
                   -v cr="$cache_read" -v cc="$cache_create" -v mid="$model_id" \
    'BEGIN {
        p_in=3.00; p_out=15.00; p_cw=3.75; p_cr=0.30
        if (mid~/haiku/) { p_in=0.80; p_out=4.00;  p_cw=1.00;  p_cr=0.08 }
        if (mid~/opus/)  { p_in=15.0; p_out=75.0;  p_cw=18.75; p_cr=1.50 }
        bi=ti-cr-cc; if(bi<0)bi=0
        c=(bi/1e6)*p_in+(to/1e6)*p_out+(cc/1e6)*p_cw+(cr/1e6)*p_cr
        if(c<0.001) printf "~$0"
        else if(c<1.0) printf "$%.2f",c
        else printf "$%.2f",c
    }')
fi

# ── Cache hit % ────────────────────────────────────────────
cache_hit=""; cache_hit_num=0
if [ "$total_in" -gt 0 ] && [ "$cache_read" -gt 0 ]; then
    cache_hit=$(awk -v cr="$cache_read" -v ti="$total_in" 'BEGIN{printf "%.0f%%",cr/ti*100}')
    cache_hit_num=$(echo "$cache_hit" | tr -d '%')
fi

# ── Git cache (5 s TTL) ────────────────────────────────────
CACHE_FILE="/tmp/claude-sl-git-${session_id}"
if [ ! -f "$CACHE_FILE" ] || \
   [ $(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) )) -gt 5 ]; then
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
        staged=$(git --no-optional-locks -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        modified=$(git --no-optional-locks -C "$cwd" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        printf '%s|%s|%s' "$branch" "$staged" "$modified" > "$CACHE_FILE"
    else printf '||' > "$CACHE_FILE"; fi
fi
IFS='|' read -r branch staged modified < "$CACHE_FILE"

# ── Elapsed session time ───────────────────────────────────
START_FILE="/tmp/claude-sl-start-${session_id}"
[ ! -f "$START_FILE" ] && date +%s > "$START_FILE"
elapsed_s=$(( $(date +%s) - $(cat "$START_FILE" 2>/dev/null || date +%s) ))
elapsed_h=$(( elapsed_s / 3600 )); elapsed_m=$(( (elapsed_s % 3600) / 60 ))
if   [ "$elapsed_h" -gt 0 ]; then elapsed_fmt="${elapsed_h}h${elapsed_m}m"
elif [ "$elapsed_m" -gt 0 ]; then elapsed_fmt="${elapsed_m}m"
else elapsed_fmt="${elapsed_s}s"; fi

# ── Code tracking stats ────────────────────────────────────
STATS_FILE="/tmp/claude-code-stats-${session_id}"
lines_added=0; lines_deleted=0; files_edited=0; edit_count=0
if [ -f "$STATS_FILE" ]; then
    lines_added=$(jq  -r '.lines_added   // 0' "$STATS_FILE" 2>/dev/null || echo 0)
    lines_deleted=$(jq -r '.lines_deleted // 0' "$STATS_FILE" 2>/dev/null || echo 0)
    files_edited=$(jq  -r '.files_edited  // 0' "$STATS_FILE" 2>/dev/null || echo 0)
    edit_count=$(jq    -r '.edit_count    // 0' "$STATS_FILE" 2>/dev/null || echo 0)
fi

# ── Token formatter ────────────────────────────────────────
fmt_tok() {
    awk -v t="$1" 'BEGIN{
        if(t>=1000000) printf "%.1fM",t/1000000
        else if(t>=1000) printf "%.0fk",t/1000
        else printf "%d",t
    }'
}

# ── Join non-empty parts with │ ───────────────────────────
PIPE=" ${DIM}│${RESET} "
join_parts() {
    local first=1
    for p in "$@"; do
        [ -z "$p" ] && continue
        if [ $first -eq 1 ]; then printf '%b' "$p"; first=0
        else printf '%b%b' "$PIPE" "$p"; fi
    done
    printf '\n'
}

awk_cmp() { awk "BEGIN{exit !($1 $2 $3)}"; }

# ══ LINE 1: IDENTIDAD ══════════════════════════════════════
p1_head="${MAGENTA}${BOLD}(Φ.Φ) 🐾${RESET}"
p1_dir="${CYAN}${BOLD}${dir}${RESET}"

if [ -n "$session_name" ]; then
    p1_session="${MAGENTA}😺 ${BOLD}${session_name}${RESET}${DIM}(${elapsed_fmt})${RESET}"
elif [ -n "$branch" ]; then
    p1_session="${MAGENTA}😺 ${BOLD}${branch}${RESET}${DIM}(${elapsed_fmt})${RESET}"
else
    p1_session="${DIM}😺 ${elapsed_fmt}${RESET}"
fi

p1_model="${YELLOW}🐈‍⬛ ${BOLD}${model}${RESET}"

p1_branch=""
if [ -n "$branch" ] && [ -n "$session_name" ]; then
    p1_branch="${GREEN}⎇ ${branch}${RESET}"
fi
[ "${staged:-0}"   -gt 0 ] && p1_branch+=" ${GREEN}+${staged}s${RESET}"
[ "${modified:-0}" -gt 0 ] && p1_branch+=" ${YELLOW}~${modified}m${RESET}"

p1_effort=""; [ -n "$effort"   ] && p1_effort="${DIM}🐾 ${effort}${RESET}"
p1_vim="";    [ -n "$vim_mode" ] && p1_vim="${GREEN}⌨️[${vim_mode}]${RESET}"
p1_clock="${BLUE}😺 ${BOLD}${clock}${RESET}"

join_parts "${p1_head} ${p1_dir}" "$p1_session" "$p1_model" "$p1_branch" "$p1_effort" "$p1_vim" "$p1_clock"

# ══ LINE 2: CONTEXTO + COSTOS ══════════════════════════════
p2_bar="${bar_color}${bar}${RESET} ${BOLD}${pct_int}%${RESET}"
p2_rem=""; [ -n "$remaining_tok" ] && p2_rem="${DIM}💾 ${WHITE}${remaining_tok}${RESET}"

rate_parts=()
if [ -n "$five_h" ]; then
    five_fmt=$(printf '%.0f' "$five_h")
    if   [ "$five_fmt" -ge 90 ]; then rc="$RED"
    elif [ "$five_fmt" -ge 70 ]; then rc="$YELLOW"; else rc="$GREEN"; fi
    rate_parts+=("${DIM}⏱️5h:${RESET}${rc}${BOLD}${five_fmt}%${RESET}")
fi
if [ -n "$seven_d" ]; then
    seven_fmt=$(printf '%.0f' "$seven_d")
    if   [ "$seven_fmt" -ge 90 ]; then rc7="$RED"
    elif [ "$seven_fmt" -ge 70 ]; then rc7="$YELLOW"; else rc7="$GREEN"; fi
    rate_parts+=("${DIM}📅sem:${RESET}${rc7}${BOLD}${seven_fmt}%${RESET}")
fi

p2_cost=""
if [ -n "$cost_est" ]; then
    if echo "$cost_est" | grep -q '~\$0'; then ce_color="$DIM"
    else
        val=$(echo "$cost_est" | sed 's/\$//')
        if   awk_cmp "$val" ">=" 1.0;  then ce_color="$RED"
        elif awk_cmp "$val" ">=" 0.10; then ce_color="$YELLOW"
        else ce_color="$GREEN"; fi
    fi
    p2_cost="${ce_color}${BOLD}💰 ${cost_est}${RESET}"
fi

p2_cache=""
if [ -n "$cache_hit" ]; then
    if   [ "$cache_hit_num" -ge 60 ]; then chc="$GREEN"
    elif [ "$cache_hit_num" -ge 30 ]; then chc="$YELLOW"; else chc="$RED"; fi
    p2_cache="${DIM}🐾 caché:${RESET}${chc}${BOLD}${cache_hit}${RESET}"
fi

join_parts "${DIM}🐱${RESET} ${p2_bar}" "$p2_rem" "${rate_parts[@]}" "$p2_cost" "$p2_cache"

# ══ LINE 3: CÓDIGO ═════════════════════════════════════════
code_parts=()
if [ "$edit_count" -gt 0 ] || [ "$lines_added" -gt 0 ] || [ "$lines_deleted" -gt 0 ]; then
    code_parts+=("${GREEN}${BOLD}+${lines_added}${RESET}${DIM}añ${RESET}")
    code_parts+=("${RED}${BOLD}-${lines_deleted}${RESET}${DIM}borr${RESET}")
    code_parts+=("${CYAN}📁${files_edited}${RESET}")
    code_parts+=("${YELLOW}✏️${edit_count}edits${RESET}")
else
    code_parts+=("${DIM}sin edits${RESET}")
fi

tok_in_fmt=$(fmt_tok "$total_in"); tok_out_fmt=$(fmt_tok "$total_out")
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    code_parts+=("${DIM}📨${WHITE}${tok_in_fmt}${RESET}")
    code_parts+=("${DIM}📤${WHITE}${tok_out_fmt}${RESET}")
fi

printf '%b ' "${DIM}🐱 código:${RESET}"
join_parts "${code_parts[@]}"

# ══ PANTHER BAR ════════════════════════════════════════════
stripe_len=$(( term_w - 12 ))
[ "$stripe_len" -lt 4 ] && stripe_len=4
panther_colors=( "\033[0;35m" "\033[2;35m" "\033[1;35m" "\033[0;34m" "\033[2;34m" "\033[0;30m" )
pc_count=${#panther_colors[@]}
panther_bar=""
for (( i=0; i<stripe_len; i++ )); do
    panther_bar+="${panther_colors[$((i % pc_count))]}═"
done
printf '%b  %b\n' "${panther_bar}${RESET}" "\033[1;35m(ΦωΦ) 🐈‍⬛\033[0m"
