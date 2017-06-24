# apfs.ksy
APFS filesystem format for Kaitai Struct (http://kaitai.io/)

Blog post about the APFS format: https://blog.cugu.eu/post/apfs/

The Kaitai WebIDE to examine APFS filesystems and to continue reverse engineering APFS: https://ide.kaitai.io/

Offical Apple Documentation an APFS: https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/APFS_Guide/Introduction/Introduction.html

## Images

Name | Description | OS
:--- | :---------- | :---
test1.dd | New filesystem, one APFS volume, no files or folders. | macOS Sierra 10.12.3 (16D32)
test3_head.dd | Non empty part of an 1GB image. Three volumes and a couple of files and folders. | macOS Sierra 10.12.3 (16D32)

## Contributing
Pull requests and issues are welcome!

## Further Tools

### iBored

The free disk editor [iBored](http://apps.tempel.org/iBored) adds support for APFS volumes in version 1.2. While it does currently not read this ksy file for its templates feature, its templates.xml file is modeled (manually) after this kdy file.

Get the latest beta (1.2b6 or higher) from here: http://files.tempel.org/iBored – note that these beta versions may contain support only for APFS, whereas the official (older) release supports many other formats (FAT, HFS etc.).
