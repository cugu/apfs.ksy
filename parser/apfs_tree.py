#!/usr/bin/env python

"""
Parse an APFS and print a file tree
"""

from collections import defaultdict
import argparse
from anytree import Node, RenderTree
from kaitaistruct import __version__ as ks_version, KaitaiStream, BytesIO
import apfs


def list_extents(extent_entries, node_id):
    """ Get list of extents for given node_id """
    extents = extent_entries[node_id]
    result = []
    for extent_entry in extents:
        result.append({
            "offset": extent_entry.key.content.offset,
            "size": extent_entry.record.size,
            "block": extent_entry.record.block
        })
    return result

class APFSTree:
    """ Parse an APFS and print a file tree """

    apfs = None
    input_file = None
    blocksize = 0

    def get_block(self, idx):
        """ Get data of a single block """
        self.input_file.seek(idx * self.blocksize)
        return self.input_file.read(self.blocksize)

    def read_block(self, block_num):
        """ Parse a singe block """
        data = self.get_block(block_num)
        if not data:
            return None
        block = self.apfs.Block(
            KaitaiStream(BytesIO(data)), self.apfs, self.apfs)
        return block

    def get_entries(self, block):
        """ Get entries with type name """
        name_entries = {}
        extent_entries = defaultdict(list)
        for _, entry in enumerate(block.body.entries):
            if block.header.type_block == self.apfs.BlockType.indexnode:
                # just follow the index blocks
                if block.header.type_content == self.apfs.ContentType.files:
                    # we ignore these here as they only give us the IDs of other nodes,
                    # but we want the block numbers, which we'll get from the
                    # ContentType.location nodes in the else case below
                    pass
                elif block.body.type_node == self.apfs.NodeType.fixed:
                    newblock = self.read_block(entry.record.block_num)
                    entries = self.get_entries(newblock)
                    name_entries.update(entries['name'])
                    extent_entries.update(entries['extent'])
                else:
                    raise "unexpected"
            elif entry.key.type_entry.value == self.apfs.EntryType.extent.value:
                extent_entries[entry.key.parent_id].append(entry)
            elif entry.key.type_entry.value == self.apfs.EntryType.name.value:
                name_entries[entry.record.node_id] = entry

        return {'name': name_entries, 'extent': extent_entries}

    def list_children(self, pid, entries, parent_node, depth=1):
        """ List children of given pid """
        for item_id, name_entry in entries['name'].items():

            if name_entry.key.parent_id == pid:
                name = name_entry.key.content.dirname
                extents = list_extents(entries['extent'], item_id)
                if any(extents):
                    extent_str = ", extents: %s" % extents
                else:
                    extent_str = ""
                node_desc = name
                if self.verbose:
                    type_item = str(name_entry.record.type_item).replace(
                        "ItemType.", "")
                    node_desc = "%s (%s, node ID: %d%s)" % (
                        node_desc, type_item, name_entry.record.node_id, extent_str)
                tree_node = Node(node_desc, parent=parent_node)
                self.list_children(item_id, entries, tree_node, depth + 1)

    def add_volume(self, volume_block, apfs_tree):
        """ Add volume dir entries to tree """

        # get volume superblock
        block = self.read_block(volume_block)
        block_map = block.body.block_map_block  # mapping btree
        root_dir_id = block.body.root_dir_id  # root dir id
        if self.verbose:
            vol_desc = "%s (volume, Mapping-Btree: %d, Rootdir-ID: %d" % (
                block.body.name, block_map, root_dir_id)
        else:
            vol_desc = block.body.name

        # get volume btree
        block = self.read_block(block_map)

        # get root btree node and parse it with all its children, collecting dir entries
        block = self.read_block(block.body.root)
        entries = self.get_entries(block)

        # create a tree from the found dir entries
        vol_node = Node(vol_desc, apfs_tree)
        self.list_children(1, entries, vol_node)

    def __init__(self):
        argparser = argparse.ArgumentParser(
            description='Print file tree for apfs images')
        argparser.add_argument(
            "-v",
            "--verbose",
            help="increase output verbosity",
            action="store_true")
        argparser.add_argument("image", help="path to apfs image")

        args = argparser.parse_args()
        self.verbose = args.verbose

        with open(args.image, 'rb') as input_file:

            self.input_file = input_file

            # get blocksize
            self.apfs = apfs.Apfs(KaitaiStream(input_file))
            block = self.apfs.Block(
                KaitaiStream(input_file), self.apfs, self.apfs)
            self.blocksize = block.body.block_size

            # get containersuperblock
            containersuperblock = self.read_block(0)

            # get list of volume ids
            apfss = containersuperblock.body.volumesuperblock_ids
            block_map = containersuperblock.body.block_map_block
            if args.verbose:
                print("Volume IDs: %s, Mapping-Btree: %d" % (apfss, block_map))

            # get root of btree TODO: btree might be larger...
            block = self.read_block(block_map)

            # get leaf node
            apfs_locations = {}
            block = self.read_block(block.body.root)
            for _, entry in enumerate(block.body.entries):
                apfs_locations[entry.key.block_id] = entry.record.block_num
            if args.verbose:
                print("Volume Blocks:", apfs_locations, "\n")

            apfs_tree = Node("apfs")

            for _, volume_block in apfs_locations.items():
                self.add_volume(volume_block, apfs_tree)

            for pre, _, node in RenderTree(apfs_tree):
                print("%s%s" % (pre, node.name))


if __name__ == "__main__":
    APFSTree()
