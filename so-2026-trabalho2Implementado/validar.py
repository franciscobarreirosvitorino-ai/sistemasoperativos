"""Verifica testes C e erros de argumentos; executar depois de compilar."""
import pathlib
import subprocess

logs = []
for args, expected in [
    (['./build/test_vm'], 0),
    (['./build/ossim', '--vm', 'invalido'], 1),
    (['./build/ossim', '--pframes', '2', '--threshold', '3'], 1),
    (['./build/ossim', '--vm'], 1),
]:
    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
    logs.append(f'$ {" ".join(args)}\n{result.stdout}{result.stderr}exit={result.returncode}\n')
    if result.returncode != expected:
        raise RuntimeError(logs[-1])
pathlib.Path('resultados').mkdir(exist_ok=True)
pathlib.Path('resultados/validacao.txt').write_text('\n'.join(logs))
print('Testes C e argumentos inválidos: todos passaram.')
