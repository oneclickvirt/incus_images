"""Keep manual retained-image repair bounded to the requested real asset."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from repair_published_selection import select


class PublishedRepairSelectionTests(unittest.TestCase):
    def test_older_release_is_selected_without_expanding_to_current_catalog(self):
        for raw_arch, arch, runner in [('arm64', 'arm64', 'ubuntu-24.04-arm'),
                                       ('x86_64', 'amd64', 'ubuntu-24.04')]:
            name = f'openeuler_25.09_25.09_{raw_arch}_cloud.zip'
            asset = dict(name=name, tag='openeuler', state='uploaded', size=123)
            value = select([asset, dict(asset, name=name.replace('_cloud.', '_default.'))], name)
            self.assertEqual(value['include'], [dict(distro='openeuler', release='25.09', arch=arch,
                runner=runner, kind='container', image=name)])

    def test_missing_incomplete_or_wrong_release_is_rejected(self):
        name = 'openeuler_25.09_25.09_arm64_cloud.zip'
        good = dict(name=name, tag='openeuler', state='uploaded', size=123)
        for assets in [[], [dict(good, size=0)], [dict(good, state='new')],
                       [dict(good, tag='processed')], [good, good]]:
            with self.subTest(assets=assets), self.assertRaises(ValueError):
                select(assets, name)
        with self.assertRaises(ValueError):
            select([good], name, architecture='amd64')
        with self.assertRaises(ValueError):
            select([good], name, distro='debian')

    def test_paths_vm_archives_and_shell_syntax_are_rejected(self):
        for name in ['../openeuler_25.09_25.09_arm64_cloud.zip',
                     'openeuler_25.09_25.09_arm64_cloud_kvm.zip',
                     'openeuler_25.09_25.09_arm64_cloud.zip;id', '$(id).zip']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                select([], name)


if __name__ == '__main__':
    unittest.main()
