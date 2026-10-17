#!/usr/bin/env bash
# The music panel's ten-band equaliser.
#
# Upstream drives EasyEffects here. This fork uses a PipeWire filter-chain
# instead (no extra daemon): ten bq_peaking sections, one per slider, declared
# as a WirePlumber *smart filter*, so WirePlumber itself places it in front of
# whichever output is the default -- speakers, headphones, Bluetooth -- and
# follows when that changes.
#
#   get                 print the panel state (JSON)
#   set_band N GAIN     move one band live; marks the state as unsaved
#   apply               save: write the gains into the PipeWire config too
#   preset NAME         load a preset, live and saved
#   set_balance -1..1   channel balance, live and saved
#   set_mono|set_swap true|false
#                       fold to mono / swap left and right, live and saved
#   set_dynamics MODE   stored only -- no compressor among filter-chain builtins
#   reset_audio         balance, mono, swap and dynamics back to neutral
#   test | stop_test    play / stop a left-right-both test tone
#   install             (re)write the PipeWire config from the saved state
#
# Gains move live through `pw-cli set-param`, so dragging a slider never
# restarts the graph. The config file is rewritten on save only so the curve
# survives a PipeWire restart or a reboot.

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

STATE_FILE="$QS_STATE_MUSIC/eq_state.json"
CONF_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d/99-kizashi-eq.conf"
NODE="effect_input.kizashi-eq"
TEST_FILE="$QS_RUN_MUSIC/channel_test.wav"
TEST_PID_FILE="$QS_RUN_MUSIC/channel_test.pid"
FREQS=(31 63 125 250 500 1000 2000 4000 8000 16000)

# One-time move of the state from its old place in the runtime dir.
if [ ! -f "$STATE_FILE" ] && [ -f "$QS_RUN_MUSIC/eq_state.json" ]; then
    cp "$QS_RUN_MUSIC/eq_state.json" "$STATE_FILE"
fi
if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false, "balance": 0, "mono": false, "swap": false, "dynamics": "off"}' > "$STATE_FILE"
elif ! jq -e 'has("balance") and has("mono") and has("swap") and has("dynamics")' "$STATE_FILE" >/dev/null 2>&1; then
    updated=$(jq -c '.balance //= 0 | .mono //= false | .swap //= false | .dynamics //= "off"' "$STATE_FILE") &&
        echo "$updated" > "$STATE_FILE"
fi

# Always as floats: the filter's controls are Float, and pw-cli passes a bare
# integer through as Int, which the node ignores.
gains() {
    jq -r '[.b1, .b2, .b3, .b4, .b5, .b6, .b7, .b8, .b9, .b10] | map(tonumber? // 0) | .[]' "$STATE_FILE" \
        | xargs printf '%.1f\n'
}

# Balance, mono and swap are one 2x2 matrix in front of the bands: two mixers,
# each summing both input channels with its own pair of gains. Printed as
# "ll lr rl rr": what the left output takes from L and from R, then the right.
matrix() {
    jq -r '[(.balance // 0 | tonumber? // 0), (.mono // false), (.swap // false)] | @tsv' "$STATE_FILE" |
    awk -F'\t' '{
        b = $1 + 0; if (b < -1) b = -1; if (b > 1) b = 1
        if ($2 == "true")      { ll = .5; lr = .5; rl = .5; rr = .5 }
        else if ($3 == "true") { ll = 0;  lr = 1;  rl = 1;  rr = 0 }
        else                   { ll = 1;  lr = 0;  rl = 0;  rr = 1 }
        gl = (b > 0) ? 1 - b : 1
        gr = (b < 0) ? 1 + b : 1
        printf "%.3f %.3f %.3f %.3f\n", ll * gl, lr * gl, rl * gr, rr * gr
    }'
}

apply_live() {
    local params="" i=1 g ll lr rl rr
    while read -r g; do
        params+=" \"eq_l_${i}:Gain\" ${g} \"eq_r_${i}:Gain\" ${g}"
        i=$((i + 1))
    done < <(gains)
    read -r ll lr rl rr < <(matrix)
    params+=" \"mix_l:Gain 1\" ${ll} \"mix_l:Gain 2\" ${lr} \"mix_r:Gain 1\" ${rl} \"mix_r:Gain 2\" ${rr}"
    pw-cli set-param "$NODE" Props "{ params = [${params} ] }" >/dev/null 2>&1
}

# The graph is written per channel on purpose. A mono graph would be copied
# for each channel by filter-chain, and then nothing could mix one channel
# into the other.
graph() {
    local nodes="" links="" i g ch ll lr rl rr
    local -a g_arr
    mapfile -t g_arr < <(gains)
    read -r ll lr rl rr < <(matrix)
    local pad="                    "
    nodes+="${pad}{ type = builtin name = in_l label = copy }"$'\n'
    nodes+="${pad}{ type = builtin name = in_r label = copy }"$'\n'
    nodes+="${pad}{ type = builtin name = mix_l label = mixer control = { \"Gain 1\" = ${ll} \"Gain 2\" = ${lr} } }"$'\n'
    nodes+="${pad}{ type = builtin name = mix_r label = mixer control = { \"Gain 1\" = ${rl} \"Gain 2\" = ${rr} } }"$'\n'
    links+="${pad}{ output = \"in_l:Out\" input = \"mix_l:In 1\" }"$'\n'
    links+="${pad}{ output = \"in_r:Out\" input = \"mix_l:In 2\" }"$'\n'
    links+="${pad}{ output = \"in_l:Out\" input = \"mix_r:In 1\" }"$'\n'
    links+="${pad}{ output = \"in_r:Out\" input = \"mix_r:In 2\" }"$'\n'
    for ch in l r; do
        links+="${pad}{ output = \"mix_${ch}:Out\" input = \"eq_${ch}_1:In\" }"$'\n'
        for i in "${!FREQS[@]}"; do
            g=${g_arr[$i]:-0}
            nodes+="${pad}{ type = builtin name = eq_${ch}_$((i + 1)) label = bq_peaking control = { \"Freq\" = ${FREQS[$i]}.0 \"Q\" = 1.4 \"Gain\" = ${g} } }"$'\n'
            if [ "$i" -gt 0 ]; then
                links+="${pad}{ output = \"eq_${ch}_${i}:Out\" input = \"eq_${ch}_$((i + 1)):In\" }"$'\n'
            fi
        done
    done
    cat <<EOF
            filter.graph = {
                nodes = [
${nodes}                ]
                links = [
${links}                ]
                inputs  = [ "in_l:In" "in_r:In" ]
                outputs = [ "eq_l_${#FREQS[@]}:Out" "eq_r_${#FREQS[@]}:Out" ]
            }
EOF
}

write_conf() {
    mkdir -p "$(dirname "$CONF_FILE")"
    cat > "$CONF_FILE" <<EOF
# Kizashi's ten-band equaliser. Written by src/quickshell/media/equalizer.sh;
# edits here are overwritten when the panel saves.
#
# filter.smart makes WirePlumber insert it in front of the default output and
# re-link it when the default changes, so it is never chosen as a device itself.
context.modules = [
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Kizashi Equalizer"
            media.name       = "Kizashi Equalizer"
$(graph)
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name         = "${NODE}"
                media.class       = Audio/Sink
                filter.smart      = true
                filter.smart.name = "kizashi-eq"
            }
            playback.props = {
                node.name         = "effect_output.kizashi-eq"
                node.passive      = true
                filter.smart      = true
                filter.smart.name = "kizashi-eq"
            }
        }
    }
]
EOF
}

save_preset() {
    balance=$(jq -r '.balance // 0' "$STATE_FILE")
    mono=$(jq -r '.mono // false' "$STATE_FILE")
    swap=$(jq -r '.swap // false' "$STATE_FILE")
    dynamics=$(jq -r '.dynamics // "off"' "$STATE_FILE")

    jq -n -c \
        --arg b1 "$1" \
        --arg b2 "$2" \
        --arg b3 "$3" \
        --arg b4 "$4" \
        --arg b5 "$5" \
        --arg b6 "$6" \
        --arg b7 "$7" \
        --arg b8 "$8" \
        --arg b9 "$9" \
        --arg b10 "${10}" \
        --arg p "${11}" \
        --argjson balance "$balance" \
        --argjson mono "$mono" \
        --argjson swap "$swap" \
        --arg dynamics "$dynamics" \
        '{
            "b1": $b1,
            "b2": $b2,
            "b3": $b3,
            "b4": $b4,
            "b5": $b5,
            "b6": $b6,
            "b7": $b7,
            "b8": $b8,
            "b9": $b9,
            "b10": $b10,
            "preset": $p,
            "pending": false,
            "balance": $balance,
            "mono": $mono,
            "swap": $swap,
            "dynamics": $dynamics
        }' > "$STATE_FILE"
}

stop_test() {
    if [ -f "$TEST_PID_FILE" ]; then
        pid=$(cat "$TEST_PID_FILE" 2>/dev/null || true)
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            kill "$pid" >/dev/null 2>&1 || true
        fi
        rm -f "$TEST_PID_FILE"
    fi
}

play_test() {
    stop_test

    if [ ! -s "$TEST_FILE" ]; then
        python3 - "$TEST_FILE" <<'PY'
import math, struct, sys, wave

path = sys.argv[1]
rate = 48000
segments = [(0.75, 660, 0), (0.18, 0, 0), (0.75, 0, 880),
            (0.18, 0, 0), (1.0, 770, 770)]
with wave.open(path, 'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(rate)
    for duration, left_hz, right_hz in segments:
        for index in range(int(duration * rate)):
            fade = min(1.0, index / (rate * 0.015),
                       (duration * rate - index) / (rate * 0.015))
            def sample(freq):
                return int(9000 * fade * math.sin(2 * math.pi * freq * index / rate)) if freq else 0
            out.writeframesraw(struct.pack('<hh', sample(left_hz), sample(right_hz)))
PY
    fi

    # В выход по умолчанию: умный фильтр и так стоит перед ним, поэтому тон
    # проходит через баланс, моно и перестановку каналов -- их и проверяем.

    (
        player_pid=""
        cleanup_test() {
            [ -n "$player_pid" ] && kill "$player_pid" >/dev/null 2>&1 || true
            if [ "$(cat "$TEST_PID_FILE" 2>/dev/null)" = "$BASHPID" ]; then
                rm -f "$TEST_PID_FILE"
            fi
        }
        trap cleanup_test EXIT TERM INT
        pw-play \
            -P '{"application.id":"kizashi-audio-test","application.name":"Kizashi audio test","media.role":"music"}' \
            "$TEST_FILE" >/dev/null 2>&1 &
        player_pid=$!
        wait "$player_pid"
    ) &
    echo "$!" > "$TEST_PID_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get")
        cat "$STATE_FILE"
        ;;

    "set_band")
        updated=$(jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true" "$STATE_FILE")
        echo "$updated" > "$STATE_FILE"
        apply_live
        ;;

    "apply")
        updated=$(jq -c ".pending = false" "$STATE_FILE")
        echo "$updated" > "$STATE_FILE"
        apply_live
        write_conf
        ;;

    "set_balance")
        if ! [[ "$arg1" =~ ^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]; then
            exit 1
        fi

        updated=$(jq -c \
            --argjson val "$arg1" \
            '.balance = (if $val < -1 then -1 elif $val > 1 then 1 else $val end)' \
            "$STATE_FILE") || exit 1

        echo "$updated" > "$STATE_FILE"
        apply_live
        write_conf
        ;;

    "set_mono"|"set_swap")
        [ "$arg1" = "true" ] || [ "$arg1" = "false" ] || exit 1
        key=${cmd#set_}
        jq -c --arg key "$key" --argjson val "$arg1" '.[$key] = $val' \
            "$STATE_FILE" > "$STATE_FILE.tmp.$$" || exit 1
        mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
        apply_live
        write_conf
        ;;

    "set_dynamics")
        case "$arg1" in off|balanced|night) ;; *) exit 1 ;; esac
        jq -c --arg val "$arg1" '.dynamics = $val' \
            "$STATE_FILE" > "$STATE_FILE.tmp.$$" || exit 1
        mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
        # Только запоминается. У апстрима это компрессор EasyEffects; среди
        # встроенных узлов filter-chain компрессора нет, а LADSPA-плагинов в
        # системе нет, так что эффекта у переключателя пока нет.
        ;;

    "reset_audio")
        jq -c '.balance = 0 | .mono = false | .swap = false | .dynamics = "off"' \
            "$STATE_FILE" > "$STATE_FILE.tmp.$$" || exit 1
        mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
        stop_test
        apply_live
        write_conf
        ;;

    "test")
        play_test
        ;;

    "stop_test")
        stop_test
        ;;

    "preset")
        case $arg1 in
            "Flat")
                save_preset 0 0 0 0 0 0 0 0 0 0 "Flat"
                ;;

            "Bass")
                save_preset 5 7 5 2 1 0 0 0 1 2 "Bass"
                ;;

            "Treble")
                save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble"
                ;;

            "Vocal")
                save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal"
                ;;

            "Pop")
                save_preset 2 4 2 0 1 2 4 2 1 2 "Pop"
                ;;

            "Rock")
                save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock"
                ;;

            "Jazz")
                save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz"
                ;;

            "Classic")
                save_preset 0 1 2 2 2 2 1 2 3 4 "Classic"
                ;;
        esac
        apply_live
        write_conf
        ;;
    "install")
        write_conf
        ;;
esac
