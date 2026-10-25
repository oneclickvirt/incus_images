#!/usr/bin/env python3
"""Select one real retained container archive for the existing repair pipeline."""
import json
import os
import re
from published_image_suite import published
from release_assets import Publisher


NAME = re.compile(r'^([A-Za-z0-9]+)_[A-Za-z0-9.-]+_([A-Za-z0-9.-]+)_'
                  r'(amd64|x86_64|arm64|aarch64)_(default|cloud|openrc|systemd)\.zip$')


def select(assets, image, distro='all', architecture='all'):
    match = NAME.fullmatch(image)
    if not match:
        raise ValueError('Expected one exact published container ZIP filename')
    name, release, raw_arch, _ = match.groups()
    arch = {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(raw_arch, raw_arch)
    if distro not in ('all', name) or architecture not in ('all', arch):
        raise ValueError('Published image does not match the requested distribution or architecture')
    matches = [asset for asset in assets if asset['name'] == image]
    if (len(matches) != 1 or matches[0].get('tag') != name
            or matches[0].get('state') != 'uploaded' or not matches[0].get('size')):
        raise ValueError('Expected complete published image in its distribution release')
    return {'include': [{'distro': name, 'release': release, 'arch': arch, 'kind': 'container',
                         'runner': 'ubuntu-24.04-arm' if arch == 'arm64' else 'ubuntu-24.04',
                         'image': image}]}


def main():
    publisher = Publisher(os.environ['GITHUB_REPOSITORY'], os.environ['GH_TOKEN'])
    matrix = select(published(publisher), os.environ['IMAGE'], os.environ['DISTRO'], os.environ['ARCH'])
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        print('matrix=' + json.dumps(matrix, separators=(',', ':')), file=output)
        print('count=1', file=output)
    print('Selected published archive for validated SSH identity repair:', os.environ['IMAGE'])


if __name__ == '__main__':
    main()
