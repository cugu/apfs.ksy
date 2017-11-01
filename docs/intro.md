_2017-04-22_
# APFS filesystem format 

I started to reverse engineer APFS and want to share what I found out so far. You can send me feedback and ideas on this post via [Twitter](https://twitter.com/intent/tweet?text=@cugu_pio%20&amp;related=cugu_pio&amp;url=https://blog.cugu.eu/post/apfs/). 

**Notice**: I created a test image with macOS Sierra 10.12.3 (16D32). All results are guesses and the reverse engineering is work in progress. Also newer versions of APFS might change structures. The information below is neither complete nor proven to be correct. 

**Update 2017-04-30**: Added a section for the checksum

**Update 2017-06-16**: Add apfs.ksy respository

## Contents

  - [Overview](#overview)
  - [General information](#general)
  - [Structures](#structures)
    - [Block header](#block_header)
      - [Checksum](#checksum)
    - [Container Superblock](#container_superblock)
    - [Node](#node)
    - [Spacemanager](#spacemanager)
    - [Allocation Info File](#allocation_info_file)
    - [Unknown](#0x11)
    - [B-Tree](#btree)
    - [Checkpoint](#checkpoint)
    - [Volume Superblock](#volume_superblock)
    - [Allocation File](#allocation_file)

## <a name="overview"></a> Overview

APFS is structured in a single container that can contain multiple APFS volumes. A container needs to be >512 MB to contain more than one volume, >1024MB to contain more than two volumes and so on. The following image shows an overview of the APFs structure.

![APFS Overview](/files/apfs_overview.png)

Each element of this structure (except for the allocation file) starts with a 32 byte **block header**, which contains some general information about the block. Afterwards the body of the structure is following. The following types exist:

- **0x01**: Container Superblock
- **0x02**: Node
- **0x05**: Spacemanager
- **0x07**: Allocation Info File
- **0x11**: *Unknown*
- **0x0B**: B-Tree
- **0x0C**: Checkpoint
- **0x0D**: Volume Superblock

Each of this structures is described in detail below. A more detailed version of the APFS structure is available as a Kaitai struct file: [apfs.ksy](https://github.com/cugu/apfs.ksy). You can use it to examine APFS dumps in the [Kaitai IDE](https://ide.kaitai.io/#) or [create parsers](http://kaitai.io/repl/) for various languages. This .ksy file must considered experimental.

## <a name="general"></a> General information:

- The filesystem uses **litte-endian** values for storing information
- Timestamps are **64bit nanoseconds** (1 / 1,000,000,000 seconds!) starting from 1.1.1970 UTC (unix epoch). The current timestamp is around `0x14b11800f375e000`.
- Standard block size seems to be 4096 byte per block.
- APFS is a **copy-on-write** filesystem so each block is copied before changes are applied so a history of all unoverwritten files and filesystem structures exists. This might result in a huge amount of forensic artefacts. 

## <a name="structures"></a> Structures

### <a name="block_header"></a> Block header

Each filesystem structure in APFS starts with a block header. This header starts with a checksum for the whole block. Other informations in the header include the copy-on-write version of the block, the block id and the block type.

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="checksum_pos">0</TD><TD PORT="checksum_size">8</TD><TD>uint64</TD><TD PORT="checksum_type">checksum</TD></TR>
        <TR><TD PORT="block_id_pos">8</TD><TD PORT="block_id_size">8</TD><TD>uint64</TD><TD PORT="block_id_type">block_id</TD></TR>
        <TR><TD PORT="version_pos">16</TD><TD PORT="version_size">8</TD><TD>uint64</TD><TD PORT="version_type">version</TD></TR>
        <TR><TD PORT="block_type_pos">24</TD><TD PORT="block_type_size">2</TD><TD>uint16</TD><TD PORT="block_type_type">block_type</TD></TR>
        <TR><TD PORT="flags_pos">26</TD><TD PORT="flags_size">2</TD><TD>uint16</TD><TD PORT="flags_type">flags</TD></TR>
        <TR><TD PORT="padding_pos">28</TD><TD PORT="padding_size">4</TD><TD>uint32</TD><TD PORT="padding_type">padding</TD></TR>
      </TABLE>

#### <a name="checksum"></a> Checksum
According to the [apple docs](https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html) the Fletcher's checksum algorithm is used. Apple uses a variant of the algorithm described in a [paper by John Kodis](http://collaboration.cmc.ec.gc.ca/science/rpn/biblio/ddj/Website/articles/DDJ/1992/9205/9205b/9205b.htm). The following algorithm shows this procedure. The input is the block without the first 8 byte.

```go
    func createChecksum(data []byte) uint64 {
        var sum1, sum2 uint64

        modValue := uint64(2<<31 - 1)

        for i := 0; i < len(data)/4; i++ {
            d := binary.LittleEndian.Uint32(data[i*4 : (i+1)*4])
            sum1 = (sum1 + uint64(d)) % modValue
            sum2 = (sum2 + sum1) % modValue
        }

        check1 := modValue - ((sum1 + sum2) % modValue)
        check2 := modValue - ((sum1 + check1) % modValue)

        return (check2 << 32) | check1
    }
```

The nice feature of the algorithm is, that when you check a block in APFS with the following algorithm you should get null as a result. Note that the input in this case is the whole block, including the checksum.

```go
    func checkChecksum(data []byte) uint64 {
        var sum1, sum2 uint64

        modValue := uint64(2<<31 - 1)

        for i := 0; i < len(data)/4; i++ {
            d := binary.LittleEndian.Uint32(data[i*4 : (i+1)*4])
            sum1 = (sum1 + uint64(d)) % modValue
            sum2 = (sum2 + sum1) % modValue
        }

        return (sum2 << 32) | sum1
    }
```

### <a name="container_superblock"></a> Container Superblock

The container superblock is the entry point to the filesystem. Because of the structure with containers and flexible volumes, allocation needs to handled on a container level. The container superblock contains information on the blocksize, the number of blocks and pointers to the spacemanager for this task. Additionally the block IDs of all volumes are stored in the superblock. To map block IDs to block offsets a pointer to a block map b-tree is stored. This b-tree contains entries for each volume with its ID and offset. 

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="magic_pos">0</TD><TD PORT="magic_size">4</TD><TD>byte</TD><TD PORT="magic_type">magic "NXSB"</TD></TR>
        <TR><TD PORT="blocksize_pos">4</TD><TD PORT="blocksize_size">4</TD><TD>uint32</TD><TD PORT="blocksize_type">blocksize</TD></TR>
        <TR><TD PORT="totalblocks_pos">8</TD><TD PORT="totalblocks_size">8</TD><TD>uint64</TD><TD PORT="totalblocks_type">totalblocks</TD></TR>
        <TR><TD PORT="guid_pos">40</TD><TD PORT="guid_size">16</TD><TD>byte</TD><TD PORT="guid_type">guid</TD></TR>
        <TR><TD PORT="next_free_block_id_pos">56</TD><TD PORT="next_free_block_id_size">8</TD><TD>uint64</TD><TD PORT="next_free_block_id_type">next_free_block_id</TD></TR>
        <TR><TD PORT="next_version_pos">64</TD><TD PORT="next_version_size">8</TD><TD>uint64</TD><TD PORT="next_version_type">next_version</TD></TR>
        <TR><TD PORT="previous_containersuperblock_block_pos">104</TD><TD PORT="previous_containersuperblock_block_size">4</TD><TD>uint32</TD><TD PORT="previous_containersuperblock_block_type">previous_containersuperblock_block</TD></TR>
        <TR><TD PORT="spaceman_id_pos">120</TD><TD PORT="spaceman_id_size">8</TD><TD>uint64</TD><TD PORT="spaceman_id_type">spaceman_id</TD></TR>
        <TR><TD PORT="block_map_block_pos">128</TD><TD PORT="block_map_block_size">8</TD><TD>uint64</TD><TD PORT="block_map_block_type">block_map_block</TD></TR>
        <TR><TD PORT="unknown_id_pos">136</TD><TD PORT="unknown_id_size">8</TD><TD>uint64</TD><TD PORT="unknown_id_type">unknown_id</TD></TR>
        <TR><TD PORT="padding2_pos">144</TD><TD PORT="padding2_size">4</TD><TD>uint32</TD><TD PORT="padding2_type">padding2</TD></TR>
        <TR><TD PORT="apfs_count_pos">148</TD><TD PORT="apfs_count_size">4</TD><TD>uint32</TD><TD PORT="apfs_count_type">apfs_count</TD></TR>
        <TR><TD PORT="offset_apfs_pos">152</TD><TD PORT="offset_apfs_size">8</TD><TD>uint64</TD><TD PORT="offset_apfs_type">offset_apfs (repeat apfs_count times)</TD></TR>
      </TABLE>

### <a name="node"></a> Node

Nodes are flexible containers that are used for storing different kinds entries. They can be part of a B-tree or exist on their own. Nodes can either contain flexible or fixed sized entries. A node starts with a list of pointers to the entry keys and entry records. This way for each entry the node contains an entry header at the beginning of the node, an entry key in the middle of the node and an entry record at the end of the node. 

![Node](/files/node.png)

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="alignment_pos">0</TD><TD PORT="alignment_size">4</TD><TD>uint32</TD><TD PORT="alignment_type">alignment</TD></TR>
        <TR><TD PORT="entry_count_pos">4</TD><TD PORT="entry_count_size">4</TD><TD>uint32</TD><TD PORT="entry_count_type">entry_count</TD></TR>
        <TR><TD PORT="head_size_pos">10</TD><TD PORT="head_size_size">2</TD><TD>uint16</TD><TD PORT="head_size_type">head_size</TD></TR>
        <TR><TD PORT="meta_entry_pos">16</TD><TD PORT="meta_entry_size">8</TD><TD>entry</TD><TD PORT="meta_entry_type">meta_entry</TD></TR>
        <TR><TD PORT="entries_pos">24</TD><TD PORT="entries_size">...</TD><TD>entry</TD><TD PORT="entries_type">entries (repeat entry_count times)</TD></TR>
      </TABLE>

### <a name="spacemanager"></a> Spacemanager

The spacemanager (sometimes called spaceman) is used to manage allocated blocks in the APFS container. The number of free blocks and a pointer to the allocation info file(s?) are stored here. 

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="blocksize_pos">0</TD><TD PORT="blocksize_size">4</TD><TD>uint32</TD><TD PORT="blocksize_type">blocksize</TD></TR>
        <TR><TD PORT="totalblocks_pos">16</TD><TD PORT="totalblocks_size">8</TD><TD>uint64</TD><TD PORT="totalblocks_type">totalblocks</TD></TR>
        <TR><TD PORT="freeblocks_pos">40</TD><TD PORT="freeblocks_size">8</TD><TD>uint64</TD><TD PORT="freeblocks_type">freeblocks</TD></TR>
        <TR><TD PORT="prev_allocationinfofile_block_pos">144</TD><TD PORT="prev_allocationinfofile_block_size">8</TD><TD>uint64</TD><TD PORT="prev_allocationinfofile_block_type">prev_allocationinfofile_block</TD></TR>
        <TR><TD PORT="allocationinfofile_block_pos">352</TD><TD PORT="allocationinfofile_block_size">8</TD><TD>uint64</TD><TD PORT="allocationinfofile_block_type">allocationinfofile_block</TD></TR>
      </TABLE>

### <a name="allocation_info_file"></a> Allocation Info File

The allocation info file works as a missing header for the allocation file. The allocation files length, version and the offset of the allocation file are stored here.

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="alloc_file_length_pos">4</TD><TD PORT="alloc_file_length_size">4</TD><TD>uint32</TD><TD PORT="alloc_file_length_type">alloc_file_length</TD></TR>
        <TR><TD PORT="alloc_file_version_pos">8</TD><TD PORT="alloc_file_version_size">4</TD><TD>uint32</TD><TD PORT="alloc_file_version_type">alloc_file_version</TD></TR>
        <TR><TD PORT="total_blocks_pos">24</TD><TD PORT="total_blocks_size">4</TD><TD>uint32</TD><TD PORT="total_blocks_type">total_blocks</TD></TR>
        <TR><TD PORT="free_blocks_pos">28</TD><TD PORT="free_blocks_size">4</TD><TD>uint32</TD><TD PORT="free_blocks_type">free_blocks</TD></TR>
        <TR><TD PORT="allocationfile_block_pos">32</TD><TD PORT="allocationfile_block_size">4</TD><TD>uint32</TD><TD PORT="allocationfile_block_type">allocationfile_block</TD></TR>
      </TABLE>

### <a name="0x11"></a> Unknown

The structure with type 0x11 is quite empty and seems to be related to the spacemanager as it occurs adjacent to it. Its purpose it unknown. 

### <a name="btree"></a> B-Tree

B-trees manage multiple nodes. They contain the offset of the root node.

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="root_pos">16</TD><TD PORT="root_size">8</TD><TD>uint64</TD><TD PORT="root_type">root</TD></TR>
      </TABLE>

### <a name="checkpoint"></a> Checkpoint

A checkpoint structure exists for every container superblock. But I have no clue what it is good for.

### <a name="volume_superblock"></a> Volume Superblock

A volume superblock exists for each volume in the filesystem. It contains the name of the volume, an ID and a timestamp. Similarly to the container superblock it contains a pointer to a block map which maps block IDs to bock offsets. Additionally a pointer to the root directory, which is stored as a node, is stored in the volume superblock. 

<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
        <TR><TD BGCOLOR="#09c">pos</TD><TD BGCOLOR="#09c">size</TD><TD BGCOLOR="#09c">type</TD><TD BGCOLOR="#09c">id</TD></TR>
        <TR><TD PORT="magic_pos">0</TD><TD PORT="magic_size">4</TD><TD>byte</TD><TD PORT="magic_type">magic "APSB"</TD></TR>
        <TR><TD PORT="block_map_pos">96</TD><TD PORT="block_map_size">8</TD><TD>uint64</TD><TD PORT="block_map_type">block_map</TD></TR>
        <TR><TD PORT="root_dir_id_pos">104</TD><TD PORT="root_dir_id_size">8</TD><TD>uint64</TD><TD PORT="root_dir_id_type">root_dir_id</TD></TR>
        <TR><TD PORT="pointer3_pos">112</TD><TD PORT="pointer3_size">8</TD><TD>uint64</TD><TD PORT="pointer3_type">pointer3</TD></TR>
        <TR><TD PORT="pointer4_pos">120</TD><TD PORT="pointer4_size">8</TD><TD>uint64</TD><TD PORT="pointer4_type">pointer4</TD></TR>
        <TR><TD PORT="bin_pos">208</TD><TD PORT="bin_size">16</TD><TD>byte</TD><TD PORT="bin_type">guid</TD></TR>
        <TR><TD PORT="time1_pos">224</TD><TD PORT="time1_size">8</TD><TD>uint64</TD><TD PORT="time1_type">time1</TD></TR>
        <TR><TD PORT="time2_pos">272</TD><TD PORT="time2_size">8</TD><TD>uint64</TD><TD PORT="time2_type">time2</TD></TR>
        <TR><TD PORT="name_pos">672</TD><TD PORT="name_size">8</TD><TD>str(ASCII)</TD><TD PORT="name_type">name</TD></TR>
      </TABLE>

### <a name="allocation_file"></a> Allocation File

Allocation files are simple bitmaps. They do not have a block header and therefore no type id.
