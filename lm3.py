from snes import SFCAddress, SFCAddressType
from script import Table

"""
Little Master 3
TODO: Find more pointer locations.
      Extract old script for comparison.
      Work on script. 
      Work on font.
      VWF?
"""

# for adding length for pointer table features
fmt_length = [
    0,  # ptr_format = 0
    1  # ptr_format = 1
]


def extract_script_bins(file_name='base.sfc', folder_prefix='test', table_filename='jap.tbl'):
    folder_name = f'{folder_prefix}_ptr_data'
    #BF9B1B9C
    tables = [
        {   # main script data
            'ptr_tbl_pos': 0x1B0000,
            'tbl_len': 0x400,
            'table_name': 'script'
        },
        {   # secondary script data
            'ptr_tbl_pos': 0x50101,
            'tbl_len': 0x400,
            'table_name': 'script_ext'
        },
        {   # Scenario description
            'ptr_tbl_pos': 0x111EE3,
            'tbl_len': 0x13C,
            'table_name': 'scenario-desc'
        },
        {   # unit and terrain and item descriptions
            'ptr_tbl_pos': 0x30000,
            'tbl_len': 0x500,
            'table_name': 'unit-terrain-desc'
        },
        [   # data for unit attacks that are re-used (they seem to be exact) between the 5 unit type tables
            {
                'ptr_tbl_pos': 0x1B0800,
                'tbl_len': 0x6A,
                'table_name': 'unit-attacks',
                'output': False
            },
            {
                'ptr_tbl_pos': 0x1B0A00
            },
            {
                'ptr_tbl_pos': 0x1B0C00
            },
            {
                'ptr_tbl_pos': 0x1B0E00
            },
            {
                'ptr_tbl_pos': 0x1B1000,
                'output': True
            },
        ],
        {
            'data_pos': 0x10050,
            'data_len': 0x1FFE,
            'block_len': 0x20,
            'block_eval': [
                {
                    'label': 'weapon',
                    'start': 0x0,
                    'len': 0x9,
                    'fill': 0x20
                },
                {
                    'label': 'armor',
                    'start': 0xC,
                    'len': 0x9,
                    'fill': 0x20
                },
            ],
            'table_name': 'unit-equipment'
        },
    ]

    # 0x1456B - Unit Attribute Value Pointer (0x3 length) - 2 byte height, weight, 1 byte age
    # 0x1457F - Unit Weapon Name Pointer - Preceeding byte is entry length
    # 0x14588 - Unit Armor Name Pointer - Preceeding byte is entry length

    for p_tbl in tables:
        p_tbls = p_tbl if type(p_tbl) is list else [p_tbl]
        kwargs = {
            'input_filename': file_name,
            'table': table_filename,
            'out_folder': folder_name
        }
        for tbl_info in p_tbls:
            kwargs.update(tbl_info)
            if 'data_pos' in kwargs.keys():
                data_extract(**clean_keys(kwargs))
            else:
                kwargs['ptr_data'] = extract_pointer_data(**kwargs)


def check_folder(folder_path):
    import os
    try:
        if not os.path.isdir(folder_path):
            os.mkdir(folder_path)
            print(f'Info: Created output folder. "{folder_path}"')
    except OSError as error:
        print(f'Warning: Cannot create output folder. "{folder_path}"')


def extract_pointer_data(input_filename: str, ptr_tbl_pos: int, tbl_len: int, table_name: str, out_folder='out',
                         ptr_data: dict = None, output=True, table: str = None, **kwargs):
    data_file = open(input_filename, "rb")
    bin_data = list(data_file.read())
    return pointer_extract(table_name, out_folder, bin_data, ptr_tbl_pos, tbl_len,
                           ptr_data=ptr_data, output=output, table=table, **kwargs)


def dump_bin(folder_path: str, bin_filename: str, data: list):
    if data and len(data) > 1:  # if data, spit it out
        file_name = f"./{folder_path}/{bin_filename}"
        try:
            ptr_file = open(file_name, "wb")
            ptr_file.write(bytearray(data))
            ptr_file.close()
        except Exception as ex:
            print(f"Error: {repr(ex)}")

def pointer_extract(table_name: str, out_folder: str, bin_data: list, ptr_tbl_loc: int, ptr_tbl_len: int = None,
                    ptr_bytes: int = 2, ptr_bank: int = None, ptr_data: dict = None, output=True, table: str = None,
                    out_addr_type: int = 4, ptr_addr_type: int = SFCAddressType.LOROM1, ptr_format: int = 0):
    """
    Extract data using the pointer table. Extract only binary data in separate files otherwise.
    :param table_name: folder name for the exported data
    :param out_folder: folder path where table_name is used as the full exported path ex. {outfolder}/{table_name}
    :param bin_data: list of bytes which is evaluated
    :param ptr_tbl_loc: PC address where table is located in the binary data
    :param ptr_tbl_len: byte length of the pointer table
    :param ptr_bytes: the address length for the pointer
    :param ptr_bank: optional: if the bank is not part of the pointer, the bank byte for the address can be set here
    :param ptr_data: optional: if we already have some generated data we are adding to
    :param output: if we are dumping True, otherwise False
    :param table: character table path or None if only binary data is processed (dumped)
    :param out_addr_type: location value to show for the text output
    0=Table PC Address with index
    1=Table Index Only
    2=Pointer Address
    3=Block Address
    4=Combines 0 with 3
    :param ptr_addr_type: pointer address conversion (default is LOROM1)
    :param ptr_format: how the pointer address is evaluated uses ptr_bytes for the address length (default is address only)
    0: Address Only
    1: Block Length, and Address - ex: 054484 (len: 5 bytes, address: 8444)
    :return:
    """

    import os
    if not ptr_tbl_len:
        ptr_tbl_len = 0x1000

    ptr_table_addr = SFCAddress(ptr_tbl_loc)
    if not ptr_bank:
        # the bank of the pointer table is used for the data unless specified otherwise
        ptr_bank = ptr_table_addr.get_bank_byte(ptr_addr_type)
    if not ptr_data:
        ptr_data = {}
    tbl = Table(table) if table else None

    check_folder(out_folder)

    table_folder = f'{out_folder}/{table_name}'
    check_folder(table_folder)

    pointer_list = ptr_data['ptr_list'] if ptr_data else []
    bin_list = ptr_data['bin_list'] if ptr_data else []

    ptr_index = 0
    for i in range(ptr_tbl_loc, ptr_tbl_loc + ptr_tbl_len, ptr_bytes + ptr_format):

        add_len = fmt_length[ptr_format]

        # get the bytes for the pointer
        ptr_end = (i + add_len) + ptr_bytes

        this_ptr_data = bin_data[(i + add_len): ptr_end]

        # convert the pointer to an SFCAddress object
        ptr = SFCAddress([this_ptr_data[0], this_ptr_data[1], ptr_bank], ptr_addr_type)

        # convert the address objects for the current and next pointer to data start/stop positions
        data_start = ptr.get_address(SFCAddressType.PC)
        if add_len == 0:
            data_end = data_start

            found = False
            while not found:
                try:
                    end_inc, char = tbl.check_for_lone_byte(bin_data, data_end, 0x0)
                    if end_inc == -1:
                        found = True
                    elif end_inc > 0:
                        data_end += end_inc - 1
                except IndexError:
                    data_end -= 2
                    found = True
                data_end += 1
        else:
            data_end = data_start + add_len

        data = bin_data[data_start: data_end]

        tab_addr = ptr_table_addr.get_address()

        pointer_list.append({'ptr_table_hex': ptr_table_addr.pc_address, 'ptr_table_dec': tab_addr,
                             'index': ptr_index, 'length': data_end - data_start, 'pc': ptr.pc_address,
                             'lorom': ptr.lorom1_address, 'pc_dec': data_start})

        # add it to the list using the requested address type
        if data_start not in [b['id'] for b in bin_list]:
            this_id = f'${tab_addr}:{ptr_index}'
            if out_addr_type == 1:  # index only
                this_id = ptr_index
            elif out_addr_type == 2:  # the pc address of the pointer
                this_id = f'(${i})'
            elif out_addr_type == 3:  # pc address of the data block
                this_id = f'[${data_start}]'
            elif out_addr_type == 4:  # table address, index and data addr
                this_id += f'[${data_start}]'
            bin_list.append({'id': this_id, 'addr':data_start, 'data': data})

        dump_bin(table_folder, f'{data_start}.bin', data)

        ptr_index += 1
    if output:
        Table.export_csv(table_folder, pointer_list)
        if table:  # if we get a table, output the text representation
            tbl.dump_script(f'./{out_folder}/{table_name}.txt', bin_list)
            print(f'Saved {hex(ptr_index)}({ptr_index}) blocks of data from table: {table_name}.')

    ptr_data['bin_list'] = bin_list
    ptr_data['ptr_list'] = pointer_list
    return ptr_data

def clean_keys(in_dict):
    allowed = ['table_name', 'out_folder', 'bin_data', 'data_pos', 'data_len',
               'block_len', 'output', 'table', 'input_filename', 'block_eval']
    final_dict = in_dict.copy()
    for key in in_dict.keys():
        if key not in allowed:
            final_dict.pop(key)
    return final_dict


def data_extract(input_filename: str, table_name: str, out_folder: str, data_pos: int, data_len: int,
                 block_len: int, output=True, table: str = None, block_eval: dict = None):
    data_file = open(input_filename, "rb")
    bin_data = list(data_file.read())

    tbl = Table(table) if table else None

    check_folder(out_folder)

    table_folder = f'{out_folder}/{table_name}'
    check_folder(table_folder)

    bin_list = []
    ptr_list = []
    tbl_index = 0
    for i in range(data_pos, data_pos + data_len, block_len):
        data_start = i
        data_end = data_start + block_len
        data = bin_data[data_start: data_end]

        ptr_list.append({'data_table_dec': data_pos, 'index': tbl_index,
                         'length': data_end - data_start, 'pc_dec': data_start})

        # add it to the list using the requested address type
        if data_start not in [b['id'] for b in bin_list]:
            this_id = f'${data_pos}:{tbl_index}'
            if block_eval is not None:
                for e in block_eval:
                    # label, start, len, fill
                    e_start = e.get('start', 0)
                    e_end = e_start + e.get('len', 0)

                    bin_list.append({'id': f'{this_id}.{e.get("label", e_start)}',
                                     'addr': data_start + e_start,
                                     'data': data[e_start:e_end], 'trim': e.get('fill', None)})
            else:
                bin_list.append({'id': this_id, 'addr': data_start, 'data': data, 'trim': None})

        dump_bin(table_folder, f'{data_start}.bin', data)

        tbl_index += 1

    if output:
        Table.export_csv(table_folder, ptr_list)
        if table:  # if we get a table, output the text representation
            tbl.dump_script(f'./{out_folder}/{table_name}.txt', bin_list)
            print(f'Saved {hex(tbl_index)}({tbl_index}) blocks of data from table: {table_name}.')