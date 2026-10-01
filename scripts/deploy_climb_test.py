#!/usr/bin/env python3
"""Validate and manually deploy the Flutter web app to climb_test."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as element_tree


SFTP_HOST = 'ftp.cluster027.hosting.ovh.net'
SFTP_REMOTE_DIRECTORY = '/home/cruxclubxi/cruxclub.fr/climb_test'
PUBLIC_STAGING_URL = 'https://cruxclub.fr/climb_test/'
REQUIRED_BASE_HREF = '<base href="/climb_test/">'


def run(command: list[str], *, cwd: Path | None = None) -> None:
  subprocess.run(command, cwd=cwd, check=True)


def saved_sftp_username() -> str:
  recent_servers = Path.home() / '.config/filezilla/recentservers.xml'
  if not recent_servers.is_file():
    raise RuntimeError('FileZilla recent-server configuration is unavailable.')

  root = element_tree.parse(recent_servers).getroot()
  for server in root.findall('.//Server'):
    fields = {child.tag: child.text or '' for child in server}
    if fields.get('Host') != SFTP_HOST:
      continue

    username = fields.get('User', '')
    if username and not any(character.isspace() for character in username):
      return username
    break

  raise RuntimeError('No usable FileZilla username is saved for the SFTP host.')


def keyring_password() -> str:
  result = subprocess.run(
      ['secret-tool', 'lookup', 'host', SFTP_HOST],
      check=False,
      capture_output=True,
      text=True,
  )
  password = result.stdout.rstrip('\n')
  if result.returncode != 0 or not password:
    raise RuntimeError('No SFTP password is available from the system keyring.')
  return password


def main() -> int:
  repository = Path(__file__).resolve().parents[1]
  frontend = repository / 'frontend'
  build = frontend / 'build/web'
  known_hosts = Path.home() / '.ssh/known_hosts'

  if not known_hosts.is_file():
    raise RuntimeError('Missing ~/.ssh/known_hosts for strict host verification.')

  run(['flutter', 'analyze', '--no-fatal-warnings', '--no-fatal-infos'], cwd=frontend)
  run(['flutter', 'test'], cwd=frontend)
  run(
      ['flutter', 'build', 'web', '--release', '--base-href', '/climb_test/'],
      cwd=frontend,
  )

  index = build / 'index.html'
  if not index.is_file() or REQUIRED_BASE_HREF not in index.read_text():
    raise RuntimeError('The staging build does not contain the required base path.')

  username = saved_sftp_username()
  password = keyring_password()
  with tempfile.NamedTemporaryFile(
      mode='w',
      prefix='topo-sftp-',
      delete=False,
  ) as netrc:
    netrc.write(f'machine {SFTP_HOST} login {username} password {password}\n')
    netrc_path = Path(netrc.name)
  os.chmod(netrc_path, 0o600)

  curl_base = [
      'curl',
      '--fail',
      '--silent',
      '--show-error',
      '--proto',
      '=sftp',
      '--knownhosts',
      str(known_hosts),
      '--netrc-file',
      str(netrc_path),
  ]
  try:
    files = sorted(path for path in build.rglob('*') if path.is_file())
    for local_path in files:
      relative_path = local_path.relative_to(build).as_posix()
      remote_url = f'sftp://{SFTP_HOST}:22{SFTP_REMOTE_DIRECTORY}/{relative_path}'
      run([
          *curl_base,
          '--ftp-create-dirs',
          '--upload-file',
          str(local_path),
          remote_url,
      ])

    deployed_index = subprocess.run(
        [*curl_base, f'sftp://{SFTP_HOST}:22{SFTP_REMOTE_DIRECTORY}/index.html'],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
  finally:
    netrc_path.unlink(missing_ok=True)

  if REQUIRED_BASE_HREF not in deployed_index:
    raise RuntimeError('The deployed index.html does not contain the staging base path.')

  public_index = subprocess.run(
      [
          'curl',
          '--fail',
          '--silent',
          '--show-error',
          '--location',
          '--max-time',
          '30',
          PUBLIC_STAGING_URL,
      ],
      check=True,
      capture_output=True,
      text=True,
  ).stdout
  if REQUIRED_BASE_HREF not in public_index:
    raise RuntimeError('The public staging endpoint does not serve the deployed build.')

  print(f'Deployed {len(files)} files to climb_test and verified the public endpoint.')
  return 0


if __name__ == '__main__':
  try:
    raise SystemExit(main())
  except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
    print(f'Deployment failed: {error}', file=sys.stderr)
    raise SystemExit(1)
