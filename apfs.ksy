meta:
  id: apfs
  license: MIT
  encoding: UTF-8
  endian: le

instances:
  b:
    pos: block_size * 0   # enter block number here to view that block
    type: block           # opens a sub stream for making positioning inside the block work
    size: block_size
  block_size:
    value: 4096

types:

# meta structs

  block_header:
    seq:
      - id: checksum
        type: u8
        doc: Flechters checksum, according to the docs.
      - id: block_id
        type: u8
        doc: ID of the block itself. Either the position of the block or an incrementing number starting at 1024.
      - id: version
        type: u8
        doc: Incrementing number of the version of the block (highest == latest)
      - id: type_block
        type: u2
        enum: block_type
      - id: flags
        type: u2
        doc: 0x4000 block_id = position, 0x8000 = container
      - id: type_content
        type: u2
        enum: content_type
      - id: padding
        type: u2

  block:
    seq:
      - id: header
        type: block_header
      - id: body
        #size-eos: true
        type:
          switch-on: header.type_block
          cases:
            block_type::containersuperblock: containersuperblock
            block_type::node_2: node    # might indicate a root node
            block_type::node_3: node
            block_type::spaceman: spaceman
            block_type::allocationinfofile: allocationinfofile
            block_type::btree: btree
            block_type::checkpoint: checkpoint
            block_type::volumesuperblock: volumesuperblock
            

# containersuperblock (type: 0x01)

  containersuperblock:
    seq:
      - id: magic
        size: 4
        contents: [NXSB]
      - id: block_size
        type: u4
      - id: num_blocks
        type: u8
      - id: padding
        size: 16
      - id: unknown_64
        type: u8
      - id: guid
        size: 16
      - id: next_free_block_id
        type: u8
      - id: next_version
        type: u8
      - id: unknown_104
        size: 32
      - id: previous_containersuperblock_block
        type: u4
      - id: unknown_140
        size: 12
      - id: spaceman_id
        type: u8
      - id: block_map_block
        type: u8
      - id: unknown_168_id
        type: u8
      - id: padding2
        type: u4
      - id: num_volumesuperblock_ids
        type: u4
      - id: volumesuperblock_ids
        type: u8
        repeat: expr
        repeat-expr: num_volumesuperblock_ids

# node (type: 0x02)

  node:
    seq:
      - id: type_flags
        type: u2
      - id: leaf_distance
        type: u2
        doc: Zero for leaf nodes, > 0 for branch nodes
      - id: num_entries
        type: u4
      - id: unknown_40
        type: u2
      - id: ofs_keys
        type: u2
      - id: len_keys
        type: u2
      - id: ofs_data
        type: u2
      - id: meta_entry
        type: full_entry_header
      - id: entries
        type: node_entry
        repeat: expr
        repeat-expr: num_entries

  full_entry_header:
    seq:
      - id: ofs_key
        type: s2
      - id: len_key
        type: u2
      - id: ofs_data
        type: s2
      - id: len_data
        type: u2

  dynamic_entry_header:
    seq:
      - id: ofs_key
        type: s2
      - id: len_key
        type: u2
        if: (_parent._parent.type_flags & 4) == 0
      - id: ofs_data
        type: s2
      - id: len_data
        type: u2
        if: (_parent._parent.type_flags & 4) == 0

## node entries

  node_entry:
    seq:
      - id: header
        type: dynamic_entry_header
    instances:
      key:
        pos: header.ofs_key + _parent.ofs_keys + 56
        type:
          switch-on: (_parent.type_flags & 4)
          cases:
            0: flex_key
            4: fixed_key
        -webide-parse-mode: eager
      rec:
        pos: _root.block_size - header.ofs_data - 40 * (_parent.type_flags & 1)
        type:
          switch-on: (_parent.type_flags & 6)
          cases:
            0: rec_ptr
            2: rec_flex
            4: rec_ptr
            6: rec_fix
        -webide-parse-mode: eager
    -webide-representation: '{key}: {rec}'

  rec_ptr:
    seq:
      - id: pointer
        type: u8
    -webide-representation: '{pointer}'

  rec_flex:
    seq:
      - id: content
        size: _parent.header.len_data
        type:
          switch-on: _parent.key.as<flex_key>.type_entry
          cases:
            entry_type::name: flex_named_record
            entry_type::thread: flex_thread_record
            entry_type::hardlink: flex_hardlink_record
            entry_type::entry_6: flex_6_record
            entry_type::extent: flex_extent_record
            entry_type::entry_c: flex_c_record
            entry_type::extattr: flex_extattr_record
        -webide-parse-mode: eager
    -webide-representation: '{content}'

  rec_fix:
    seq:
      - id: content
        #size: _parent._parent._parent.meta_entry.len_data
        type:
          switch-on: _parent._parent._parent.header.type_content.to_i + (256 * _parent._parent.type_flags)
          cases:
            content_type::history.to_i: fixed_history_record
            content_type::location.to_i + (256 * 5): fixed5_loc_record
            content_type::location.to_i + (256 * 6): fixed6_loc_record
            content_type::location.to_i + (256 * 7): fixed7_loc_record
        -webide-parse-mode: eager
    -webide-representation: '{content}'

## node fixed entry keys

  fixed_key:
    seq:
      - id: key
        type:
          switch-on: _parent._parent._parent.header.type_content
          cases:
            content_type::history: fixed_history_key
            content_type::location: fixed_loc_key
    -webide-representation: '{key}'

  fixed_loc_key:
    seq:
      - id: block_id
        type: u8
      - id: version
        type: u8
    -webide-representation: 'ID {block_id} v{version}'

  fixed_history_key:
    seq:
      - id: version
        type: u8
      - id: block_num
        type: u8
    -webide-representation: 'v{block_id} Blk {version}'

## node fixed entry records

  fixed7_loc_record:
    seq:
      - id: block_start
        type: u4
      - id: block_length
        type: u4
      - id: block_num
        type: u8
    -webide-representation: 'Blk {block_num}, from {block_start}, len {block_length}'

  fixed5_loc_record:
    seq:
      - id: block_num
        type: u8
    -webide-representation: 'Blk {block_num}'

  fixed6_loc_record:
    seq:
      - id: block_num
        type: u8
      - id: unk_ofs
        type: u2
      - id: unk_len
        type: u2
      - id: block_length
        type: u4
    -webide-representation: 'Blk {block_num}, len {block_length}'

  fixed_history_record:
    seq:
      - id: unknown_0
        type: u4
      - id: unknown_4
        type: u4
    -webide-representation: '{unknown_0}, {unknown_4}'

## node flex entry keys

  flex_key:
    seq:
      - id: id_low
        type: u4
      - id: id_high
        type: u4
      - id: content
        #size: _parent.header.len_key
        type:
          switch-on: type_entry
          cases:
            entry_type::name: flex_named_key
            entry_type::hardlink: flex_hardlink_key
            entry_type::extattr: flex_named_key
            entry_type::extent: flex_extent_key
            entry_type::location: flex_location_key
    instances:
      parent_id:
        value: id_low + ((id_high & 0x0FFFFFFF) << 32)
        -webide-parse-mode: eager
      type_entry:
        value: id_high >> 28
        enum: entry_type
        -webide-parse-mode: eager
    -webide-representation: '({type_entry}) {parent_id} {content}'

  flex_named_key:
    seq:
      - id: len_name
        type: u1
      - id: flag_1
        type: u1
      - id: unknown_2
        type: u2
        if: flag_1 != 0
      - id: dirname
        size: len_name
        type: strz
    -webide-representation: '"{dirname}"'

  flex_hardlink_key:
    seq:
      - id: id2
        type: u8
    -webide-representation: '#{id2}'

  flex_extent_key:
    seq:
      - id: offset # seek pos in file
        type: u8
    -webide-representation: '{offset}'

  flex_location_key:
    seq:
      - id: version
        type: u8
    -webide-representation: 'v{version}'

## node flex entry records

  flex_thread_record: # 0x30
    seq:
      - id: node_id
        type: u8
      - id: parent_id
        type: u8
      - id: timestamps
        type: u8
        repeat: expr
        repeat-expr: 4
      - id: flags
        type: u4
      - id: unknown_52
        type: u4
      - id: unknown_56
        type: u8
      - id: unknown_64
        type: u8
      - id: owner_id
        type: u4
      - id: group_id
        type: u4
      - id: access
        type: u4
      - id: unknown_84
        type: u4
      - id: unknown_88
        type: u4
      - id: filler_flag
        type: u2
      - id: unknown_94
        type: u2
      - id: unknown_96
        type: u2
      - id: len_name
        type: u2
      - id: name_filler
        type: u4
        if: filler_flag == 2
      - id: name
        type: strz
      - id: unknown_remainder
        size-eos: true
    -webide-representation: '#{node_id} / #{parent_id} "{name}"'

  flex_hardlink_record: # 0x50
    seq:
      - id: node_id
        type: u8
      - id: namelength
        type: u2
      - id: dirname
        size: namelength
        type: str
    -webide-representation: '#{node_id} "{dirname}"'

  flex_6_record: # 0x60
    seq:
      - id: unknown_0
        type: u4
    -webide-representation: '{unknown_0}'

  flex_extent_record: # 0x80
    seq:
      - id: size
        type: u8
      - id: block
        type: u8
      - id: unknown_16
        type: u8
    -webide-representation: 'Blk {block}, Len {size}, {unknown_16}'

  flex_named_record: # 0x90
    seq:
      - id: node_id
        type: u8
      - id: timestamp
        type: u8
      - id: type_item
        type: u2
        enum: item_type
    -webide-representation: '#{node_id}, {type_item}'

  flex_c_record: # 0xc0
    seq:
      - id: unknown_0
        type: u8
    -webide-representation: '{unknown_0}'

  flex_extattr_record: # 0x40
    seq:
      - id: type_ea
        type: u2
        enum: ea_type
      - id: len_data
        type: u2
      - id: data
        size: len_data
        type:
          switch-on: type_ea
          cases:
            ea_type::symlink: strz # symlink
            # all remaining cases are handled as a "bunch of bytes", thanks to the "size" argument
    -webide-representation: '{type_ea} {data}'


# spaceman (type: 0x05)

  spaceman:
    seq:
      - id: block_size
        type: u4
      - id: unknown_36
        size: 12
      - id: num_blocks
        type: u8
      - id: unknown_56
        size: 8
      - id: num_entries
        type: u4
      - id: unknown_68
        type: u4
      - id: num_free_blocks
        type: u8
      - id: ofs_entries
        type: u4
      - id: unknown_84
        size: 92
      - id: prev_allocationinfofile_block
        type: u8
      - id: unknown_184
        size: 200
    instances:
      allocationinfofile_blocks:
        pos: ofs_entries
        repeat: expr
        repeat-expr: num_entries
        type: u8

# allocation info file (type: 0x07)

  allocationinfofile:
    seq:
      - id: unknown_32
        size: 4
      - id: num_entries
        type: u4
      - id: entries
        type: allocationinfofile_entry
        repeat: expr
        repeat-expr: num_entries

  allocationinfofile_entry:
    seq:
      - id: version
        type: u8
      - id: unknown_8
        type: u4
      - id: unknown_12
        type: u4
      - id: num_blocks
        type: u4
      - id: num_free_blocks
        type: u4
      - id: allocationfile_block
        type: u8

# btree (type: 0x0b)

  btree:
    seq:
      - id: unknown_0
        size: 16
      - id: root
        type: u8

# checkpoint (type: 0x0c)

  checkpoint:
    seq:
      - id: unknown_0
        type: u4
      - id: num_entries
        type: u4
      - id: entries
        type: checkpoint_entry
        repeat: expr
        repeat-expr: num_entries

  checkpoint_entry:
    seq:
      - id: type_block
        type: u2
        enum: block_type
      - id: flags
        type: u2
      - id: type_content
        type: u4
        enum: content_type
      - id: block_size
        type: u4
      - id: unknown_52
        type: u4
      - id: unknown_56
        type: u4
      - id: unknown_60
        type: u4
      - id: block_id
        type: u8
      - id: block
        type: u8

# volumesuperblock (type: 0x0d)

  volumesuperblock:
    seq:
      - id: magic
        size: 4
        contents: [APSB]
      - id: unknown_36
        size: 92
      - id: block_map_block
        type: u8
        doc: 'Maps node IDs to the inode Btree nodes'
      - id: root_dir_id
        type: u8
      - id: inode_map_block
        type: u8
        doc: 'Maps file extents to inodes'
      - id: unknown_152_id
        type: u8
      - id: unknown_160
        size: 80
      - id: volume_guid
        size: 16
      - id: time_updated
        type: u8
      - id: unknown_264
        type: u8
      - id: created_by
        size: 32
        type: strz
      - id: time_created
        type: u8
      - id: unknown_312
        size: 392
      - id: volume_name
        type: strz

# enums

enums:

  block_type:
    1: containersuperblock
    2: node_2
    3: node_3
    5: spaceman
    7: allocationinfofile
    11: btree
    12: checkpoint
    13: volumesuperblock
    17: unknown

  entry_type:
    0x0: location
    0x2: inode
    0x3: thread
    0x4: extattr
    0x5: hardlink
    0x6: entry_6
    0x8: extent
    0x9: name
    0xc: entry_c

  content_type:
    0: empty
    9: history
    11: location
    14: files
    15: extents
    16: unknown3

  item_type:
    4: folder
    8: file
    10: type_10

  ea_type:
    2: generic
    6: symlink
