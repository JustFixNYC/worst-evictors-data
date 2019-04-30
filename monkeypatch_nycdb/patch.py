from typing import Iterable
from pathlib import Path
from importlib.util import find_spec


MY_DIR = Path(__file__).parent.resolve()

NYCDB_SPEC = find_spec('nycdb')

assert NYCDB_SPEC is not None

NYCDB_ORIGIN = NYCDB_SPEC.origin

assert NYCDB_ORIGIN is not None

NYCDB_ROOT_DIR = Path(NYCDB_ORIGIN).parent.resolve()


def copy_files(src_paths: Iterable[Path], dest_path: Path):
    for path in src_paths:
        target = dest_path / path.name
        target.write_text(path.read_text())


def monkeypatch():
    dataset_ymls = list((MY_DIR / 'datasets').glob('*.yml'))
    dataset_names = [path.stem for path in dataset_ymls]

    copy_files(dataset_ymls, NYCDB_ROOT_DIR / 'datasets')
    copy_files((MY_DIR / 'sql').glob('*.sql'), NYCDB_ROOT_DIR / 'sql')

    from . import new_dataset_transformations
    from nycdb import dataset_transformations

    for name in dataset_names:
        transform_func = getattr(new_dataset_transformations, name)
        setattr(dataset_transformations, name, transform_func)


if __name__ == '__main__':
    monkeypatch()
