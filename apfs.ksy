meta:
  id: apfs
  endian: le
  license: MIT
seq:
 - id: blocks
   type: block
   size: block_size
   repeat: until
   repeat-until: _io.size - _io.pos < block_size
instances:
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
      - id: block_type
        type: u2
        enum: block_type
      - id: flags
        type: u2
        doc: 0x4000 block_id = position, 0x8000 = container
      - id: node_type
        type: u2
        enum: node_type
      - id: padding
        type: u2

  block:
    seq:
      - id: header
        type: block_header
      - id: body
        type:
          switch-on: header.block_type
          cases:
            block_type::containersuperblock: containersuperblock
            block_type::node: node
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
      - id: block_count
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
      - id: volumesuperblock_ids_count
        type: u4
      - id: volumesuperblock_ids
        type: u8
        repeat: expr
        repeat-expr: volumesuperblock_ids_count

# node (type: 0x02)

  node:
    seq:
      - id: alignment_type
        type: u2
        enum: alignment_type
      - id: unknown_34
        type: u2
      - id: entry_count
        type: u4
      - id: unknown_40
        type: u2
      - id: keys_offset
        type: u2
      - id: keys_size
        type: u2
      - id: data_offset
        type: u2
      - id: meta_entry
        type: entry_header
      - id: entries
        type:
          switch-on: alignment_type
          cases:
            alignment_type::flex: flex_entry
            alignment_type::fixed: fixed_entry
        repeat: expr
        repeat-expr: entry_count

## node entries

  flex_entry:
    seq:
      - id: header
        type: entry_header
    instances:
      key:
        pos: header.key_offset + _parent.keys_offset + 56
        # size: header.key_length + 8
        type: flex_key
      record:
        pos: _root.block_size - header.data_offset - 40
        size: header.data_length
        type:
          switch-on: key.entry_type
          cases:
            entry_type::name: flex_named_record
            entry_type::thread: flex_thread_record
            entry_type::extent: flex_extent_record

  fixed_entry:
    seq:
      - id: header
        type: fixed_entry_header
    instances:
      key:
        pos: header.key_offset + _parent.keys_offset + 56
        type:
          switch-on: _parent._parent.header.node_type
          cases:
            node_type::history: fixed_history_key
            node_type::location: fixed_loc_key
            _: fixed_default_key
      record:
        pos: _root.block_size - header.data_offset - 40
        type:
          switch-on: _parent._parent.header.node_type
          cases:
            node_type::history: fixed_history_record
            node_type::location: fixed_loc_record

## node entry header

  entry_header:
    seq:
      - id: key_offset
        type: s2
      - id: key_length
        type: u2
      - id: data_offset
        type: s2
      - id: data_length
        type: u2

  fixed_entry_header:
    seq:
      - id: key_offset
        type: s2
      - id: data_offset
        type: s2

## node fixed entry keys

  fixed_default_key:
    seq:
      - id: unknown_0
        size: 16

  fixed_loc_key:
    seq:
      - id: block_id
        type: u8
      - id: unknown_8
        type: u8

  fixed_history_key:
    seq:
      - id: version
        type: u8
      - id: block
        type: u8

## node fixed entry records

  fixed_loc_record:
    seq:
      - id: unknown_0
        type: u4
      - id: unknown_4
        type: u4
      - id: block
        type: u8

  fixed_history_record:
    seq:
      - id: unknown_0
        type: u4
      - id: unknown_4
        type: u4

## node flex entry keys

  flex_key:
    seq:
      - id: parent_id
        type: u4
      - id: entry_type
        type: u4
        enum: entry_type
      - id: content
        type:
          switch-on: entry_type
          cases:
            entry_type::name: named_key
            entry_type::location: location_key

  named_key:
    seq:
      - id: name_length
        type: u2
      - id: dirname
        size: name_length
        type: str
        encoding: UTF-8

  location_key:
    seq:
      - id: version
        type: u8

## node flex entry records

  flex_named_record:
    seq:
      - id: node_id
        type: u8
      - id: timestamp
        type: u8
      - id: item_type
        type: u2
        enum: item_type

  flex_thread_record:
    seq:
      - id: node_id
        type: u8
      - id: parent_id
        type: u8
      - id: timestamps
        type: u8
        repeat: expr
        repeat-expr: 4
      - id: unknown_48
        size: 32
      - id: access
        type: u8
      - id: unknown_88
        type: u8
      - id: block_id
        type: u2
      - id: name_length
        type: u2
      - id: name
        type: str
        size-eos: true
        encoding: UTF-8
        doc: size = name_length if in UTF-8 chars not byte
      - id: padding
        size-eos: true

  flex_extent_record:
    seq:
      - id: size
        type: u8
      - id: block
        type: u8

# spaceman (type: 0x05)

  spaceman:
    seq:
      - id: block_size
        type: u4
      - id: unknown_36
        size: 12
      - id: block_count
        type: u8
      - id: unknown_56
        size: 8
      - id: entry_count
        type: u4
      - id: unknown_68
        type: u4
      - id: free_block_count
        type: u8
      - id: entries_offset
        type: u4
      - id: unknown_84
        size: 92
      - id: prev_allocationinfofile_block
        type: u8
      - id: unknown_184
        size: 200
    instances:
      allocationinfofile_blocks:
        pos: entries_offset
        repeat: expr
        repeat-expr: entry_count
        type: u8

# allocation info file (type: 0x07)

  allocationinfofile:
    seq:
      - id: unknown_32
        size: 4
      - id: entry_count
        type: u4
      - id: entries
        type: allocationinfofile_entry
        repeat: expr
        repeat-expr: entry_count

  allocationinfofile_entry:
    seq:
      - id: version
        type: u8
      - id: unknown_8
        type: u4
      - id: unknown_12
        type: u4
      - id: block_count
        type: u4
      - id: free_block_count
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
      - id: entry_count
        type: u4
      - id: entries
        type: checkpoint_entry
        repeat: expr
        repeat-expr: entry_count

  checkpoint_entry:
    seq:
      - id: block_type
        type: u2
        enum: block_type
      - id: flags
        type: u2
      - id: node_type
        type: u4
        enum: node_type
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
      - id: root_dir_id
        type: u8
      - id: unknown_144_id
        type: u8
      - id: unknown_152_id
        type: u8
      - id: unknown_160
        size: 80
      - id: volume_guid
        size: 16
      - id: time_256
        type: u8
      - id: unknown_264
        type: u8
      - id: unknown_272
        size: 32
      - id: time_304
        type: u8
      - id: unknown_312
        size: 392
      - id: name
        type: str
        size: 8
        encoding: UTF-8

# enums

enums:

  block_type:
    1: containersuperblock
    2: node
    5: spaceman
    7: allocationinfofile
    11: btree
    12: checkpoint
    13: volumesuperblock
    17: unknown

  entry_type:
    0x00000000: location
    0x20000000: volume
    0x30000000: thread
    0x60000000: unknown
    0x80000000: extent
    0x90000000: name

  alignment_type:
    0x03: flex
    0x07: fixed

  node_type:
    0: empty
    9: history
    11: location
    14: files
    15: unknown2
    16: unknown3

  item_type:
    4: folder
    8: file
