from RetroTool.snes import SFCAddress, SFCAddressType
from RetroTool.script import Table
from PIL import Image

"""
Little Master 3 English Script Dumper and Inserter
TODO: Work on font.
      Finish event script dump if possible.
      VWF?
      Test inserting current script.
      Rewrite DTE script/Table for event script use.
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
        {   # secondary script data (event scripts with embedded dialog)
            'ptr_tbl_pos': 0x50101,
            'tbl_len': 0x400,
            'table_name': 'script_ext',
            'event_script': True
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
        {   # supplementary character dialog (Charlie, Momo, etc.)
            'ptr_tbl_pos': 0x1B8000,
            'tbl_len': 0x188,
            'table_name': 'dialog-2'
        },
        {   # supplementary character dialog (Hauser, Weiss scenes)
            'ptr_tbl_pos': 0x1B8100,
            'tbl_len': 0x88,
            'table_name': 'dialog-3'
        },
        {   # short dialog scenes (Yago)
            'ptr_tbl_pos': 0x1B8200,
            'tbl_len': 0x26,
            'table_name': 'dialog-4'
        },
        {   # supplementary dialog (recruitment scenes, etc.)
            'ptr_tbl_pos': 0x1B8300,
            'tbl_len': 0xD0,
            'table_name': 'dialog-5'
        },
        {   # quiz/trivia questions
            'ptr_tbl_pos': 0x030800,
            'tbl_len': 0xC0,
            'table_name': 'quiz-text'
        },
        {   # field NPC messages
            'ptr_tbl_pos': 0x01BD00,
            'tbl_len': 0x42,
            'table_name': 'field-msg'
        },
        {   # battle menu prompts
            'ptr_tbl_pos': 0x013100,
            'tbl_len': 0x24,
            'table_name': 'battle-menu'
        },
        {   # battle messages (spell/item use, status effects)
            'ptr_tbl_pos': 0x013200,
            'tbl_len': 0x70,
            'table_name': 'battle-msg'
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
                    out_addr_type: int = 4, ptr_addr_type: int = SFCAddressType.LOROM1, ptr_format: int = 0,
                    **kwargs):
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
            if kwargs.get('event_script', False):
                dump_event_script(f'./{out_folder}/{table_name}.txt', bin_list, tbl)
            else:
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


def interpret_event_script(bin_data, tbl):
    """
    Interpret binary data that mixes event bytecode with embedded text.
    Event bytecode is wrapped in {XX} notation, text is decoded through the table.

    Detection strategy:
    - Multi-byte FF-prefix sequences are always decoded as control codes
    - Once a text marker is found ([msg], [special], or 0x92 「), switch to text mode
    - In text mode, decode through the table normally
    - Text mode ends at 0x00 (end) or when data runs out
    - Before any text marker, output bytes as {XX} raw hex
    - Pure text entries (most bytes >= 0x20) are decoded entirely as text

    :param bin_data: list of byte values
    :param tbl: Table instance for character lookups
    :return: string representation
    """
    if not bin_data:
        return ''

    # Multi-byte control code sequences (FF-prefix) that we always recognize
    ff_controls = {
        (0xFF, 0x7F, 0x02): '[msg]\n',
        (0xFF, 0xFD, 0x02): '[special]',
        (0xFF, 0xFF, 0x00): '[cls]\n',
        (0xFF, 0xFB, 0x00): '[white]',
        (0xFF, 0xFB, 0x01): '[pink]',
    }

    # Single-byte text markers and controls
    text_controls = {
        0x00: '[end]\n',
        0x09: '[u]',
        0x0A: '[d]',
        0x10: '[P]',
        0x11: '[R]',
        0x12: '[S]',
        0x13: '[E]',
        0x14: '[K]',
        0x15: '[A]',
        0x16: '[G]',
        0x17: '[Y]',
        0x1B: '!!',
        0x1C: '...',
        0x1E: '[cry]',
        0x1F: '[luv]',
        0x90: '[nl]\n',
        0x91: '[pause][cls]\n',  # acts as 。 in text but functionally pause+cls
        0x92: '「',
        0x93: '」',
    }

    # Determine if this entry is primarily text or event bytecode.
    # Strategy: find where text begins by looking for structural markers.
    has_text_markers = any(b in (0x90, 0x91, 0x92, 0x93) for b in bin_data)

    # Find first text marker position (FF7F02 [msg] or FFFD02 [special])
    msg_pos = -1
    for i in range(len(bin_data) - 2):
        if bin_data[i] == 0xFF:
            triple = (bin_data[i], bin_data[i+1], bin_data[i+2])
            if triple in [(0xFF, 0x7F, 0x02), (0xFF, 0xFD, 0x02)]:
                msg_pos = i
                break

    # Find [P] (0x10) that may precede the [msg]/[special]
    p_pos = -1
    if msg_pos > 0:
        for i in range(msg_pos - 1, -1, -1):
            if bin_data[i] == 0x10:
                p_pos = i
                break

    # Determine text start position:
    # - If [P][msg]/[special] found: text starts at [P], everything before is event code
    # - If no [msg]/[special] but has text markers (0x90-0x93): treat as pure text
    # - If no text markers at all: treat as pure event bytecode
    if msg_pos >= 0:
        event_end = p_pos if p_pos >= 0 else msg_pos
        is_text_entry = (event_end == 0)  # text entry only if text starts at byte 0
    elif has_text_markers:
        event_end = 0
        is_text_entry = True
    else:
        event_end = 0
        is_text_entry = False

    result = ''
    i = 0
    in_text_mode = is_text_entry

    while i < len(bin_data):
        # Switch to text mode when we reach the text portion
        if not in_text_mode and i >= event_end and event_end > 0:
            in_text_mode = True

        b = bin_data[i]

        # Check for FF-prefix control codes (always recognized)
        if b == 0xFF and i + 2 < len(bin_data):
            triple = (bin_data[i], bin_data[i+1], bin_data[i+2])
            if triple in ff_controls:
                result += ff_controls[triple]
                i += 3
                in_text_mode = True  # text follows control codes
                continue

            # FFF2XX = [waitXX] or [pause]
            if bin_data[i+1] == 0xF2:
                val = bin_data[i+2]
                if val == 0x78:
                    result += '[pause]'
                else:
                    result += f'[wait{val:02X}]'
                i += 3
                continue

            # FFC0XX, FFFEXX, FFFCXX = other known controls
            # Generic FF-prefix: output as [FFXXYY]
            result += f'[FF{bin_data[i+1]:02X}{bin_data[i+2]:02X}]'
            i += 3
            continue

        # End marker
        if b == 0x00:
            result += '[end]\n'
            i += 1
            continue

        # In text mode: decode through table
        if in_text_mode:
            # Known single-byte text controls
            if b in text_controls:
                result += text_controls[b]
                i += 1
                continue

            # Try 3-byte table lookup first
            if i + 2 < len(bin_data):
                val_3byte = (b << 16) | (bin_data[i+1] << 8) | bin_data[i+2]
                char = tbl.get_chars(val_3byte, False)
                if char:
                    result += char
                    i += 3
                    continue

            # Try 2-byte table lookup (kanji and other multi-byte chars)
            if i + 1 < len(bin_data):
                val_2byte = (b << 8) | bin_data[i+1]
                char = tbl.get_chars(val_2byte, False)
                if char:
                    result += char
                    i += 2
                    continue

            # Single byte table lookup
            char = tbl.get_chars(b, False)
            if char:
                result += char
                i += 1
                continue

            # Unknown byte in text mode
            result += f'[{b:02X}]'
            i += 1
            continue

        # In event code mode: output as raw hex
        result += '{' + f'{b:02X}' + '}'
        i += 1

    return result


def dump_event_script(filename, dict_data, tbl, deduplicate=True):
    """
    Dump event script data with smart bytecode/text separation.
    :param filename: output file path
    :param dict_data: list of dicts with 'id', 'addr', 'data' keys
    :param tbl: Table instance
    :param deduplicate: skip duplicate addresses
    """
    line1 = True
    nl = "\n"
    enc = tbl.encoding if tbl else 'utf-8'
    with open(filename, 'w', encoding=enc) as of:
        dumped_addrs = []
        for data in dict_data:
            of.write(f"{'' if line1 else nl}<<{data.get('id')}>>{nl}")
            addr = data.get('addr', None)
            if deduplicate and addr is not None:
                if addr not in dumped_addrs:
                    dumped_addrs.append(addr)
                    of.write(interpret_event_script(data['data'], tbl))
            else:
                of.write(interpret_event_script(data['data'], tbl))
            line1 = False


def encode_text(text_str, tbl):
    """
    Encode a text string to bytes using a Table object.
    Handles control codes like [nl], [pause], [cls], [end], [waitXX], [FFXXYY].
    :param text_str: the text to encode
    :param tbl: Table instance with character mappings
    :return: bytes
    """
    # Direct control code mapping (bypasses Table lookup issues)
    control_codes = {
        '[end]': b'\x00',
        '[nl]': b'\x90',
        '[pause][cls]': b'\x91',
        '[pause]': b'\xFF\xF2\x78',
        '[cls]': b'\xFF\xFF\x00',
        '[msg]': b'\xFF\x7F\x02',
        '[special]': b'\xFF\xFD\x02',
        '[white]': b'\xFF\xFB\x00',
        '[pink]': b'\xFF\xFB\x01',
        '[FFFE00]': b'\xFF\xFE\x00',
        '[P]': b'\x10',
        '[R]': b'\x11',
        '[S]': b'\x12',
        '[E]': b'\x13',
        '[K]': b'\x14',
        '[A]': b'\x15',
        '[G]': b'\x16',
        '[Y]': b'\x17',
        '[u]': b'\x09',
        '[d]': b'\x0A',
        '[cry]': b'\x1E',
        '[luv]': b'\x1F',
        '[~]': b'\xFE',
        '!!': b'\x1B',
        '[r.]': b'\x0B',   # if used
        '[D0]': b'\x0C',   # if used
    }

    import re

    result = bytearray()
    i = 0
    while i < len(text_str):
        # Try control codes first (longest match)
        matched = False
        for length in range(min(15, len(text_str) - i), 1, -1):
            substr = text_str[i:i+length]
            if substr in control_codes:
                result.extend(control_codes[substr])
                i += length
                matched = True
                break

        if matched:
            continue

        # Try [waitXX] pattern
        m = re.match(r'\[wait([0-9A-Fa-f]{2})\]', text_str[i:])
        if m:
            val = int(m.group(1), 16)
            result.extend(b'\xFF\xF2')
            result.append(val)
            i += m.end()
            continue

        # Try [FFXXYY] hex pattern
        m = re.match(r'\[FF([0-9A-Fa-f]{4})\]', text_str[i:])
        if m:
            result.append(0xFF)
            result.append(int(m.group(1)[:2], 16))
            result.append(int(m.group(1)[2:], 16))
            i += m.end()
            continue

        # Try [XX] single hex byte pattern
        m = re.match(r'\[([0-9A-Fa-f]{2})\]', text_str[i:])
        if m:
            result.append(int(m.group(1), 16))
            i += m.end()
            continue

        ch = text_str[i]

        # Skip newlines and carriage returns
        if ch in '\n\r':
            i += 1
            continue

        # Space
        if ch == ' ':
            result.append(0x20)
            i += 1
            continue

        # Skip fullwidth/unicode chars
        if ord(ch) > 0x2000:
            i += 1
            continue

        # Table lookup for regular characters
        val = tbl.get_value(ch, infer_value=False)
        if val is not None:
            result.append(val & 0xFF)
        else:
            # Direct ASCII if in printable range
            if 0x20 <= ord(ch) <= 0x7E:
                result.append(ord(ch))
            else:
                result.append(0x3F)  # '?' fallback
        i += 1

    # Ensure terminated with 0x00 if not already
    if not result or result[-1] != 0x00:
        result.append(0x00)

    return bytes(result)


def insert_script(input_filename, output_filename, script_file, table_filename,
                  ptr_tbl_pos, tbl_len, ptr_bank=None, ptr_addr_type=None):
    """
    Insert translated text back into the ROM by encoding text and updating pointers.
    :param input_filename: source ROM
    :param output_filename: output ROM
    :param script_file: translated text file path
    :param table_filename: character table file path
    :param ptr_tbl_pos: PC address of pointer table
    :param tbl_len: byte length of pointer table
    :param ptr_bank: bank byte for pointers (auto-detected if None)
    :param ptr_addr_type: address type for pointer conversion
    """
    from RetroTool.snes import SFCAddress, SFCAddressType
    from RetroTool.script import Table

    if ptr_addr_type is None:
        ptr_addr_type = SFCAddressType.LOROM1

    with open(input_filename, 'rb') as f:
        rom = bytearray(f.read())

    tbl = Table(table_filename)

    # Determine bank from pointer table position
    ptr_table_addr = SFCAddress(ptr_tbl_pos)
    if ptr_bank is None:
        ptr_bank = ptr_table_addr.get_bank_byte(ptr_addr_type)

    # Read translated text
    try:
        with open(script_file, 'r', encoding='utf-16') as f:
            text = f.read()
    except UnicodeDecodeError:
        with open(script_file, 'r', encoding='utf-8') as f:
            text = f.read()

    # Parse entries
    entries = text.split('<<')[1:]
    encoded_entries = []
    for entry in entries:
        if '>>' not in entry:
            continue
        content = entry.split('>>')[1]
        # Don't strip - preserve newlines for control code matching
        # But remove leading newline (artifact of format)
        if content.startswith('\n'):
            content = content[1:]
        # Remove trailing whitespace after [end]
        content = content.rstrip()
        if not content or content == '[end]':
            encoded_entries.append(b'\x00')
        else:
            encoded = encode_text(content, tbl)
            encoded_entries.append(encoded)

    # Calculate data placement
    num_ptrs = tbl_len // 2
    data_start_pc = ptr_tbl_pos + tbl_len  # Text data goes right after pointer table

    # Calculate total data size
    total_size = sum(len(e) for e in encoded_entries)
    bank_end = ((ptr_tbl_pos // 0x8000) + 1) * 0x8000  # End of current bank

    if data_start_pc + total_size > bank_end:
        print(f'WARNING: Text data ({total_size} bytes) exceeds bank boundary!')
        print(f'  Available: {bank_end - data_start_pc} bytes')
        print(f'  Overflow: {data_start_pc + total_size - bank_end} bytes')
        # For now, allow overflow into next bank (works in expanded ROM)

    # Write encoded data and build pointer table
    data_offset = 0
    new_ptrs = []
    for i, encoded in enumerate(encoded_entries):
        # Calculate SNES address for this text entry
        pc = data_start_pc + data_offset
        snes_addr = SFCAddress(pc)
        ptr_val = snes_addr.get_address(ptr_addr_type) & 0xFFFF

        new_ptrs.append(ptr_val)

        # Write encoded text to ROM
        rom[pc:pc + len(encoded)] = encoded
        data_offset += len(encoded)

    # Write pointer table
    for i, ptr in enumerate(new_ptrs):
        if i >= num_ptrs:
            break
        offset = ptr_tbl_pos + i * 2
        rom[offset] = ptr & 0xFF
        rom[offset + 1] = (ptr >> 8) & 0xFF

    # Write output
    with open(output_filename, 'wb') as f:
        f.write(rom)

    print(f'Inserted {len(encoded_entries)} entries ({total_size} bytes) at 0x{data_start_pc:X}')
    print(f'Pointer table updated at 0x{ptr_tbl_pos:X}')


def convert_font_to_1bppil(image_path, output_path, rom_path=None, rom_offset=0x170000):
    """
    Convert an 8x16 font PNG to the LM3 1BPP-IL ROM format and optionally patch a ROM.

    LM3 1BPP-IL format (per 8x16 character, 16 bytes):
      Even bytes (0,2,4,...14) = top 8x8 tile rows 0-7
      Odd bytes  (1,3,5,...15) = bottom 8x8 tile rows 0-7
    The ROM loader writes each byte to BOTH VRAM data ports ($2118/$2119),
    so bp0==bp1 automatically in VRAM.

    Output is 8192 bytes: 4096 normal + 4096 inverted (XOR $FF).
    The inverted set is used for menus and scenario screens.

    :param image_path: path to the font PNG (grid of 8x16 glyphs)
    :param output_path: path to write the 1BPP-IL binary
    :param rom_path: optional ROM file to patch in-place
    :param rom_offset: ROM offset for font data (default 0x170000)
    """
    img = Image.open(image_path).convert('L')
    cols = img.size[0] // 8
    rows = img.size[1] // 16
    num_chars = min(cols * rows, 256)

    # Convert to 1bpp (1 byte per row, 16 rows per char)
    font_1bpp = bytearray()
    for idx in range(num_chars):
        col = idx % cols
        row = idx // cols
        x0, y0 = col * 8, row * 16
        for y in range(16):
            byte = 0
            for x in range(8):
                if img.getpixel((x0 + x, y0 + y)) < 128:
                    byte |= (0x80 >> x)
            font_1bpp.append(byte)

    # Build 1BPP-IL: interleave top/bottom rows
    font_normal = bytearray(4096)
    for char_idx in range(min(num_chars, 256)):
        src = char_idx * 16
        dst = char_idx * 16
        if src + 16 > len(font_1bpp):
            break
        for r in range(8):
            font_normal[dst + r * 2] = font_1bpp[src + r]          # top row (even byte)
            font_normal[dst + r * 2 + 1] = font_1bpp[src + 8 + r]  # bottom row (odd byte)

    # Shift by 1 tile (16 bytes) to match the game's tile indexing
    font_normal = bytearray(16) + font_normal[:-16]

    # Build inverted version (XOR 0xFF)
    font_inverted = bytearray(b ^ 0xFF for b in font_normal)

    # Combine normal + inverted
    font_full = font_normal + font_inverted

    # Save binary
    with open(output_path, 'wb') as f:
        f.write(font_full)
    print(f'Saved font ({num_chars} chars, {len(font_full)} bytes) to {output_path}')

    # Optionally patch ROM
    if rom_path:
        with open(rom_path, 'rb') as f:
            rom = bytearray(f.read())
        rom[rom_offset:rom_offset + len(font_full)] = font_full
        with open(rom_path, 'wb') as f:
            f.write(rom)
        print(f'Patched ROM at 0x{rom_offset:X}')


def get_character_widths(image_path):
    # Open the image
    img = Image.open(image_path)

    # Define tile size
    tile_width = 8
    tile_height = 16

    # Image dimensions
    img_width, img_height = img.size

    # Initialize a list to store the character widths
    character_widths = []

    # Loop through the image in 8x16 pixel blocks
    for x in range(1, img_width, tile_width):
        # Crop the current 8x16 pixel block
        tile = img.crop((x, 0, x + tile_width, tile_height))

        # Check if the tile is empty (all pixels are white)
        if tile.getextrema() == (255, 255):
            character_widths.append(5)  # Empty space is 5
        else:
            # Find the leftmost non-white pixel in the tile
            leftmost_pixel = next((i for i, value in enumerate(tile.getdata()) if value < 255), None)

            # Calculate the character width in pixels
            character_width = leftmost_pixel % tile_width

            character_widths.append(character_width)

    return character_widths
