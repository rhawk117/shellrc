#!/usr/bin/env python3

import argparse
import hashlib
import logging
import os
import shutil
import sys
from collections.abc import Iterator
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import ClassVar, Self
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

SCRIPT_DIRECTORY = Path(__file__).resolve().parent
USER_HOME = Path.home()

LOG = logging.getLogger('shellrc-installer')

SOURCE_BLOCK_OPEN = '# >>> shellrc >>>'
SOURCE_BLOCK_CLOSE = '# <<< shellrc <<<'


class MaxLevelFilter(logging.Filter):
    def __init__(self, max_level: int) -> None:
        super().__init__()
        self.max_level = max_level

    def filter(self, record: logging.LogRecord) -> bool:
        return record.levelno <= self.max_level


def configure_logging(verbose: bool = False) -> None:
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setLevel(logging.DEBUG)
    stdout_handler.addFilter(MaxLevelFilter(logging.INFO))

    stderr_handler = logging.StreamHandler(sys.stderr)
    stderr_handler.setLevel(logging.WARNING)

    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format='[%(levelname)s] %(message)s',
        handlers=[stdout_handler, stderr_handler],
        force=True,
    )


def file_sha256(path: Path) -> str:
    """
    Hash the exact bytes of a file.

    For zip files, this answers:
        "Are these two zip files byte-for-byte identical?"
    """
    hasher = hashlib.sha256()

    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            hasher.update(chunk)

    return hasher.hexdigest()


def zip_content_hash(zip_path: Path, *, ignore: set[str] | None = None) -> str:
    """
    Hash zip contents independent of zip container metadata.

    This answers:
        "Do these zips contain the same file names with the same file contents?"

    It ignores timestamps, compression differences, ordering, comments, etc.
    """
    ignored = ignore or set()
    hasher = hashlib.sha256()

    with ZipFile(zip_path, 'r') as zf:
        names = sorted(
            name
            for name in zf.namelist()
            if not name.endswith('/') and name not in ignored
        )

        for name in names:
            hasher.update(name.encode('utf-8'))
            hasher.update(b'\0')
            hasher.update(zf.read(name))
            hasher.update(b'\0')

    return hasher.hexdigest()


def zip_contents_equal(left: Path, right: Path) -> bool:
    return zip_content_hash(left) == zip_content_hash(right)


class ShellrcPath:
    LIBRARY_DIRNAME: ClassVar[str] = '.shellrc.d'
    FILE_NAME: ClassVar[str] = '.shellrc.sh'

    def __init__(self, parent_dir: Path) -> None:
        self.parent_dir = parent_dir
        self.shellrc_dir = parent_dir / self.LIBRARY_DIRNAME
        self.shellrc_file = parent_dir / self.FILE_NAME

    def any_exist(self) -> bool:
        return self.shellrc_file.exists() or self.shellrc_dir.exists()

    def all_exist(self) -> bool:
        return self.shellrc_file.exists() and self.shellrc_dir.exists()

    def must_exist(self) -> None:
        if not self.shellrc_file.is_file():
            LOG.error('expected shellrc entrypoint to be a file: %s', self.shellrc_file)
            raise SystemExit(1)

        if not self.shellrc_dir.is_dir():
            LOG.error('expected shellrc library to be a directory: %s', self.shellrc_dir)
            raise SystemExit(1)

    def iter_files(self) -> Iterator[Path]:
        if self.shellrc_file.is_file():
            yield self.shellrc_file

        if self.shellrc_dir.is_dir():
            yield from (path for path in self.shellrc_dir.rglob('*') if path.is_file())

    def iter_backup_members(self) -> Iterator[tuple[str, bytes]]:
        for path in sorted(self.iter_files()):
            rel = path.relative_to(self.parent_dir).as_posix()
            yield rel, path.read_bytes()

    def compute_hash(self) -> str:
        """
        Hash the logical shellrc payload.

        This is better than hashing a zip because it ignores zip metadata.
        """
        hasher = hashlib.sha256()

        for rel, data in self.iter_backup_members():
            hasher.update(rel.encode('utf-8'))
            hasher.update(b'\0')
            hasher.update(data)
            hasher.update(b'\0')

        return hasher.hexdigest()

    def copy_to(self, dest_dir: Path) -> None:
        dest_dir.mkdir(parents=True, exist_ok=True)

        if self.shellrc_file.exists():
            shutil.copy2(self.shellrc_file, dest_dir / self.shellrc_file.name)

        if self.shellrc_dir.exists():
            shutil.copytree(
                self.shellrc_dir,
                dest_dir / self.shellrc_dir.name,
                symlinks=True,
                dirs_exist_ok=True,
            )


class ShellrcBackupManager:
    BACKUP_DIRNAME: ClassVar[str] = '.shellrc.bak.d'
    HASH_FILENAME: ClassVar[str] = '.shellrc.backup.sha256'
    ZIP_PREFIX: ClassVar[str] = 'shellrc_backup_'

    ZIP_TIMESTAMP: ClassVar[tuple[int, int, int, int, int, int]] = (
        1980,
        1,
        1,
        0,
        0,
        0,
    )

    def __init__(self, backup_dir: Path) -> None:
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    @property
    def backup_archives(self) -> Iterator[Path]:
        yield from sorted(
            path
            for path in self.backup_dir.glob(f'{self.ZIP_PREFIX}*.zip')
            if path.is_file()
        )

    def get_latest_archive(self) -> Path | None:
        backups = list(self.backup_archives)
        return backups[-1] if backups else None

    def new_backup_archive(self, now: datetime | None = None) -> Path:
        now = now or datetime.now(UTC)
        timestamp = now.strftime('%Y%m%dT%H%M%SZ')
        return self.backup_dir / f'{self.ZIP_PREFIX}{timestamp}.zip'

    def read_backup_hash(self, archive: Path) -> str | None:
        if not archive.is_file():
            return None

        with ZipFile(archive, 'r') as zf:
            try:
                return zf.read(self.HASH_FILENAME).decode('utf-8').strip()
            except KeyError:
                return None

    def latest_hash(self) -> str | None:
        latest = self.get_latest_archive()
        if latest is None:
            return None

        return self.read_backup_hash(latest)

    def should_create_backup(self, target_hash: str, *, force: bool = False) -> bool:
        if force:
            return True

        return self.latest_hash() != target_hash

    def _zip_info(self, name: str) -> ZipInfo:
        info = ZipInfo(name)
        info.date_time = self.ZIP_TIMESTAMP
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        return info

    def create(self, target: ShellrcPath, target_hash: str | None = None) -> Path:
        target_hash = target_hash or target.compute_hash()
        archive = self.new_backup_archive()

        with ZipFile(
            archive,
            mode='w',
            compression=ZIP_DEFLATED,
            compresslevel=9,
        ) as zf:
            zf.writestr(
                self._zip_info(self.HASH_FILENAME),
                f'{target_hash}\n',
            )

            for rel, data in target.iter_backup_members():
                zf.writestr(self._zip_info(rel), data)

        LOG.info('created backup: %s', archive)
        return archive


@dataclass(slots=True, frozen=True, kw_only=True)
class CLIArguments:
    backup_path: Path
    no_backup: bool
    force_backup: bool
    no_source: bool
    verbose: bool

    @classmethod
    def from_parser(cls, parser: argparse.ArgumentParser) -> Self:
        ns = parser.parse_args()
        return cls(
            backup_path=ns.backup_path,
            no_backup=ns.no_backup,
            force_backup=ns.force_backup,
            no_source=ns.no_source,
            verbose=ns.verbose,
        )


@dataclass(slots=True)
class UserRCFile:
    user_shell: str
    dotfile: Path
    _content: str | None = field(init=False, default=None)

    def __post_init__(self) -> None:
        self.dotfile.parent.mkdir(parents=True, exist_ok=True)

    @property
    def parent_dir(self) -> Path:
        return self.dotfile.parent

    def readlines(self) -> list[str]:
        if not self.dotfile.exists():
            return []

        return self.dotfile.read_text(encoding='utf-8').splitlines()

    @classmethod
    def auto(cls) -> Self:
        user_shell = Path(os.getenv('SHELL', 'bash')).name
        home = Path.home()

        if 'zsh' not in user_shell:
            return cls(
                user_shell=user_shell,
                dotfile=home / '.bashrc',
            )

        zdotdir = os.getenv('ZDOTDIR')
        base = Path(zdotdir) if zdotdir else home

        return cls(
            user_shell=user_shell,
            dotfile=base / '.zshrc',
        )

    def append_lines(self, *lines: str) -> None:
        text = '\n'.join(lines)

        if not text.endswith('\n'):
            text += '\n'

        with self.dotfile.open('a', encoding='utf-8') as file:
            file.write(text)


def edit_user_rc_file(
    args: CLIArguments,
    rc_file: UserRCFile,
    *,
    open_delim: str = SOURCE_BLOCK_OPEN,
    close_delim: str = SOURCE_BLOCK_CLOSE,
) -> bool:
    rc_lines = set(rc_file.readlines())

    if args.no_source:
        LOG.info('skipping rc file modification because --no-source was set')
        return False

    if open_delim in rc_lines or close_delim in rc_lines:
        LOG.info('the existing rc file was not modified: %s', rc_file.dotfile)
        return False

    entry = f'$HOME/{ShellrcPath.FILE_NAME}'

    rc_file.append_lines(
        '',
        '# -- added by shellrc --',
        open_delim,
        f'[ -f "{entry}" ] && source "{entry}"',
        close_delim,
        '# -- added by shellrc --',
    )

    LOG.info('added shellrc source block to: %s', rc_file.dotfile)
    return True


def installer(args: CLIArguments, user_rc: UserRCFile) -> bool:
    source_shellrc = ShellrcPath(SCRIPT_DIRECTORY)
    source_shellrc.must_exist()

    existing_shellrc = ShellrcPath(user_rc.parent_dir)

    if existing_shellrc.any_exist() and not args.no_backup:
        backup_manager = ShellrcBackupManager(args.backup_path)
        existing_hash = existing_shellrc.compute_hash()

        if backup_manager.should_create_backup(
            existing_hash,
            force=args.force_backup,
        ):
            backup_manager.create(existing_shellrc, existing_hash)
        else:
            LOG.info('backup skipped because latest backup already matches current files')

    LOG.info('installing shellrc into: %s', user_rc.parent_dir)
    source_shellrc.copy_to(user_rc.parent_dir)

    return edit_user_rc_file(
        args=args,
        rc_file=user_rc,
    )


def create_cli_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog='shellrc-installer',
        description='Installer / synchronization script for shellrc',
    )

    backup_group = parser.add_argument_group(
        'backup options',
        'configuring backup behavior',
    )

    backup_group.add_argument(
        '-b',
        '--backup-path',
        type=Path,
        dest='backup_path',
        help='where backups live',
        default=USER_HOME / ShellrcBackupManager.BACKUP_DIRNAME,
    )

    backup_group.add_argument(
        '--no-backup',
        dest='no_backup',
        action='store_true',
        help='do not create a backup',
    )

    backup_group.add_argument(
        '--force-backup',
        dest='force_backup',
        action='store_true',
        help='create a backup even if it is identical to the most recent one',
    )

    parser.add_argument(
        '--no-source',
        dest='no_source',
        action='store_true',
        help='do not edit the rc file to source the entrypoint',
    )

    parser.add_argument(
        '-v',
        '--verbose',
        dest='verbose',
        action='store_true',
        help='enable debug logging',
    )

    return parser


def run_tool() -> int:
    try:
        parser = create_cli_parser()
        arguments = CLIArguments.from_parser(parser)

        configure_logging(arguments.verbose)

        user_rc = UserRCFile.auto()

        LOG.info('targeting %s rc file: %s', user_rc.user_shell, user_rc.dotfile)

        rc_file_changed = installer(arguments, user_rc)

        if rc_file_changed:
            LOG.info('entrypoint added to: %s', user_rc.dotfile)
        else:
            LOG.info('existing rc file was not modified: %s', user_rc.dotfile)

        LOG.info('installation complete, reload your terminal')
    except SystemExit:
        raise
    except Exception:
        LOG.exception('installation failed')
        return 1

    return 0


def main() -> int:
    user_cwd = Path.cwd()
    try:
        os.chdir(SCRIPT_DIRECTORY)
        return run_tool()
    finally:
        os.chdir(user_cwd)


if __name__ == '__main__':
    raise SystemExit(main())
