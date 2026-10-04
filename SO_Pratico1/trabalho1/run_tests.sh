#!/bin/bash
# run_tests.sh — corre um cenario + algoritmo N vezes e regista os resultados
# automaticamente num CSV (Elapsed/CPU/BLOCKED), sem copiar nada a mao.
#
# Uso:
#   ./run_tests.sh <cenario> <ALGORITMO> [n_corridas]
#
# Exemplos:
#   ./run_tests.sh 1 FIFO
#   ./run_tests.sh 1 FIFO 3
#   ./run_tests.sh 5 SJF 5
#
# Resultado: cria/acrescenta ao ficheiro resultados.csv (na pasta atual), com as
# colunas: Cenario,Algoritmo,Aplicacao,Corrida,Elapsed,CPU,BLOCKED
# Esse ficheiro pode depois ser aberto no Excel ou colado na folha Dados_Brutos.

set -u

SCEN="${1:?Uso: ./run_tests.sh <cenario> <ALGORITMO> [n_corridas]}"
ALGO="${2:?Uso: ./run_tests.sh <cenario> <ALGORITMO> [n_corridas]}"
NRUNS="${3:-3}"
OUT_CSV="resultados.csv"

# --- localizar os executaveis (build/ ou cmake-build-debug/) ---
for d in build cmake-build-debug; do
    if [ -x "$d/ossim" ]; then BUILD_DIR="$d"; EXT=""; break; fi
    if [ -x "$d/ossim.exe" ]; then BUILD_DIR="$d"; EXT=".exe"; break; fi
done
if [ -z "${BUILD_DIR:-}" ]; then
    echo "Erro: nao encontrei build/ossim nem cmake-build-debug/ossim. Compila primeiro." >&2
    exit 1
fi
OSSIM="./$BUILD_DIR/ossim$EXT"
APP="./$BUILD_DIR/application$EXT"

# --- lista de aplicacoes por cenario ---
case "$SCEN" in
    1) APPS=(A B C) ;;
    2) APPS=(A B C D E F) ;;
    3) APPS=(A B C) ;;
    4) APPS=(A B C) ;;
    5) APPS=(A B C D E) ;;
    *) echo "Cenario '$SCEN' desconhecido. Edita o script para o acrescentar." >&2; exit 1 ;;
esac

SCEN_DIR="scenarios/$SCEN"
for app in "${APPS[@]}"; do
    if [ ! -f "$SCEN_DIR/$app.csv" ]; then
        echo "Erro: nao encontrei $SCEN_DIR/$app.csv" >&2
        exit 1
    fi
done

# --- cabecalho do CSV, so na primeira vez ---
if [ ! -f "$OUT_CSV" ]; then
    echo "Cenario,Algoritmo,Aplicacao,Corrida,Elapsed,CPU,BLOCKED" > "$OUT_CSV"
fi

echo "=== Cenario $SCEN | Algoritmo $ALGO | $NRUNS corrida(s) ==="

for run in $(seq 1 "$NRUNS"); do
    echo "--- Corrida $run/$NRUNS ---"

    # limpar qualquer ossim anterior preso
    pkill -f "ossim --sched" >/dev/null 2>&1
    rm -f /tmp/scheduler.sock
    sleep 0.3

    # ligar o scheduler em segundo plano
    "$OSSIM" --sched "$ALGO" > /tmp/ossim_run.log 2>&1 &
    OSSIM_PID=$!
    sleep 0.5   # dar tempo a abrir o socket

    # correr todas as aplicacoes do cenario em paralelo, capturar o output
    APP_LOG=$(mktemp)
    APP_PIDS=()
    for app in "${APPS[@]}"; do
        "$APP" "$SCEN_DIR/$app.csv" >> "$APP_LOG" 2>&1 &
        APP_PIDS+=("$!")
    done
    wait "${APP_PIDS[@]}"   # espera APENAS pelas applications (nao pelo ossim, que nunca termina sozinho)

    # desligar o scheduler desta corrida
    kill "$OSSIM_PID" >/dev/null 2>&1
    wait "$OSSIM_PID" 2>/dev/null

    # extrair "Application X (PID n) finished ..., Elapsed: a seconds, CPU: b seconds, BLOCKED: c seconds"
    n_found=0
    while IFS= read -r line; do
        parsed=$(echo "$line" | sed -nE \
            's/Application ([A-Za-z0-9_]+) .*Elapsed: ([0-9.]+) seconds, CPU: ([0-9.]+) seconds, BLOCKED: ([0-9.]+) seconds.*/\1,\2,\3,\4/p')
        if [ -n "$parsed" ]; then
            app_name=$(echo "$parsed" | cut -d',' -f1)
            elapsed=$(echo "$parsed" | cut -d',' -f2)
            cpu=$(echo "$parsed" | cut -d',' -f3)
            blocked=$(echo "$parsed" | cut -d',' -f4)
            echo "$SCEN,$ALGO,$app_name,$run,$elapsed,$cpu,$blocked" >> "$OUT_CSV"
            echo "  -> $app_name: Elapsed=$elapsed CPU=$cpu BLOCKED=$blocked"
            n_found=$((n_found + 1))
        fi
    done < "$APP_LOG"

    if [ "$n_found" -ne "${#APPS[@]}" ]; then
        echo "  AVISO: esperava ${#APPS[@]} resultados, encontrei $n_found. Ve /tmp/ossim_run.log e o log desta corrida." >&2
    fi

    rm -f "$APP_LOG"
done

echo "=== Concluido. Resultados em $OUT_CSV ==="
