# [apfs.ksy](https://github.com/cugu/apfs.ksy/blob/master/apfs.ksy)

![stability-experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
[![CircleCI](https://circleci.com/gh/cugu/apfs.ksy.svg?style=shield&circle-token=15c0e9d1824e893ef4ac06a35aa3fef6f5fd4d97)](https://circleci.com/gh/cugu/apfs.ksy)

APFS filesystem format for Kaitai Struct (http://kaitai.io/)

## Usage

Use the Kaitai WebIDE to examine APFS filesystems and to continue reverse engineering APFS: https://ide.kaitai.io/devel/ (the development version currently supports some nice additional features). A brief explanation of how the Web IDE works:
https://github.com/kaitai-io/kaitai_struct_webide/wiki/Features 

## Documentation

Information about the checksum calculation can be found in [checksum.md](checksum.md).

## More documentation on APFS

 - [**Decoding the APFS file system**](http://www.sciencedirect.com/science/article/pii/S1742287617301408): Paper by Kurt H.Hansen and Fergus Toolan Fergus in _Digital Investigation_. Published: 2017-09-22.
- [**Apple File System Guide**](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html): Official documentation on APFS. Lacks lots of information on APFS. Last update: 2017-09-21.
 - [**APFS filesystem format**](https://blog.cugu.eu/post/apfs/): Deprecated blog post by myself. Still contains some useful diagrams. Last update: 2017-04-30.

## Tools with APFS support

 - [**iBored**](http://files.tempel.org/iBored) by [Thomas Tempelmann](https://github.com/tempelmann): Free hex editor with support for APFS volumes starting in version 1.2 (Note that these beta versions may contain support only for APFS, whereas the official (older) release supports many other formats like FAT, HFS etc.. While it does currently not read this ksy file for its templates feature, its templates.xml file is modeled (manually) after this ksy file.
 - [**Find Any File**](http://apps.tempel.org/FindAnyFile/) by [Thomas Tempelmann](https://github.com/tempelmann): Fast search for filenames on a disk.

## Contributing
Pull requests and issues are welcome!
