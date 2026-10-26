#!/bin/bash
# Refresh this project's local development database from Render.
# Requirements: authenticated Render CLI, Python 3, Ruby/Bundler and PostgreSQL clients.
# Render database Networking must allow your current public IP (/32).
# Usage: ./refresh_local_db.sh [--check | --dump-only]
# --check makes no database changes. Default refresh saves a local recovery dump
# in tmp/db-refresh before replacing ONLY this project's development database.
# Optional: PG_BIN=/path/to/postgres/bin; LOCAL_DATABASE_URL must point to
# localhost/127.0.0.1/::1 and the project's normal development database.
# Production credentials are fetched at runtime and never printed or saved.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
command -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }
exec python3 - "foxconnect" "dpg-dbd6mgnb9u1s73dhut40-a" "srv-dbd6mtnb9u1s73di0kkg" "foxconnect_development" "$@" <<'PYTHON'
import argparse
import datetime
import fcntl
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

# The shell wrapper supplies this repository's non-secret Render resource IDs.
project, postgres_id, service_id, database_name = sys.argv[1:5]
sys.argv = [sys.argv[0]] + sys.argv[5:]
parser = argparse.ArgumentParser(description=f'Refresh {database_name} from the production database configured on Render.')
parser.add_argument('--check', action='store_true', help='Check access, PostgreSQL versions and local dependencies without changing data')
parser.add_argument('--dump-only', action='store_true', help='Download and validate latest.dump without changing the local database')
args = parser.parse_args()
if args.check and args.dump_only:
    parser.error('Choose either --check or --dump-only')
os.umask(0o077)
root = Path.cwd()
# Respect the checked-in Ruby version even from a non-interactive shell.
bundle = ['rbenv', 'exec', 'bundle'] if shutil.which('rbenv') and (root / '.ruby-version').exists() else ['bundle']

def fail(message):
    raise RuntimeError(message)

def run(command, env=None, capture=True):
    result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None)
    if result.returncode:
        # Commands never receive production credentials as arguments. Avoid printing
        # remote responses, which can contain credentials or production row values.
        fail(f'{Path(command[0]).name} failed (exit {result.returncode}). Check authentication, connectivity and tool compatibility.')
    return result.stdout.strip() if capture else ''

# Do not inherit libpq service files, alternate hosts, or a production DATABASE_URL.
clean_env = {k: v for k, v in os.environ.items() if not k.startswith('PG') and k != 'DATABASE_URL'}
clean_env.update({'PGCONNECT_TIMEOUT': '15', 'PGPASSFILE': '/dev/null', 'PGSERVICEFILE': '/dev/null'})

def connection(url, local=False):
    u = urllib.parse.urlsplit(url)
    if u.scheme not in ('postgres', 'postgresql') or not u.hostname or not u.path.strip('/'):
        fail('Expected a complete PostgreSQL connection URL')
    if local and (u.hostname not in ('localhost', '127.0.0.1', '::1') or urllib.parse.unquote(u.path[1:]) != database_name):
        fail(f'LOCAL_DATABASE_URL must use a loopback host and database {database_name}')
    if u.query or u.fragment:
        # Disallow host/service overrides hidden in a URL query. TLS is enforced below.
        query = urllib.parse.parse_qs(u.query)
        if set(query) - {'sslmode'} or u.fragment:
            fail('Connection URL query may contain only sslmode')
    env = dict(clean_env)
    env.update({'PGHOST': u.hostname, 'PGPORT': str(u.port or 5432),
                'PGDATABASE': urllib.parse.unquote(u.path[1:]),
                'PGUSER': urllib.parse.unquote(u.username or getpass.getuser()),
                'PGPASSWORD': urllib.parse.unquote(u.password or ''),
                'PGSSLMODE': 'prefer' if local else 'require'})
    if not local:
        env['PGOPTIONS'] = '-c default_transaction_read_only=on'
    return env

def source_url():
    if not shutil.which('render'):
        fail('Install the Render CLI and run render login first')
    if postgres_id:
        data = json.loads(run(['render', 'postgres', 'get', postgres_id,
                               '--include-sensitive-connection-info', '--output', 'json']))
        return data['data']['connectionInfo']['externalConnectionString']
    # Vixen currently uses an external database. Read its live Render setting so
    # the sync follows a future database migration without retaining an old URL.
    # Let the CLI refresh an expired login before reading its cached API token.
    run(['render', 'whoami', '--output', 'json'])
    api_key = os.environ.get('RENDER_API_KEY')
    if not api_key:
        config = os.environ.get('RENDER_CLI_CONFIG_PATH')
        if not config:
            config = str(Path(os.environ.get('RENDER_CLI_CONFIG_DIR', str(Path.home() / '.render'))) / 'cli.yaml')
        api_key = run(['ruby', '-ryaml', '-e', 'print YAML.load_file(ARGV[0]).fetch("api").fetch("key")', config])
    cursor = None
    while True:
        query = {'limit': 100}
        if cursor:
            query['cursor'] = cursor
        request = urllib.request.Request('https://api.render.com/v1/services/' + service_id + '/env-vars?' + urllib.parse.urlencode(query),
                                         headers={'Authorization': 'Bearer ' + api_key})
        with urllib.request.urlopen(request, timeout=30) as response:
            entries = json.load(response)
        for entry in entries:
            var = entry.get('envVar', entry)
            if var.get('key') == 'DATABASE_URL':
                url = var['value']
                parsed = urllib.parse.urlsplit(url)
                if (parsed.hostname or '').startswith('dpg-'):
                    # Render services use private hosts; local tools need the external endpoint.
                    db_id = parsed.hostname.split('.')[0]
                    data = json.loads(run(['render', 'postgres', 'get', db_id,
                                           '--include-sensitive-connection-info', '--output', 'json']))
                    external = urllib.parse.urlsplit(data['data']['connectionInfo']['externalConnectionString'])
                    return urllib.parse.urlunsplit(external._replace(path=parsed.path))
                return url
        if len(entries) < 100 or not entries[-1].get('cursor'):
            fail('Render service has no DATABASE_URL')
        cursor = entries[-1]['cursor']

def candidates():
    if os.environ.get('PG_BIN'):
        return [Path(os.environ['PG_BIN'])]
    dirs = [Path('/Applications/Postgres.app/Contents/Versions/latest/bin')]
    for base in ('/opt/homebrew/opt', '/usr/local/opt'):
        dirs.extend(Path(base).glob('postgresql@*/bin'))
        dirs.extend(Path(base).glob('libpq*/bin'))
    if shutil.which('pg_dump'):
        dirs.append(Path(shutil.which('pg_dump')).parent)
    return dirs

def version(directory):
    if not all((directory / tool).is_file() for tool in ('pg_dump', 'pg_restore', 'psql')):
        return 0
    match = re.search(r'(\d+)(?:\.\d+)', run([str(directory / 'pg_dump'), '--version']))
    return int(match[1]) if match else 0

def sql(directory, env, statement):
    return run([str(directory / 'psql'), '-X', '-w', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-c', statement], env)

def main():
    source = connection(source_url())
    default_user = os.environ.get('DATABASE_USERNAME', 'postgres') if project == 'pfc-labels' else getpass.getuser()
    default_password = os.environ.get('DATABASE_PASSWORD', '') if project == 'pfc-labels' else ''
    host = os.environ.get('DATABASE_HOST', 'localhost') if project == 'pfc-labels' else 'localhost'
    port = os.environ.get('DATABASE_PORT', '5432') if project == 'pfc-labels' else '5432'
    local_url = os.environ.get('LOCAL_DATABASE_URL', 'postgresql://' + urllib.parse.quote(default_user, safe='') + ':' + urllib.parse.quote(default_password, safe='') + '@' + host + ':' + port + '/' + database_name)
    local = connection(local_url, local=True)
    admin = dict(local, PGDATABASE='postgres')
    available = sorted([(version(d), d) for d in candidates()], key=lambda item: item[0], reverse=True)
    available = [(v, d) for v, d in available if v]
    if not available:
        fail('Install PostgreSQL clients (Postgres.app or brew install postgresql@18), or set PG_BIN')
    probe = available[0][1]
    print(f'Checking production access for {project}...', flush=True)
    try:
        remote_major = int(sql(probe, source, 'SHOW server_version_num')) // 10000
    except RuntimeError:
        fail('Production connection failed. For Render Postgres, allow your current public IP /32 in Networking. Check Render login and database availability. No local data was changed.')
    local_major = int(sql(probe, admin, 'SHOW server_version_num')) // 10000
    compatible = [(v, d) for v, d in available if remote_major <= v <= local_major]
    if not compatible:
        fail(f'Need a pg_dump/pg_restore pair >= source PostgreSQL {remote_major} and <= local PostgreSQL {local_major}. Upgrade the local server/clients or set PG_BIN.')
    client_major, pg_bin = compatible[0]
    rails_env = dict(clean_env, DATABASE_URL=local_url, RAILS_ENV='development', RACK_ENV='development')
    if not args.dump_only:
        run(bundle + ['check'], rails_env)
    print(f'Source PostgreSQL {remote_major}; local PostgreSQL {local_major}; clients {client_major}.', flush=True)
    if args.check:
        print('Checks passed. No database changes made.')
        return
    # Store downloads privately in tmp (ignored by Rails repositories), then replace
    # latest.dump only after the entire archive has been downloaded and validated.
    backup_dir = root / 'tmp' / 'db-refresh'
    backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (backup_dir / 'refresh.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            fail('Another database refresh is already running for this project')
        with tempfile.TemporaryDirectory(prefix='download-', dir=backup_dir) as scratch:
            dump = Path(scratch) / 'production.dump'
            print('Downloading production database (read-only)...', flush=True)
            run([str(pg_bin / 'pg_dump'), '-w', '--format=custom', '--no-owner', '--no-acl', '--file', str(dump)], source)
            run([str(pg_bin / 'pg_restore'), '--list', str(dump)])
            # Atomic replacement preserves the previous good dump on download failure.
            os.replace(dump, root / 'latest.dump')
        if args.dump_only:
            print('Validated latest.dump. Local database unchanged.')
            return
        exists = sql(pg_bin, admin, "SELECT 1 FROM pg_database WHERE datname = '" + database_name + "'") == '1'
        if exists:
            backup = backup_dir / ('local-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.dump')
            print('Backing up the existing local database...', flush=True)
            run([str(pg_bin / 'pg_dump'), '-w', '--format=custom', '--no-owner', '--no-acl', '--file', str(backup)], local)
            run([str(pg_bin / 'pg_restore'), '--list', str(backup)])
            print('Local recovery backup: ' + str(backup), flush=True)
        print(f'Replacing local database {database_name}...', flush=True)
        # Only this explicitly validated development database is dropped. Never invoke
        # Rails db:drop, which may also drop test databases or inherit production config.
        sql(pg_bin, admin, 'DROP DATABASE IF EXISTS "' + database_name + '" WITH (FORCE)')
        sql(pg_bin, admin, 'CREATE DATABASE "' + database_name + '" TEMPLATE template0')
        run([str(pg_bin / 'pg_restore'), '-w', '--exit-on-error', '--single-transaction', '--no-owner', '--no-acl',
             '--dbname', database_name, str(root / 'latest.dump')], local)
        print('Running development migrations...', flush=True)
        run(bundle + ['exec', 'rails', 'db:environment:set', 'db:migrate'], rails_env, capture=False)
        print('Database refresh complete.')

try:
    main()
except (RuntimeError, KeyError, ValueError, OSError, urllib.error.URLError) as error:
    # Never echo connection strings, API responses, or production records.
    message = str(error) if isinstance(error, RuntimeError) else type(error).__name__ + ': check Render authentication/configuration and dependencies'
    print('Refresh failed: ' + message, file=sys.stderr)
    sys.exit(1)

PYTHON
