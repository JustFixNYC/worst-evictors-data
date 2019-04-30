import os
import sys
import subprocess
import argparse
import time
import yaml
from urllib.parse import urlparse
from typing import NamedTuple, Any, Tuple, Optional, Dict, List
from pathlib import Path
from types import SimpleNamespace
import psycopg2

import monkeypatch_nycdb.patch
monkeypatch_nycdb.patch.monkeypatch()

import nycdb.dataset
from nycdb.utility import list_wrap


DEFAULT_DATABASE_URL = 'postgres://nycdb:nycdb@localhost/nycdb'

ROOT_DIR = Path(__file__).parent.resolve()

DATA_DIR = ROOT_DIR / 'data'

SQL_DIR = ROOT_DIR / 'sql'

SQLFILE_PATHS = [
    SQL_DIR / 'worst-evictors.sql'
]

NYCDB_DATASET_DEPENDENCIES = [
    'pluto_18v1',
    'rentstab_summary',
    # These are custom datasets we monkeypatched in.
    'marshal_evictions_18',
    'hpd_head_officers',
    'eviction_filings_1315'
]


# Just an alias for our database connection.
DbConnection = Any


class DbContext(NamedTuple):
    host: str
    database: str
    user: str
    password: str
    port: int

    @staticmethod
    def from_url(url: str) -> 'DbContext':
        parsed = urlparse(url)
        if parsed.scheme != 'postgres':
            raise ValueError('Database URL schema must be postgres')
        if parsed.username is None:
            raise ValueError('Database URL must have a username')
        if parsed.password is None:
            # We might support password-less logins someday, but
            # not right now.
            raise ValueError('Database URL must have a password')
        if parsed.hostname is None:
            raise ValueError('Database URL must have a hostname')
        database = parsed.path[1:]
        if not database:
            raise ValueError('Database URL must have a database name')
        port = parsed.port or 5432
        return DbContext(
            host=parsed.hostname,
            database=database,
            user=parsed.username,
            password=parsed.password,
            port=port
        )

    def psycopg2_connect_kwargs(self) -> Dict[str, Any]:
        return dict(
            user=self.user,
            password=self.password,
            host=self.host,
            database=self.database,
            port=self.port
        )

    def connection(self) -> DbConnection:
        tries_left = 5
        secs_between_tries = 2

        connect = lambda: psycopg2.connect(**self.psycopg2_connect_kwargs())

        while tries_left > 1:
            try:
                return connect()
            except psycopg2.OperationalError as e:
                print("Failed to connect to db, retrying...")
                time.sleep(secs_between_tries)
                tries_left -= 1
        return connect()

    def get_pg_env_and_args(self) -> Tuple[Dict[str, str], List[str]]:
        '''
        Return an environment dictionary and command-line arguments that
        can be passed to Postgres command-line tools (e.g. psql, pg_dump) to
        connect to the database.
        '''

        env = os.environ.copy()
        env['PGPASSWORD'] = self.password
        args = [
            '-h', self.host, '-p', str(self.port), '-U', self.user, '-d', self.database
        ]
        return (env, args)


class NycDbBuilder:
    db: DbContext
    conn: DbConnection
    data_dir: Path

    def __init__(self, db: DbContext) -> None:
        self.db = db
        self.data_dir = DATA_DIR
        self.conn = db.connection()
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def get_nycdb_dataset(self, name: str) -> nycdb.Dataset:
        db = self.db
        args = SimpleNamespace(
            user=db.user,
            password=db.password,
            host=db.host,
            database=db.database,
            port=str(db.port),
            root_dir=self.data_dir
        )
        return nycdb.Dataset(name, args=args)

    def call_nycdb(self, *args: str) -> None:
        db = self.db
        subprocess.check_call(
            ['nycdb', *args, '-H', db.host, '-U', db.user, '-P', db.password,
             '-D', db.database, '--port', str(db.port),
             '--root-dir', str(self.data_dir)]
        )

    def do_tables_exist(self, *names: str) -> bool:
        with self.conn:
            for name in names:
                with self.conn.cursor() as cursor:
                    cursor.execute(f"SELECT to_regclass('public.{name}')")
                    if cursor.fetchone()[0] is None:
                        return False
        return True

    def drop_tables(self, *names: str) -> None:
        with self.conn:
            for name in names:
                with self.conn.cursor() as cursor:
                    cursor.execute(f"DROP TABLE IF EXISTS {name}")

    def delete_downloaded_data(self, *tables: str) -> None:
        for tablename in tables:
            csv_file = self.data_dir / f"{tablename}.csv"
            if csv_file.exists():
                print(f"Removing {csv_file.name} so it can be re-downloaded.")
                csv_file.unlink()

    def ensure_dataset(self, name: str, force_refresh: bool=False) -> None:
        dataset = nycdb.dataset.datasets()[name]
        tables: List[str] = [
            schema['table_name']
            for schema in list_wrap(dataset['schema'])
        ]
        tables_str = 'table' if len(tables) == 1 else 'tables'
        print(f"Ensuring NYCDB dataset '{name}' is loaded with {len(tables)} {tables_str}...")

        if force_refresh:
            self.drop_tables(*tables)
            self.delete_downloaded_data(*tables)
        if not self.do_tables_exist(*tables):
            print(f"Table {name} not found in the database. Downloading...")
            self.get_nycdb_dataset(name).download_files()
            print(f"Loading {name} into the database...")
            self.get_nycdb_dataset(name).db_import()
        else:
            print(f"Table {name} already exists.")

    def run_sql_file(self, sqlpath: Path) -> None:
        sql = sqlpath.read_text()
        with self.conn:
            with self.conn.cursor() as cursor:
                cursor.execute(sql)

    def build(self, force_refresh: bool) -> None:
        print("Loading the database with real data (this could take a while).")

        for dataset in NYCDB_DATASET_DEPENDENCIES:
            self.ensure_dataset(dataset, force_refresh=force_refresh)

        for sqlpath in SQLFILE_PATHS:
            print(f"Running {sqlpath.name}...")
            # TODO: Uncomment this.
            self.run_sql_file(sqlpath)


def dbshell(db: DbContext):
    env, args = db.get_pg_env_and_args()
    retval = subprocess.call(['psql', *args], env=env)
    sys.exit(retval)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    parser.add_argument(
        '-u', '--database-url',
        help=(
            f'Set database URL. Defaults to {DEFAULT_DATABASE_URL} and '
            f'can be overridden via the DATABASE_URL environment variable.'
        ),
        default=os.environ.get('DATABASE_URL', DEFAULT_DATABASE_URL)
    )

    parser_builddb = subparsers.add_parser('builddb')
    parser_builddb.set_defaults(cmd='builddb')

    parser_dbshell = subparsers.add_parser('dbshell')
    parser_dbshell.set_defaults(cmd='dbshell')

    args = parser.parse_args()

    database_url: str = args.database_url

    db = DbContext.from_url(args.database_url)

    cmd = getattr(args, 'cmd', '')

    if cmd == 'dbshell':
        dbshell(db)
    elif cmd == 'builddb':
        NycDbBuilder(db).build(force_refresh=False)
    else:
        parser.print_help()
        sys.exit(1)
