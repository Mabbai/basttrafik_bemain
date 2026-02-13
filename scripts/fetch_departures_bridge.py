#!/usr/bin/env python3
import importlib.util
import inspect
import json
import pathlib
import sys
from typing import Callable, List


def _load_fetch_departures(src_dir: pathlib.Path) -> Callable[[str], List[dict]]:
    if not src_dir.exists():
        raise RuntimeError(f'Submodule source directory not found: {src_dir}')

    for path in sorted(src_dir.glob('*.py')):
        if path.name.startswith('_') or path.name == pathlib.Path(__file__).name:
            continue

        spec = importlib.util.spec_from_file_location(path.stem, path)
        if spec is None or spec.loader is None:
            continue

        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        func = getattr(module, 'fetch_departures', None)
        if func is not None and callable(func):
            return func

    raise RuntimeError('Could not locate a callable fetch_departures(stop_name) in basttrafik/src/*.py')


def _to_json_safe(value):
    if isinstance(value, dict):
        return {str(k): _to_json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_to_json_safe(v) for v in value]
    if hasattr(value, 'isoformat') and inspect.ismethod(value.isoformat):
        return value.isoformat()
    return value


def main() -> int:
    if len(sys.argv) != 2:
        print('Usage: fetch_departures_bridge.py <stop_name>', file=sys.stderr)
        return 2

    stop_name = sys.argv[1]
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    src_dir = repo_root / 'basttrafik' / 'src'

    fetch_departures = _load_fetch_departures(src_dir)
    result = fetch_departures(stop_name)

    print(json.dumps(_to_json_safe(result), ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
