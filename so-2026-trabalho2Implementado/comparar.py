"""Executar em Linux/WSL, na pasta do projecto; requer Python 3."""
import csv
import pathlib
import re
import signal
import subprocess
import time

out = pathlib.Path('resultados')
out.mkdir(exist_ok=True)
rows = []
for scenario in ('localidade', 'escritas'):
    for algo in ('FIFO', 'RANDOM', 'LRU', 'NRU', 'CLOCK'):
        log = out / f'{scenario}-{algo}.log'
        with log.open('w') as stream:
            server = subprocess.Popen(['./build/ossim', '--sched', 'FIFO',
                '--vm', algo, '--vpages', '5', '--pframes', '4', '--threshold', '1'],
                stdout=stream, stderr=subprocess.STDOUT)
            try:
                # Socket AF_UNIX do código base; não executar dois simuladores em paralelo.
                for _ in range(100):
                    if server.poll() is not None:
                        raise RuntimeError(f'ossim terminou: consultar {log}')
                    if pathlib.Path('/tmp/scheduler.sock').exists():
                        break
                    time.sleep(.05)
                time.sleep(.1)
                app = subprocess.run(['./build/application', f'cenarios/{scenario}.csv'],
                    capture_output=True, text=True, timeout=20, check=True)
                (out / f'{scenario}-{algo}-app.log').write_text(app.stdout + app.stderr)
                time.sleep(.2)
            finally:
                server.send_signal(signal.SIGINT)
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
        matches = re.findall(r'accesses=(\d+) faults=(\d+) swap-in=(\d+) swap-out=(\d+)', log.read_text())
        if not matches:
            raise RuntimeError(f'Sem estatísticas: {log}')
        rows.append([scenario, algo, *matches[-1]])
with (out / 'comparacao.csv').open('w', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['cenario', 'algoritmo', 'acessos', 'faltas', 'swap_in', 'swap_out'])
    writer.writerows(rows)
for row in rows:
    print(*row, sep='\t')
