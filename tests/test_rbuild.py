"""Read shared ArchKit mappings without performing sync or SSH."""
import contextlib
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import yaml

SCRIPT = Path(__file__).resolve().parents[1] / 'tools/rbuild'
loader = importlib.machinery.SourceFileLoader('rbuild', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
rbuild = importlib.util.module_from_spec(spec)
loader.exec_module(rbuild)


class WorkspaceMappingTests(unittest.TestCase):
    def setUp(self):
        self.scope = tempfile.TemporaryDirectory()
        self.addCleanup(self.scope.cleanup)
        self.root = Path(self.scope.name).resolve()
        self.config = self.root / 'config.yaml'
        for guard in (patch.object(rbuild, 'CONFIG_PATH', self.config),
                      patch.object(rbuild.subprocess, 'call', side_effect=AssertionError('no remote access'))):
            guard.start()
            self.addCleanup(guard.stop)

    def write(self, profiles):
        self.config.write_text(yaml.safe_dump({'shared': {'workspace_profiles': profiles}}))

    def test_flat_inventory_selects_longest_root_and_relative_remote_cwd(self):
        nested = self.root / 'nested'
        self.write({'mappings': {
            'outer': {'local': str(self.root), 'remote': '/build/outer'},
            'inner': {'local': str(nested), 'remote': '~/build/inner', 'subdir': 'service,common'},
        }})
        with patch.object(Path, 'cwd', return_value=nested / 'service'):
            root, remote, directories = rbuild.workspace_mapping()
            self.assertEqual(root, nested)
            self.assertEqual(remote, rbuild.REMOTE_HOME + '/build/inner')
            self.assertEqual(directories, ['service', 'common'])
            self.assertEqual(rbuild.remote_cwd(), remote + '/service')

    def test_local_mapping_rejects_remote_build(self):
        for fields in ({'local': str(self.root)}, {'local': str(self.root), 'remote': ''}):
            self.write({'mappings': {'local': fields}})
            stderr = io.StringIO()
            with patch.object(Path, 'cwd', return_value=self.root), contextlib.redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    rbuild.workspace_mapping()
            self.assertEqual(raised.exception.code, 2)
            self.assertIn('local compilation', stderr.getvalue())

    def test_old_grouped_config_is_rejected(self):
        self.write({'default': {'mappings': {'demo': {'local': str(self.root), 'remote': '/remote'}}}})
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            rbuild.workspace_mapping()


if __name__ == '__main__':
    unittest.main()
