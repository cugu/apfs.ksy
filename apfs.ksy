meta:
  id: apfs
  license: MIT
  encoding: UTF-8
  endian: le

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
            block_type::node_2: node
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
      - id: type_node
        type: u2
        enum: node_type
      - id: unknown_34
        type: u2
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
        type: entry_header
      - id: entries
        type:
          switch-on: type_node
          cases:
            node_type::flex_1: flex_entry
            node_type::flex_2: flex_entry
            node_type::flex_3: flex_entry
            node_type::fixed: fixed_entry
        repeat: expr
        repeat-expr: num_entries

## node entries

  flex_entry:
    seq:
      - id: header
        type: entry_header
    instances:
      key:
        pos: header.ofs_key + _parent.ofs_keys + 56
        type: flex_key
      block_id:
        pos: '_root.block_size - header.ofs_data - 40 * ((_parent.type_node != node_type::flex_2) ? 1 : 0)'
        if: _parent.type_node == node_type::flex_1
        type: u8
      record:
        pos: '_root.block_size - header.ofs_data - 40 * ((_parent.type_node != node_type::flex_2) ? 1 : 0)'
        if: _parent.type_node != node_type::flex_1
        size: header.len_data
        type:
          switch-on: key.type_entry
          cases:
            entry_type::name: flex_named_record
            entry_type::thread: flex_thread_record
            entry_type::idpair: flex_idpair_record
            entry_type::entry_60: flex_60_record
            entry_type::extent: flex_extent_record
            entry_type::entry_c0: flex_c0_record
            entry_type::extattr: flex_extattr_record

  fixed_entry:
    seq:
      - id: header
        type: fixed_entry_header
    instances:
      key:
        pos: header.ofs_key + _parent.ofs_keys + 56
        #size: _parent.meta_entry.len_key
        type:
          switch-on: _parent._parent.header.type_content
          cases:
            content_type::history: fixed_history_key
            content_type::location: fixed_loc_key
      record:
        pos: _root.block_size - header.ofs_data - 40
        #size: _parent.meta_entry.len_data
        type:
          switch-on: _parent._parent.header.type_content
          cases:
            content_type::history: fixed_history_record
            content_type::location: fixed_loc_record

## node entry header

  entry_header:
    seq:
      - id: ofs_key
        type: s2
      - id: len_key
        type: u2
      - id: ofs_data
        type: s2
      - id: len_data
        type: u2

  fixed_entry_header:
    seq:
      - id: ofs_key
        type: s2
      - id: ofs_data
        type: s2

## node fixed entry keys

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
      - id: type0
        type: u1
      - id: type1
        type: u1
      - id: type2
        type: u1
      - id: type_entry
        type: u1
        enum: entry_type
      - id: content
        size: _parent.header.len_key
        type:
          switch-on: type_entry
          cases:
            entry_type::name: flex_named_key
            entry_type::idpair: flex_idpair_key
            entry_type::extattr: flex_named_key
            entry_type::extent: flex_extent_key
            entry_type::location: flex_location_key

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

  flex_idpair_key:
    seq:
      - id: id2
        type: u4
      - id: id3
        type: u4

  flex_extent_key:
    seq:
      - id: id2
        type: u8

  flex_location_key:
    seq:
      - id: version
        type: u8

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
      - id: unk_48
        type: u8
      - id: unk_56
        type: u8
      - id: unk_64
        type: u8
      - id: unk_72
        type: u8
      - id: access
        type: u8
      - id: unknown_88
        type: u8
      - id: block_id
        type: u2
      - id: len_name
        type: u2
      - id: name_filler
        type: u4
        if: unk_64 > 2
      - id: name
        type: strz
      - id: unk_remainder
        size-eos: true

  flex_idpair_record: # 0x50
    seq:
      - id: node_id
        type: u8
      - id: namelength
        type: u2
      - id: dirname
        size: namelength
        type: str

  flex_60_record: # 0x60
    seq:
      - id: unknown_0
        type: u4

  flex_extent_record: # 0x80
    seq:
      - id: size
        type: u8
      - id: block
        type: u8

  flex_named_record: # 0x90
    seq:
      - id: node_id
        type: u8
      - id: timestamp
        type: u8
      - id: type_item
        type: u2
        enum: item_type

  flex_c0_record: # 0xc0
    seq:
      - id: unknown_0
        type: u8

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
    0x00: location
    0x20: volume
    0x30: thread
    0x40: extattr
    0x50: idpair
    0x60: entry_60
    0x80: extent
    0x90: name
    0xc0: entry_c0

  node_type:
    0x01: flex_1
    0x02: flex_2
    0x03: flex_3
    0x07: fixed

  content_type:
    0: empty
    9: history
    11: location
    14: files
    15: unknown2
    16: unknown3

  item_type:
    4: folder
    8: file
    10: type_10

  ea_type:
    2: generic
    6: symlink
    
