# apfs.ksy

![stability-experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
[![CircleCI](https://circleci.com/gh/cugu/apfs.ksy.svg?style=shield&circle-token=15c0e9d1824e893ef4ac06a35aa3fef6f5fd4d97)](https://circleci.com/gh/cugu/apfs.ksy)

APFS filesystem format for Kaitai Struct (http://kaitai.io/)

Blog post about the APFS format: https://blog.cugu.eu/post/apfs/

The Kaitai WebIDE to examine APFS filesystems and to continue reverse engineering APFS: https://ide.kaitai.io/
Add the following snippet after the meta section to the ksy file to parse all blocks

    seq:
     - id: blocks
       type: block
       size: block_size
       repeat: until
       repeat-until: _io.size - _io.pos < block_size

Offical Apple Documentation an APFS: https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html

## Contributing
Pull requests and issues are welcome!

## Further Tools

### iBored

The free disk editor [iBored](http://apps.tempel.org/iBored) adds support for APFS volumes in version 1.2. While it does currently not read this ksy file for its templates feature, its templates.xml file is modeled (manually) after this ksy file.

Get the latest beta (1.2b6 or higher) from here: http://files.tempel.org/iBored – note that these beta versions may contain support only for APFS, whereas the official (older) release supports many other formats (FAT, HFS etc.).

To use iBored, drop a disk image file such as the provided .dd files into its window, or type shift+cmd+R to relaunch iBored with root permissions so that you can see the volumes of installed disks. Then double click it to see the first block in structured layout.
