#!/usr/bin/env python

""" List non-empty block in APFS file system """

import sys
from tabulate import tabulate
from kaitaistruct import __version__ as ks_version, KaitaiStream, BytesIO
import apfs


def get_block(idx, block_size, file_io):
    """ Get data of a single block """
    file_io.seek(idx * block_size)
    return file_io.read(block_size)


def main():
    """ List non-empty block in APFS file system """
    with open(sys.argv[1], 'rb') as input_file:
        # get block_size
        apfs_parser = apfs.Apfs(KaitaiStream(input_file))
        block = apfs_parser.Block(KaitaiStream(input_file), apfs_parser, apfs_parser)
        block_size = block.body.block_size

        out = []

        # get latest superblock
        i = 0
        while True:
            # get data
            data = get_block(i, block_size, input_file)
            column = {
                'block_id': "-",
                'version': "-",
                'type_block': "-",
                'type_content': "-",
                'error': "-",
                'infos': "",
                'flags': "-"
            }

            if not data:
                break
            if not any(data):
                i += 1
                continue
            try:
                # parse block
                block = apfs_parser.Block(KaitaiStream(BytesIO(data)), apfs_parser, apfs_parser)

                column['block_id'] = block.header.block_id
                column['version'] = block.header.version
                column['type_block'] = str(block.header.type_block).replace(
                    "BlockType.", "")
                column['flags'] = hex(int(block.header.flags))
                column['type_content'] = str(block.header.type_content).replace(
                    "ContentType.", "")
                if column['type_content'] == "empty":
                    column['type_content'] = "-"

                if column['type_block'] == "node":
                    column['type_node'] = str(block.body.type_node).replace(
                        "NodeType.", "")
                    column['infos'] += "type_node: " + column['type_node']
                    #if type_node == "flex":


            except ValueError as exception:
                column['error'] = exception
            finally:
                out.append(column)
            i += 1

        print(tabulate(out, headers='keys'))


if __name__ == "__main__":
    main()
