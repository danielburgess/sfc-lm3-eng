from retrotool.snes import SFCAddress, SFCAddressType
from retrotool.script import Table
from PIL import Image

"""
Little Master 3 English Script Dumper and Inserter
TODO: Work on font.
      Finish event script dump if possible.
      VWF?
      Test inserting current script.
      Rewrite DTE script/Table for event script use.
"""


# ============================================================================
# LoROM Address Conversion Utilities
# ============================================================================
# LoROM layout: SNES banks $00-$3F / $80-$BF, addresses $8000-$FFFF map to ROM.
#   PC  -> SNES:  bank = (pc >> 15) & 0x7F,  addr = (pc & 0x7FFF) | 0x8000
#   SNES -> PC:   pc   = (bank & 0x7F) * 0x8000 + (addr - 0x8000)
#
# "lorom1" = banks $00-$3F  (mirror bit 23 clear)
# "lorom2" = banks $80-$BF  (mirror bit 23 set, fast ROM region)

def pc_to_snes(pc: int, fast: bool = False) -> int:
    """PC file offset -> 24-bit SNES LoROM address.
    fast=True returns $80-$BF bank (fast ROM mirror)."""
    bank = (pc >> 15) & 0x7F
    addr = (pc & 0x7FFF) | 0x8000
    if fast:
        bank |= 0x80
    return (bank << 16) | addr

def snes_to_pc(snes: int) -> int:
    """24-bit SNES LoROM address -> PC file offset."""
    bank = (snes >> 16) & 0x7F
    addr = snes & 0xFFFF
    return bank * 0x8000 + (addr - 0x8000)

def snes_bank(snes: int) -> int:
    """Extract bank byte from a 24-bit SNES address."""
    return (snes >> 16) & 0xFF

def snes_addr(snes: int) -> int:
    """Extract 16-bit address from a 24-bit SNES address."""
    return snes & 0xFFFF

def pc_to_snes_bytes(pc: int, fast: bool = False) -> bytes:
    """PC offset -> 3 bytes [lo, hi, bank] suitable for ROM insertion."""
    s = pc_to_snes(pc, fast)
    return bytes([s & 0xFF, (s >> 8) & 0xFF, (s >> 16) & 0xFF])

def fmt_snes(snes: int) -> str:
    """Format a 24-bit SNES address as '$BB:AAAA'."""
    return f'${snes >> 16:02X}:${snes & 0xFFFF:04X}'

def fmt_pc(pc: int) -> str:
    """Format a PC offset as '0xNNNNNN'."""
    return f'0x{pc:06X}'


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
            'event_script': False
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
        {   # supplementary character dialog (Charley, Momo, etc.)
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

    # Pre-compute all pointer targets for bounding entries
    all_data_starts = []
    for i in range(ptr_tbl_loc, ptr_tbl_loc + ptr_tbl_len, ptr_bytes + ptr_format):
        add_len = fmt_length[ptr_format]
        ptr_end = (i + add_len) + ptr_bytes
        this_ptr_data = bin_data[(i + add_len): ptr_end]
        ptr = SFCAddress([this_ptr_data[0], this_ptr_data[1], ptr_bank], ptr_addr_type)
        all_data_starts.append(ptr.get_address(SFCAddressType.PC))
    sorted_unique_addrs = sorted(set(all_data_starts))

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
            # Use next unique pointer address as upper bound to prevent over-scanning
            addr_idx = sorted_unique_addrs.index(data_start) if data_start in sorted_unique_addrs else -1
            max_addr = sorted_unique_addrs[addr_idx + 1] if addr_idx >= 0 and addr_idx + 1 < len(sorted_unique_addrs) else None
            data_end = tbl.find_entry_end(bin_data, data_start, max_addr=max_addr)
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
    with open(filename, 'w', encoding='utf-16') as of:
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


def _int_to_bytes_be(val):
    """Convert an integer to big-endian bytes (e.g. 0xFFF278 → b'\\xFF\\xF2\\x78')."""
    if val == 0:
        return b'\x00'
    out = []
    v = val
    while v > 0:
        out.append(v & 0xFF)
        v >>= 8
    out.reverse()
    return bytes(out)


def hexify_text(text, jp_tbl, en_tbl):
    """
    Convert untranslated Japanese characters in text to hex byte placeholders.
    Characters mapped in jap.tbl but NOT in eng.tbl are converted to [XX] format.
    Bracket escapes like [end], [FF7F01], [FFC000] are preserved as-is.
    :param text: the text string
    :param jp_tbl: Table instance for jap.tbl
    :param en_tbl: Table instance for eng.tbl
    :return: converted text string
    """
    jp_map = jp_tbl._Table__chr_map
    en_map = en_tbl._Table__chr_map

    result = []
    i = 0
    while i < len(text):
        ch = text[i]

        # Preserve bracket escapes as-is
        if ch == '[':
            close = text.find(']', i + 1)
            if close != -1:
                result.append(text[i:close + 1])
                i = close + 1
                continue

        # Preserve entry headers <<...>>
        if ch == '<' and i + 1 < len(text) and text[i + 1] == '<':
            close = text.find('>>', i + 2)
            if close != -1:
                result.append(text[i:close + 2])
                i = close + 2
                continue

        # Preserve ASCII, newlines, and characters in eng.tbl
        if ch in '\n\r' or (0x20 <= ord(ch) <= 0x7E) or ch in en_map:
            result.append(ch)
            i += 1
            continue

        # Try longest match in jap.tbl (multi-char entries like !! or (ぇ))
        matched = False
        for length in range(3, 0, -1):
            substr = text[i:i + length]
            val = jp_map.get(substr)
            if val is not None:
                hex_str = _int_to_bytes_be(val).hex().upper()
                if len(hex_str) % 2:
                    hex_str = '0' + hex_str
                result.append(f'[{hex_str}]')
                i += length
                matched = True
                break

        if not matched:
            # Unknown character — emit as Unicode escape
            result.append(f'[?{ord(ch):04X}]')
            i += 1

    return ''.join(result)


def hexify_en_files(en_folder, jp_table_path='jap.tbl', en_table_path='eng.tbl',
                    tables_filter=None):
    """
    Convert remaining Japanese text in English dump files to hex byte placeholders.
    :param en_folder: path to English text files
    :param jp_table_path: Japanese table file
    :param en_table_path: English table file
    :param tables_filter: optional list of table names to process
    """
    import os
    jp_tbl = Table(jp_table_path)
    en_tbl = Table(en_table_path)

    # Process all .txt files in the folder
    txt_files = sorted(f for f in os.listdir(en_folder) if f.endswith('.txt'))
    for txt_file in txt_files:
        name = txt_file[:-4]  # strip .txt
        if tables_filter and name not in tables_filter:
            continue
        txt_path = os.path.join(en_folder, txt_file)

        # Try UTF-16 first, fall back to detected encoding
        try:
            with open(txt_path, encoding='utf-16') as f:
                content = f.read()
            enc = 'utf-16'
        except (UnicodeDecodeError, UnicodeError):
            enc = Table.detect_encoding(txt_path)
            with open(txt_path, encoding=enc) as f:
                content = f.read()

        converted = hexify_text(content, jp_tbl, en_tbl)

        if converted != content:
            with open(txt_path, 'w', encoding=enc) as f:
                f.write(converted)
            print(f'  {name}: converted Japanese text to hex placeholders')
        else:
            print(f'  {name}: no changes needed')


def encode_text(text_str, tbl, fallback_tbl=None):
    """
    Encode a text string to bytes using the Table's character map.
    All control codes and character mappings come from the table file —
    nothing is hardcoded here.
    :param text_str: the text to encode
    :param tbl: Table instance with character mappings (primary, e.g. eng.tbl)
    :param fallback_tbl: optional fallback Table (e.g. jap.tbl) for characters
                         not in the primary table — used to pass through
                         untranslated Japanese text as raw bytes
    :return: bytes
    """
    # Build a lookup from the Table's char_map, sorted longest-key-first
    # so multi-char sequences like [pause], !!, etc. match before singles.
    # Access the private map (Table doesn't expose it directly).
    char_map = tbl._Table__chr_map
    fb_map = fallback_tbl._Table__chr_map if fallback_tbl else {}

    # Pre-compute bytes for each entry and sort by descending key length
    lookup = []
    for ch, val in char_map.items():
        lookup.append((ch, _int_to_bytes_be(val)))
    lookup.sort(key=lambda x: len(x[0]), reverse=True)

    max_key_len = max(len(k) for k, _ in lookup) if lookup else 1

    # Also compute max key length for fallback table
    fb_max_key_len = max((len(k) for k in fb_map), default=1) if fb_map else 1

    result = bytearray()
    i = 0
    while i < len(text_str):
        ch = text_str[i]

        # Skip newlines and carriage returns (format artifacts, not game data)
        if ch in '\n\r':
            i += 1
            continue

        # Longest-match against the primary table — multi-char matches always preferred.
        matched = False
        for length in range(min(max_key_len, len(text_str) - i), 0, -1):
            substr = text_str[i:i + length]
            val = char_map.get(substr)
            if val is not None:
                result.extend(_int_to_bytes_be(val))
                i += length
                matched = True
                break

        if matched:
            continue

        # Hex escape: [XX], [XXXX], [XXXXXX] — raw byte emission for values
        # not in the character table (e.g. [08] for unmapped byte 0x08)
        if ch == '[':
            close = text_str.find(']', i + 1)
            if close != -1:
                hex_str = text_str[i + 1:close]
                if len(hex_str) in (2, 4, 6, 8) and all(c in '0123456789ABCDEFabcdef' for c in hex_str):
                    result.extend(bytes.fromhex(hex_str))
                    i = close + 1
                    continue

        # Fallback table: look up untranslated characters (e.g. Japanese)
        if fb_map:
            fb_matched = False
            for length in range(min(fb_max_key_len, len(text_str) - i), 0, -1):
                substr = text_str[i:i + length]
                val = fb_map.get(substr)
                if val is not None:
                    result.extend(_int_to_bytes_be(val))
                    i += length
                    fb_matched = True
                    break
            if fb_matched:
                continue

        # Fallback: printable ASCII → identity, else '?'
        if 0x20 <= ord(ch) <= 0x7E:
            result.append(ord(ch))
        else:
            result.append(0x3F)  # '?'
        i += 1

    return bytes(result)


def insert_script(input_filename, output_filename, script_file, table_filename,
                  ptr_tbl_pos, tbl_len, ptr_bank=None, ptr_addr_type=None,
                  fallback_table=None):
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
    from retrotool.snes import SFCAddress, SFCAddressType
    from retrotool.script import Table

    if ptr_addr_type is None:
        ptr_addr_type = SFCAddressType.LOROM1

    with open(input_filename, 'rb') as f:
        rom = bytearray(f.read())

    tbl = Table(table_filename)
    fb_tbl = Table(fallback_table) if fallback_table else None

    # Determine bank from pointer table position
    ptr_table_addr = SFCAddress(ptr_tbl_pos)
    if ptr_bank is None:
        ptr_bank = ptr_table_addr.get_bank_byte(ptr_addr_type)

    # Read translated text (detect encoding — JP dumps are UTF-16-LE without BOM)
    script_enc = Table.detect_encoding(script_file)
    try:
        with open(script_file, 'r', encoding=script_enc) as f:
            text = f.read()
    except (UnicodeDecodeError, TypeError):
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
            encoded = encode_text(content, tbl, fallback_tbl=fb_tbl)
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


def convert_font_to_1bppil(image_path, output_path, rom_path=None, rom_offset=0x170000,
                           sequential_output_path=None):
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
    :param sequential_output_path: optional path to save sequential 1bpp binary (for VWF)
    """
    img = Image.open(image_path).convert('L')
    cols = img.size[0] // 8
    rows = img.size[1] // 16
    num_chars = min(cols * rows, 256)

    # Convert to 1bpp sequential (1 byte per row, 16 rows per char: 8 top + 8 bottom)
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

    # Save sequential 1bpp for VWF if requested
    if sequential_output_path:
        with open(sequential_output_path, 'wb') as f:
            f.write(font_1bpp)
        print(f'Saved sequential 1bpp ({num_chars} chars, {len(font_1bpp)} bytes) to {sequential_output_path}')

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


def get_character_widths(image_path, spacing=1):
    """
    Compute per-character pixel widths from a font PNG for VWF use.

    Width = rightmost pixel column + 1 + spacing.
    Empty tiles get width 0. Space character (index 0x20) gets a default width.

    :param image_path: path to the font PNG (grid of 8x16 glyphs)
    :param spacing: extra pixels after the rightmost pixel (default 1)
    :return: list of widths, one per character in the grid
    """
    img = Image.open(image_path).convert('L')
    tile_width = 8
    tile_height = 16
    cols = img.size[0] // tile_width
    rows = img.size[1] // tile_height
    num_chars = cols * rows

    character_widths = []
    for idx in range(num_chars):
        col = idx % cols
        row = idx // cols
        x0, y0 = col * tile_width, row * tile_height

        # Find rightmost non-white pixel column
        rightmost = -1
        for py in range(tile_height):
            for px in range(tile_width - 1, -1, -1):
                if img.getpixel((x0 + px, y0 + py)) < 128:
                    rightmost = max(rightmost, px)
                    break

        if rightmost < 0:
            character_widths.append(0)
        else:
            character_widths.append(min(rightmost + 1 + spacing, 8))

    # The font ROM data is shifted by 1 tile (convert_font_to_1bppil prepends
    # 16 zero bytes), so PNG tile 0 = ROM tile 1.  Shift widths to match.
    character_widths = [0] + character_widths[:-1]

    return character_widths


def font_width_preview(font_bin_path='font/bin/font_accented_1bpp.bin',
                       widths_bin_path='font/font_accented_widths.bin',
                       table_path='eng.tbl', output_path='font/font_accented_preview.png',
                       scale=3, chars_per_row=16, first_char=0x00, last_char=0xF0):
    """
    Generate a visual preview of the VWF font with width boundaries.

    Each character cell shows:
      - The glyph rendered from font_1bpp.bin (white pixels)
      - A light blue vertical line at the leftmost pixel column
      - A red vertical line at the width boundary (from widths.bin)
      - The width value (green) and table character (gray) below

    Font indexing: VWFFontData = 16 zero bytes + font_1bpp.bin,
    so char N -> font_1bpp.bin[(N-1)*16].

    :param font_bin_path: path to sequential 1bpp font binary
    :param widths_bin_path: path to character widths binary
    :param table_path: path to character encoding table (.tbl)
    :param output_path: path to save the preview PNG
    :param scale: pixel scale factor (default 3)
    :param chars_per_row: characters per row in the grid
    :param first_char: first character code to display
    :param last_char: last character code (exclusive)
    """
    from PIL import ImageDraw

    with open(font_bin_path, 'rb') as f:
        font_data = f.read()
    with open(widths_bin_path, 'rb') as f:
        widths = f.read()

    # Parse encoding table
    tbl = {}
    with open(table_path, 'r') as f:
        for line in f:
            line = line.strip()
            if '=' in line and len(line) >= 3:
                try:
                    code = int(line[:2], 16)
                    tbl[code] = line[3:]
                except ValueError:
                    pass

    num_chars = last_char - first_char
    num_rows = (num_chars + chars_per_row - 1) // chars_per_row

    cell_w = 12 * scale
    cell_h = 26 * scale
    img_w = chars_per_row * cell_w
    img_h = num_rows * cell_h

    img = Image.new('RGB', (img_w, img_h), (20, 20, 30))
    draw = ImageDraw.Draw(img)

    for i in range(num_chars):
        char_code = first_char + i
        # VWFFontData = 16 zero bytes + font_1bpp.bin
        # char N -> font_1bpp.bin[(N-1)*16], char 0 = all zeros (padding)
        font_off = (char_code - 1) * 16
        has_font = 0 <= font_off and font_off + 16 <= len(font_data)

        col = i % chars_per_row
        row = i // chars_per_row
        x0 = col * cell_w + 2 * scale
        y0 = row * cell_h + scale

        w = widths[char_code] if char_code < len(widths) else 0

        if has_font:
            # Draw glyph at scale
            for py in range(16):
                byte = font_data[font_off + py]
                for px in range(8):
                    if byte & (0x80 >> px):
                        for sy in range(scale):
                            for sx in range(scale):
                                img.putpixel((x0 + px * scale + sx, y0 + py * scale + sy), (255, 255, 255))

            # Draw left bound at column 0 (light blue vertical line)
            if w > 0:
                for py in range(16 * scale):
                    for sx in range(max(1, scale // 2)):
                        px_pos = x0 - max(1, scale // 2)
                        if px_pos >= col * cell_w:
                            img.putpixel((px_pos + sx, y0 + py), (100, 180, 255))

            # Draw width boundary (red vertical line)
            if 0 < w <= 8:
                for py in range(16 * scale):
                    for sx in range(max(1, scale // 2)):
                        img.putpixel((x0 + w * scale + sx, y0 + py), (255, 50, 50))

        # Labels: width (green), then table character (gray)
        label_y = y0 + 16 * scale + 4
        ch = tbl.get(char_code, '')
        draw.text((x0, label_y), f'{w} {ch}', fill=(0, 255, 0))
        draw.text((x0, label_y + 14), f'${char_code:02X}', fill=(120, 120, 140))

    img.save(output_path)
    print(f'Font width preview ({num_chars} chars) saved to {output_path}')


# ============================================================================
# Build system
# ============================================================================

# Tables that can be inserted with insert_table_into_rom.
# script_ext and unit-equipment require special handling and are not listed here.
SCRIPT_TABLES = [
    # Main dialog script: relocated to bank $C1 (PC $208000) with 3-byte SNES pointers.
    # This bypasses the 32 KB bank-$B6 limit and lets the EN text span into $C2+.
    # Requires the TextPtrDispatch patch and meta-table patch in script_patch.asm.
    {'name': 'script',           'ptr_tbl_pos': 0x208000, 'tbl_len': 0x600, 'ptr_size': 3},
    # Dialog tables: ptr tables live at $1B8000-$1B83CF; ALL text is packed
    # sequentially from DIALOG_TEXT_BASE ($1B83D0) to avoid overlap.
    {'name': 'dialog-2',         'ptr_tbl_pos': 0x1B8000, 'tbl_len': 0x188},
    {'name': 'dialog-3',         'ptr_tbl_pos': 0x1B8100, 'tbl_len': 0x088},
    {'name': 'dialog-4',         'ptr_tbl_pos': 0x1B8200, 'tbl_len': 0x026},
    {'name': 'dialog-5',         'ptr_tbl_pos': 0x1B8300, 'tbl_len': 0x0D0},
    # scenario-desc: relocated to $C3:$8000 (3-byte ptrs). EN text (10840 bytes)
    # overflows JP space (6732 bytes) into adjacent ptr tables in bank $22.
    # Meta-table entries 2, 11, 12 patched in script_patch.asm.
    # 158 entries × 3 bytes = 0x1DA.
    {'name': 'scenario-desc',    'ptr_tbl_pos': 0x218000, 'tbl_len': 0x1DA, 'ptr_size': 3,
                                  'orig_blank': [(0x111EE3, 0x113A6B)]},
    # unit-terrain-desc: JP data at $030A00. EN text (27 KB) overflows the 32 KB half-bank
    # so this must be relocated to expanded area in a future step.
    {'name': 'unit-terrain-desc','ptr_tbl_pos': 0x030000, 'tbl_len': 0x500,
                                  'data_start_pc': 0x030A00},
    # unit-attacks: JP data starts at $1B1200 (gap between ptrs and data has other data).
    {'name': 'unit-attacks',     'ptr_tbl_pos': 0x1B0800, 'tbl_len': 0x06A,
                                  'data_start_pc': 0x1B1200},
    # quiz-text: relocated to expanded area (was $06:$8800, overflowed by unit-terrain-desc).
    # Meta-table entry 15 patched in script_patch.asm to point to $C2:$9700.
    # 96 entries × 3 bytes = 0x120 for the pointer table.
    {'name': 'quiz-text',        'ptr_tbl_pos': 0x211700, 'tbl_len': 0x120, 'ptr_size': 3,
                                  'orig_blank': [(0x030800, 0x0308C0),   # old ptr table
                                                 (0x035AE0, 0x036ED2)]}, # old text data
    # field-msg: JP data starts at $01F2B7 (gap has game data, must not overwrite).
    {'name': 'field-msg',        'ptr_tbl_pos': 0x01BD00, 'tbl_len': 0x042,
                                  'data_start_pc': 0x01F2B7},
    # battle-menu: JP data at $013520. battle-msg: JP data at $014E36.
    # No overlap between them — separate regions in the same bank.
    {'name': 'battle-menu',      'ptr_tbl_pos': 0x013100, 'tbl_len': 0x024,
                                  'data_start_pc': 0x013520},
    {'name': 'battle-msg',       'ptr_tbl_pos': 0x013200, 'tbl_len': 0x070,
                                  'data_start_pc': 0x014E36},
]

# All four dialog ptr tables end by $1B83D0; pack dialog text from here.
DIALOG_TEXT_BASE = 0x1B83D0


def build_font(font_png='font/font_accented.png', force=False):
    """
    Generate all font binary files needed by the build.

    Produces (in font/bin/):
      {name}_1bppil.bin  — 8192-byte 1BPP-IL ROM format (normal + inverted)
      {name}_1bpp.bin    — sequential 1BPP for VWF incbin
      {name}_widths.bin  — per-character pixel widths for VWF
      {name}.checksum    — SHA-256 of input PNG for cache invalidation

    Where {name} is the input filename stem (e.g. font_accented).
    """
    import hashlib, os

    font_dir = os.path.dirname(font_png) or 'font'
    cache_dir = os.path.join(font_dir, 'bin')
    os.makedirs(cache_dir, exist_ok=True)

    stem = os.path.splitext(os.path.basename(font_png))[0]
    il_path = os.path.join(cache_dir, f'{stem}_1bppil.bin')
    seq_path = os.path.join(cache_dir, f'{stem}_1bpp.bin')
    cksum_path = os.path.join(cache_dir, f'{stem}.checksum')

    widths_path = os.path.join(font_dir, f'{stem}_widths.bin')

    # Checksum covers the PNG + widths file (if it exists).
    h = hashlib.sha256()
    with open(font_png, 'rb') as f:
        h.update(f.read())
    if os.path.exists(widths_path):
        with open(widths_path, 'rb') as f:
            h.update(f.read())
    else:
        h.update(b'__missing__')
    current_checksum = h.hexdigest()

    if not force and os.path.exists(cksum_path):
        with open(cksum_path, 'r') as f:
            cached = f.read().strip()
        if cached == current_checksum and all(
            os.path.exists(p) for p in (il_path, seq_path)
        ):
            print(f'Font cached (unchanged): {font_png}')
            return

    print(f'Building font from {font_png}...')

    if not os.path.exists(widths_path):
        widths = get_character_widths(font_png, spacing=1)
        with open(widths_path, 'wb') as f:
            f.write(bytes(widths[:256]))
        print(f'  Generated {widths_path} ({len(widths[:256])} chars)')
    else:
        print(f'  Using existing {widths_path}')

    convert_font_to_1bppil(
        font_png,
        output_path=il_path,
        sequential_output_path=seq_path,
    )

    with open(cksum_path, 'w') as f:
        f.write(current_checksum)
    print('Font build complete.')


def encode_script_file(script_file: str, table_filename: str,
                       cache_dir: str = None, force: bool = False,
                       fallback_table: str = None) -> list[bytes]:
    """
    Encode a script file into a list of binary entries, one per <<index>> block.

    Uses a bin cache in cache_dir (e.g. en_ptr_data/bin/) to skip re-encoding
    when neither the script file nor the table file have changed.  The cache
    stores:
      {cache_dir}/{name}.bin       — concatenated encoded entries with 4-byte
                                     length prefix per entry
      {cache_dir}/{name}.checksum  — hex digest of (script_file + tbl_file)

    Returns list of encoded byte strings (one per entry, including \\x00 terminator).
    """
    import hashlib, os

    name = os.path.splitext(os.path.basename(script_file))[0]

    # Compute checksum over script + table file + all encoder source files.
    # Any change to the build/encoding logic invalidates every cache entry.
    h = hashlib.sha256()
    src_dir = os.path.dirname(os.path.abspath(__file__))
    source_files = [
        os.path.join(src_dir, 'lm3.py'),
        os.path.join(src_dir, 'retrotool', 'script.py'),
        os.path.join(src_dir, 'retrotool', 'snes.py'),
    ]
    for path in [script_file, table_filename] + source_files:
        with open(path, 'rb') as f:
            h.update(f.read())
    current_checksum = h.hexdigest()

    # Check cache.
    bin_path = cksum_path = None
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        bin_path = os.path.join(cache_dir, f'{name}.bin')
        cksum_path = os.path.join(cache_dir, f'{name}.checksum')

        if not force and os.path.exists(cksum_path) and os.path.exists(bin_path):
            with open(cksum_path, 'r') as f:
                cached_checksum = f.read().strip()
            if cached_checksum == current_checksum:
                encoded_entries = []
                with open(bin_path, 'rb') as f:
                    data = f.read()
                pos = 0
                while pos < len(data):
                    addr = int.from_bytes(data[pos:pos+8], 'little', signed=True)
                    pos += 8
                    if addr == -1:
                        addr = None
                    entry_len = int.from_bytes(data[pos:pos+4], 'little')
                    pos += 4
                    encoded_entries.append((data[pos:pos+entry_len], addr))
                    pos += entry_len
                return encoded_entries

    # Cache miss — encode from scratch.
    tbl = Table(table_filename)
    fb_tbl = Table(fallback_table) if fallback_table else None

    with open(script_file, 'r', encoding='utf-16') as f:
        text = f.read()

    import re

    entries = text.split('<<')[1:]
    encoded_entries = []
    for entry in entries:
        if '>>' not in entry:
            continue
        header = entry.split('>>')[0]
        content = entry.split('>>')[1]
        if content.startswith('\n'):
            content = content[1:]
        content = content.rstrip()

        # Parse original address from header: <<$78336:0[$85558]>>
        orig_addr = None
        addr_match = re.search(r'\[\$(\d+)\]', header)
        if addr_match:
            orig_addr = int(addr_match.group(1))

        if not content or content == '[end]':
            encoded_entries.append((b'\x00', orig_addr))
        else:
            encoded_entries.append((encode_text(content, tbl, fallback_tbl=fb_tbl), orig_addr))

    # Write cache.
    if bin_path:
        with open(bin_path, 'wb') as f:
            for data, addr in encoded_entries:
                # addr as 8-byte signed (-1 for None), then 4-byte len + data
                f.write((addr if addr is not None else -1).to_bytes(8, 'little', signed=True))
                f.write(len(data).to_bytes(4, 'little'))
                f.write(data)
        with open(cksum_path, 'w') as f:
            f.write(current_checksum)

    return encoded_entries


def insert_table_into_rom(rom: bytearray, script_file: str, table_filename: str,
                          ptr_tbl_pos: int, tbl_len: int,
                          ptr_bank: int = None, ptr_addr_type=None,
                          ptr_size: int = 2, data_start_pc: int = None,
                          cache_dir: str = None, force: bool = False,
                          fallback_table: str = None) -> int:
    """
    Encode a translated script file and write it into a ROM bytearray in place.

    :param ptr_size: 2 for standard 16-bit LoROM pointers (bank implicit),
                     3 for 24-bit absolute SNES pointers [lo, hi, bank].
                     When ptr_size=3, tbl_len must be num_entries * 3.
    :param data_start_pc: Override where text data begins in the ROM file.
                          Defaults to ptr_tbl_pos + tbl_len.
                          Use this to skip preserved JP data structures or to
                          pack multiple tables into a shared text region.
    :param cache_dir: Directory for encoded bin cache (e.g. en_ptr_data/bin/).

    Returns total bytes written (text only, not pointer table).
    """
    from retrotool.snes import SFCAddress, SFCAddressType

    if ptr_addr_type is None:
        ptr_addr_type = SFCAddressType.LOROM1

    if ptr_size == 3:
        num_ptrs = tbl_len // 3
    else:
        num_ptrs = tbl_len // 2
        ptr_table_addr = SFCAddress(ptr_tbl_pos)
        if ptr_bank is None:
            ptr_bank = ptr_table_addr.get_bank_byte(ptr_addr_type)

    encoded_entries = encode_script_file(script_file, table_filename,
                                         cache_dir=cache_dir, force=force,
                                         fallback_table=fallback_table)

    if data_start_pc is None:
        data_start_pc = ptr_tbl_pos + tbl_len

    # Only count bytes for entries that will actually be written (skip duplicates).
    # Duplicate-address entries (empty content, same orig_addr as earlier entry)
    # reuse the earlier entry's pointer — no new data written.
    seen_addrs = {}  # orig_addr -> pointer value
    total_size = 0
    for encoded, orig_addr in encoded_entries:
        is_dup = (orig_addr is not None and orig_addr in seen_addrs
                  and encoded == b'\x00')
        if not is_dup:
            total_size += len(encoded)
            if orig_addr is not None:
                seen_addrs[orig_addr] = None  # placeholder, filled during write

    if ptr_size == 2:
        # Bank-boundary check only applies to 2-byte (same-bank) pointers
        bank_end = ((ptr_tbl_pos // 0x8000) + 1) * 0x8000
        if data_start_pc + total_size > bank_end:
            overflow = data_start_pc + total_size - bank_end
            print(f'  WARNING: {script_file} overflows bank by {overflow} bytes')

    # Extend the ROM bytearray to the required size before writing.
    required_size = data_start_pc + total_size
    ptr_tbl_end = ptr_tbl_pos + tbl_len
    required_size = max(required_size, ptr_tbl_end)
    if required_size > len(rom):
        rom.extend(b'\xff' * (required_size - len(rom)))

    # Write encoded data and build pointer table.
    # For duplicate-address entries (empty content, same orig_addr), reuse the
    # pointer from the first occurrence instead of writing new data.
    seen_addrs = {}  # orig_addr -> pointer value (filled on first write)
    data_offset = 0
    new_ptrs = []
    for encoded, orig_addr in encoded_entries:
        # Check if this is a duplicate pointer entry
        is_dup = (orig_addr is not None and orig_addr in seen_addrs
                  and encoded == b'\x00')

        if is_dup:
            # Reuse the pointer from the first occurrence
            new_ptrs.append(seen_addrs[orig_addr])
        else:
            pc = data_start_pc + data_offset
            if ptr_size == 3:
                snes = SFCAddress(pc).get_address(SFCAddressType.LOROM2)
                ptr_val = bytes([snes & 0xFF, (snes >> 8) & 0xFF, (snes >> 16) & 0xFF])
            else:
                snes_addr = SFCAddress(pc)
                ptr_val = snes_addr.get_address(ptr_addr_type) & 0xFFFF
            new_ptrs.append(ptr_val)
            rom[pc:pc + len(encoded)] = encoded
            data_offset += len(encoded)
            # Record this address's pointer for future duplicates
            if orig_addr is not None:
                seen_addrs[orig_addr] = ptr_val

    for i, ptr in enumerate(new_ptrs):
        if i >= num_ptrs:
            break
        if ptr_size == 3:
            off = ptr_tbl_pos + i * 3
            rom[off:off + 3] = ptr
        else:
            off = ptr_tbl_pos + i * 2
            rom[off] = ptr & 0xFF
            rom[off + 1] = (ptr >> 8) & 0xFF

    return total_size


def insert_all_scripts(rom_path: str,
                       en_folder: str = 'en_ptr_data',
                       table_filename: str = 'eng.tbl',
                       tables_filter: list = None,
                       jp_tables: set = None,
                       force: bool = False):
    """
    Insert translated script tables into rom_path in place.

    :param tables_filter: Optional list of table names to process (e.g.
                          ['script', 'dialog-2']).  If None, all tables are
                          processed.
    :param jp_tables: Set of table names to insert from JP source (jp_ptr_data/
                      with jap.tbl) instead of EN.  Useful for debugging
                      individual tables by swapping back to the original.

    Dialog tables (dialog-2/3/4/5) share a text region starting at
    DIALOG_TEXT_BASE ($1B83D0) to avoid overlapping each other's data.

    The main 'script' table uses 3-byte SNES pointers and lives in bank $C1+
    (PC $208000+) to overcome the 32 KB bank-$B6 limit.
    """
    import os
    from concurrent.futures import ProcessPoolExecutor
    import multiprocessing

    if jp_tables is None:
        jp_tables = set()

    with open(rom_path, 'rb') as f:
        rom = bytearray(f.read())

    dialog_data_pos = DIALOG_TEXT_BASE
    FREE_FILL = 0xCC  # fill byte for blanked-out relocated data (visible in hex editor)

    # Build the list of tables to process with their source info.
    jobs = []
    for tbl_info in SCRIPT_TABLES:
        name = tbl_info['name']
        if tables_filter is not None and name not in tables_filter:
            continue

        if name in jp_tables:
            folder = 'jp_ptr_data'
            tbl_file = 'jap.tbl'
            lang_tag = ' [JP]'
        else:
            folder = en_folder
            tbl_file = table_filename
            lang_tag = ''

        script_file = os.path.join(folder, f'{name}.txt')
        if not os.path.exists(script_file):
            print(f'  skip {name} (not found: {script_file})')
            continue

        cache_dir = os.path.join(folder, 'bin')
        # When encoding with eng.tbl, use jap.tbl as fallback for untranslated chars
        fb_tbl = 'jap.tbl' if tbl_file != 'jap.tbl' else None
        jobs.append((tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl))

    # Pre-encode all scripts in parallel (encoding is CPU-bound; ROM writes are serial).
    print(f'Encoding {len(jobs)} script table(s)...')
    max_workers = max(1, int(multiprocessing.cpu_count() * 0.8))
    with ProcessPoolExecutor(max_workers=max_workers) as pool:
        futures = {}
        for tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl in jobs:
            fut = pool.submit(encode_script_file, script_file, tbl_file,
                              cache_dir=cache_dir, force=force,
                              fallback_table=fb_tbl)
            futures[tbl_info['name']] = fut
        # Wait for all to finish (also raises any exceptions).
        for name, fut in futures.items():
            fut.result()
            print(f'  encoded: {name}')

    # Insert encoded data into ROM (serial — writes to shared bytearray).
    print('Inserting into ROM...')
    for tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl in jobs:
        name = tbl_info['name']

        kwargs = {}
        if tbl_info.get('ptr_size', 2) == 3:
            kwargs['ptr_size'] = 3

        if 'data_start_pc' in tbl_info:
            kwargs['data_start_pc'] = tbl_info['data_start_pc']

        if name.startswith('dialog-'):
            kwargs['data_start_pc'] = dialog_data_pos

        size = insert_table_into_rom(
            rom, script_file, tbl_file,
            tbl_info['ptr_tbl_pos'], tbl_info['tbl_len'],
            cache_dir=cache_dir,
            fallback_table=fb_tbl,
            **kwargs,
        )
        data_start = kwargs.get('data_start_pc', tbl_info['ptr_tbl_pos'] + tbl_info['tbl_len'])
        print(f'  {name}: {size} bytes written (data @ 0x{data_start:X}){lang_tag}')

        # Blank out original JP location for relocated tables.
        for start, end in tbl_info.get('orig_blank', []):
            length = end - start
            rom[start:end] = bytes([FREE_FILL]) * length
            print(f'    blanked 0x{start:06X}-0x{end:06X} ({length} bytes, fill 0x{FREE_FILL:02X})')

        if name.startswith('dialog-'):
            dialog_data_pos += size

    with open(rom_path, 'wb') as f:
        f.write(rom)

    print(f'All scripts inserted → {rom_path}')


def build_scripted(source: str = 'lm3.sfc',
                   output: str = 'out/lm3_scripted.sfc',
                   font_png: str = 'font/font_accented.png',
                   font_rom_offset: int = 0x170000,
                   en_folder: str = 'en_ptr_data',
                   table_filename: str = 'eng.tbl',
                   tables_filter: list = None,
                   jp_tables: set = None,
                   force: bool = False):
    """
    Build the scripted ROM: font patch + all script insertions.

    Steps:
      1. Rebuild font binary files from font_png.
      2. Copy source ROM to output.
      3. Patch font_1bppil.bin into the ROM at font_rom_offset.
      4. Insert all script tables from en_folder.

    This intermediate ROM is the base for VWF development —
    apply vwf_patch.asm on top with build_vwf().
    """
    print(f'=== build_scripted: {source} → {output} ===')

    build_font(font_png, force=force)

    import shutil, os
    shutil.copy2(source, output)

    # Patch the already-built IL font binary into the ROM.
    font_dir = os.path.dirname(font_png) or 'font'
    stem = os.path.splitext(os.path.basename(font_png))[0]
    il_path = os.path.join(font_dir, 'bin', f'{stem}_1bppil.bin')
    with open(il_path, 'rb') as f:
        font_data = f.read()
    with open(output, 'r+b') as f:
        f.seek(font_rom_offset)
        f.write(font_data)
    print(f'  Font patched into ROM at 0x{font_rom_offset:X}')

    insert_all_scripts(output, en_folder=en_folder, table_filename=table_filename,
                       tables_filter=tables_filter, jp_tables=jp_tables, force=force)

    # Pad ROM to next power-of-2 size and update the ROM-size header byte.
    # LoROM requires a power-of-2 file size; an odd size confuses emulator mapping.
    with open(output, 'r+b') as f:
        data = bytearray(f.read())
    size = len(data)
    target = 1
    while target < size:
        target <<= 1
    if size < target:
        data.extend(b'\xff' * (target - size))
    # ROM-size byte at $7FD7: value N means 2^N KB
    import math
    size_byte = int(math.log2(target // 1024))
    data[0x7FD7] = size_byte
    with open(output, 'wb') as f:
        f.write(data)
    print(f'  ROM padded to {target // 1024} KB, size byte = ${size_byte:02X}')

    # Apply script_patch.asm: TextPtrDispatch + game code patch + meta-table patch.
    # This enables the main script in bank $C1 without needing the VWF patch.
    import os as _os
    if _os.path.exists('script_patch.asm'):
        import subprocess
        result = subprocess.run(
            ['disassembly/asar', 'script_patch.asm', output],
            capture_output=True, text=True,
        )
        if result.stdout:
            print(result.stdout.strip())
        if result.stderr:
            print(result.stderr.strip())
        if result.returncode != 0:
            print('ERROR: script_patch.asm failed')
            return
        print('  script_patch.asm applied')

    print(f'=== scripted ROM ready: {output} ===')


def build_vwf(source: str = 'out/lm3_scripted.sfc',
              output: str = 'out/lm3_en.sfc',
              patch: str = 'vwf_patch.asm',
              asar_path: str = 'disassembly/asar'):
    """
    Apply the VWF assembly patch to the scripted ROM.

    Copies source → output then runs asar in-place on output.
    Font binaries (font/font_1bpp.bin, font/widths.bin) must already exist;
    run build_font() or build_scripted() first if they are stale.
    """
    import subprocess
    import shutil
    import os

    if not os.path.exists(source):
        print(f'ERROR: source ROM not found: {source}')
        print('  Run "python lm3.py script" first to build the scripted ROM.')
        return False

    shutil.copy2(source, output)

    result = subprocess.run(
        [asar_path, patch, output],
        capture_output=True, text=True,
    )

    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)

    if result.returncode != 0:
        print(f'ERROR: asar failed (exit {result.returncode})')
        return False

    print(f'=== VWF patch applied → {output} ===')
    return True


def build(source: str = 'lm3.sfc',
          scripted: str = 'out/lm3_scripted.sfc',
          output: str = 'out/lm3_en.sfc',
          patch: str = 'vwf_patch.asm',
          font_png: str = 'font/font_accented.png',
          en_folder: str = 'en_ptr_data',
          table_filename: str = 'eng.tbl'):
    """Full build: font → scripts → VWF patch."""
    print('=== FULL BUILD ===')
    build_scripted(source=source, output=scripted, font_png=font_png,
                   en_folder=en_folder, table_filename=table_filename)
    build_vwf(source=scripted, output=output, patch=patch)
    print('=== BUILD COMPLETE ===')


# ============================================================================
# Round-trip verification
# ============================================================================

# Extraction table definitions — maps table names to their original ROM layout
# for round-trip verification.  Must match the extract_script_bins() tables.
EXTRACT_TABLES = {
    'script':           {'ptr_tbl_pos': 0x1B0000, 'tbl_len': 0x400},
    'scenario-desc':    {'ptr_tbl_pos': 0x111EE3, 'tbl_len': 0x13C},
    'unit-terrain-desc':{'ptr_tbl_pos': 0x030000, 'tbl_len': 0x500},
    'unit-attacks':     {'ptr_tbl_pos': 0x1B0800, 'tbl_len': 0x06A},
    'quiz-text':        {'ptr_tbl_pos': 0x030800, 'tbl_len': 0x0C0},
    'dialog-2':         {'ptr_tbl_pos': 0x1B8000, 'tbl_len': 0x188},
    'dialog-3':         {'ptr_tbl_pos': 0x1B8100, 'tbl_len': 0x088},
    'dialog-4':         {'ptr_tbl_pos': 0x1B8200, 'tbl_len': 0x026},
    'dialog-5':         {'ptr_tbl_pos': 0x1B8300, 'tbl_len': 0x0D0},
    'field-msg':        {'ptr_tbl_pos': 0x01BD00, 'tbl_len': 0x042},
    'battle-menu':      {'ptr_tbl_pos': 0x013100, 'tbl_len': 0x024},
    'battle-msg':       {'ptr_tbl_pos': 0x013200, 'tbl_len': 0x070},
}


def verify_roundtrip(rom_path: str, folder: str, table_filename: str,
                     tables_filter: list = None):
    """
    Strict round-trip verification: for each table, re-encode the text dump
    and compare byte-for-byte against the original ROM binary data.

    Every mismatch is a failure — no tolerance for ambiguous encodings or
    duplicate pointers.  These must be fixed in the table file or dump.

    Returns True if all entries match 1:1, False otherwise.
    """
    import os

    with open(rom_path, 'rb') as f:
        rom = list(f.read())  # list, not bytearray — check_for_lone_byte needs int elements

    tbl = Table(table_filename, warn_duplicates=True)
    all_pass = True

    for name, ext_info in EXTRACT_TABLES.items():
        if tables_filter and name not in tables_filter:
            continue

        script_file = os.path.join(folder, f'{name}.txt')
        if not os.path.exists(script_file):
            print(f'  skip {name} (not found: {script_file})')
            continue

        ptr_tbl_pos = ext_info['ptr_tbl_pos']
        tbl_len = ext_info['tbl_len']
        ptr_size = 2
        num_ptrs = tbl_len // ptr_size

        # Determine bank from pointer table
        ptr_table_addr = SFCAddress(ptr_tbl_pos)
        ptr_bank = ptr_table_addr.get_bank_byte(SFCAddressType.LOROM1)

        # Pre-compute all pointer targets for bounding entries
        all_starts = []
        for idx in range(num_ptrs):
            ptr_off = ptr_tbl_pos + idx * ptr_size
            lo = rom[ptr_off]
            hi = rom[ptr_off + 1]
            ptr = SFCAddress([lo, hi, ptr_bank], SFCAddressType.LOROM1)
            all_starts.append(ptr.get_address(SFCAddressType.PC))
        sorted_unique_addrs = sorted(set(all_starts))

        # Extract original binary entries from ROM using pointer table.
        orig_entries = []  # (data_bytes, data_start_pc)
        for idx in range(num_ptrs):
            data_start = all_starts[idx]

            # Use next unique pointer address as upper bound
            addr_idx = sorted_unique_addrs.index(data_start) if data_start in sorted_unique_addrs else -1
            max_addr = sorted_unique_addrs[addr_idx + 1] if addr_idx >= 0 and addr_idx + 1 < len(sorted_unique_addrs) else None
            data_end = tbl.find_entry_end(rom, data_start, max_addr=max_addr)

            orig_entries.append((bytes(rom[data_start:data_end]), data_start))

        # Re-encode text dump (returns list of (encoded_bytes, orig_addr) tuples)
        encoded_entries = encode_script_file(script_file, table_filename)

        # Compare — strict 1:1.
        # For duplicate-address entries (empty content in dump, same orig_addr
        # as earlier entry), the encoder will reuse the first entry's data at
        # insertion time, so we compare against the first occurrence's encoded
        # data rather than the empty b'\x00'.
        max_entries = min(len(orig_entries), len(encoded_entries))
        fails = 0

        if len(orig_entries) != len(encoded_entries):
            print(f'  {name}: WARN — entry count mismatch '
                  f'(ROM: {len(orig_entries)}, text: {len(encoded_entries)})')

        # Build map: orig_addr -> first encoded data for that address
        addr_to_encoded = {}
        for enc_data, orig_addr in encoded_entries:
            if orig_addr is not None and orig_addr not in addr_to_encoded:
                if enc_data != b'\x00':
                    addr_to_encoded[orig_addr] = enc_data

        for idx in range(max_entries):
            orig_data, orig_pc = orig_entries[idx]
            enc_data, orig_addr = encoded_entries[idx]

            # For duplicate-address entries, use the first occurrence's encoding
            if enc_data == b'\x00' and orig_addr is not None and orig_addr in addr_to_encoded:
                enc_data = addr_to_encoded[orig_addr]

            if orig_data == enc_data:
                continue

            fails += 1
            if fails <= 5:
                diff_pos = next(
                    (i for i in range(min(len(orig_data), len(enc_data)))
                     if orig_data[i] != enc_data[i]),
                    min(len(orig_data), len(enc_data))
                )
                print(f'  {name}[{idx}]: FAIL at byte {diff_pos}')
                print(f'    orig ({len(orig_data):4d} bytes): '
                      f'{orig_data[:32].hex(" ")}{"..." if len(orig_data) > 32 else ""}')
                print(f'    enc  ({len(enc_data):4d} bytes): '
                      f'{enc_data[:32].hex(" ")}{"..." if len(enc_data) > 32 else ""}')
                if diff_pos > 0:
                    ctx_start = max(0, diff_pos - 4)
                    ctx_end = min(max(len(orig_data), len(enc_data)), diff_pos + 8)
                    print(f'    diff region [{ctx_start}:{ctx_end}]:')
                    print(f'      orig: {orig_data[ctx_start:ctx_end].hex(" ")}')
                    print(f'      enc:  {enc_data[ctx_start:ctx_end].hex(" ")}')

        ok_count = max_entries - fails
        if fails == 0:
            print(f'  {name}: PASS ({ok_count} exact) [{max_entries} entries]')
        else:
            print(f'  {name}: FAIL ({fails}/{max_entries} entries differ, '
                  f'{ok_count} exact)')
            if fails > 5:
                print(f'    (showing first 5 of {fails} failures)')
            all_pass = False

    return all_pass


def jptest_orig(rom_path: str, output_path: str, jp_folder: str = 'jp_ptr_data',
                table_filename: str = 'jap.tbl', tables_filter: list = None):
    """
    Re-insert JP scripts at original ROM locations by writing each entry back
    at its original address (from the dump header). This preserves the non-contiguous
    layout of tables like battle-msg where game data is interleaved between entries.
    """
    import os, shutil, re

    shutil.copy2(rom_path, output_path)

    with open(output_path, 'rb') as f:
        rom = bytearray(f.read())

    tbl = Table(table_filename)

    for name, ext_info in EXTRACT_TABLES.items():
        if tables_filter and name not in tables_filter:
            continue

        script_file = os.path.join(jp_folder, f'{name}.txt')
        if not os.path.exists(script_file):
            print(f'  skip {name} (not found)')
            continue

        ptr_tbl_pos = ext_info['ptr_tbl_pos']
        tbl_len = ext_info['tbl_len']
        num_ptrs = tbl_len // 2

        ptr_table_addr = SFCAddress(ptr_tbl_pos)
        ptr_bank = ptr_table_addr.get_bank_byte(SFCAddressType.LOROM1)

        # Read and encode entries
        with open(script_file, 'r', encoding='utf-16') as f:
            text = f.read()

        entries = text.split('<<')[1:]
        total_bytes = 0
        ptr_idx = 0
        seen_addrs = {}  # orig_addr -> SNES pointer value

        for entry in entries:
            if '>>' not in entry:
                continue
            header = entry.split('>>')[0]
            content = entry.split('>>')[1]
            if content.startswith('\n'):
                content = content[1:]
            content = content.rstrip()

            # Parse original address from header: <<$78336:0[$85558]>>
            addr_match = re.search(r'\[\$(\d+)\]', header)
            if not addr_match:
                continue
            orig_pc = int(addr_match.group(1))

            # Check for duplicate address (no content in dump)
            if not content and orig_pc in seen_addrs:
                # Reuse pointer from first occurrence
                if ptr_idx < num_ptrs:
                    ptr_val = seen_addrs[orig_pc]
                    off = ptr_tbl_pos + ptr_idx * 2
                    rom[off] = ptr_val & 0xFF
                    rom[off + 1] = (ptr_val >> 8) & 0xFF
                ptr_idx += 1
                continue

            # Encode the entry
            if not content or content == '[end]':
                encoded = b'\x00'
            else:
                encoded = encode_text(content, tbl)

            # Write data at the original address
            rom[orig_pc:orig_pc + len(encoded)] = encoded
            total_bytes += len(encoded)

            # Write pointer
            snes_addr = SFCAddress(orig_pc)
            ptr_val = snes_addr.get_address(SFCAddressType.LOROM1) & 0xFFFF
            if ptr_idx < num_ptrs:
                off = ptr_tbl_pos + ptr_idx * 2
                rom[off] = ptr_val & 0xFF
                rom[off + 1] = (ptr_val >> 8) & 0xFF

            seen_addrs[orig_pc] = ptr_val
            ptr_idx += 1

        print(f'  {name}: {total_bytes} bytes written in-place ({ptr_idx} entries)')

    with open(output_path, 'wb') as f:
        f.write(rom)

    print(f'JP scripts re-inserted at original locations → {output_path}')




# ============================================================================
# CLI entry point
# ============================================================================

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='LM3 ROM build tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
commands:
  font     Build font binary files only (font_1bppil.bin, font_1bpp.bin, widths.bin)
  script   Font + script insertion → lm3_scripted.sfc  (partial build base)
  vwf      Apply VWF patch to lm3_scripted.sfc → lm3_en.sfc
  build    Full build: font + script + vwf
  extract  Extract script from ROM to text files
  verify   Round-trip test: re-encode text dumps and compare against ROM binary
  hexify   Convert untranslated Japanese in en_ptr_data to [XX] hex placeholders
  jptest   Re-insert JP scripts into expanded ROM layout (round-trip insertion test)
  jptest-orig  Re-insert JP scripts at original ROM locations (data integrity test)
""",
    )
    parser.add_argument('command', choices=['font', 'font-preview', 'script', 'vwf', 'build', 'extract', 'verify', 'hexify', 'jptest', 'jptest-orig'])
    parser.add_argument('--source',   default='lm3.sfc',          help='Source ROM (default: lm3.sfc)')
    parser.add_argument('--scripted', default='out/lm3_scripted.sfc',  help='Scripted ROM intermediate')
    parser.add_argument('--output',   default='out/lm3_en.sfc',        help='Final output ROM')
    parser.add_argument('--patch',    default='vwf_patch.asm',     help='VWF patch file (default: vwf_patch.asm)')
    parser.add_argument('--font',     default='font/font_accented.png', help='Font PNG (default: font/font_accented.png)')
    parser.add_argument('--lang',     default='jp',                help='Language for extract (jp or en, default: jp)')
    parser.add_argument('--table',    default='eng.tbl',           help='Character table for insert (default: eng.tbl)')
    parser.add_argument('--en-folder',default='en_ptr_data',       help='English text folder (default: en_ptr_data)')
    parser.add_argument('--tables',   default=None,
                        help='Comma-separated list of tables to insert '
                             '(e.g. "script,dialog-2"). Default: all tables.')
    parser.add_argument('--jp-tables', default=None,
                        help='Comma-separated list of tables to insert from JP source '
                             'instead of EN (e.g. "battle-msg,battle-menu"). '
                             'Uses jp_ptr_data/ with jap.tbl.')
    parser.add_argument('--force', action='store_true',
                        help='Force re-encode all scripts (ignore bin cache).')

    args = parser.parse_args()
    import os
    tables_filter = [t.strip() for t in args.tables.split(',')] if args.tables else None
    jp_tables = set(t.strip() for t in args.jp_tables.split(',')) if args.jp_tables else set()

    if args.command == 'font':
        build_font(args.font, force=args.force)

    elif args.command == 'font-preview':
        stem = os.path.splitext(os.path.basename(args.font))[0]
        font_dir = os.path.dirname(args.font) or 'font'
        font_width_preview(
            font_bin_path=os.path.join(font_dir, 'bin', f'{stem}_1bpp.bin'),
            widths_bin_path=os.path.join(font_dir, f'{stem}_widths.bin'),
            table_path=args.table,
            output_path=os.path.join(font_dir, f'{stem}_preview.png'),
        )

    elif args.command == 'script':
        build_scripted(
            source=args.source,
            output=args.scripted,
            font_png=args.font,
            en_folder=args.en_folder,
            table_filename=args.table,
            tables_filter=tables_filter,
            jp_tables=jp_tables,
            force=args.force,
        )

    elif args.command == 'vwf':
        build_vwf(source=args.scripted, output=args.output, patch=args.patch)

    elif args.command == 'build':
        build(
            source=args.source,
            scripted=args.scripted,
            output=args.output,
            patch=args.patch,
            font_png=args.font,
            en_folder=args.en_folder,
            table_filename=args.table,
        )

    elif args.command == 'extract':
        tbl_file = 'jap.tbl' if args.lang == 'jp' else 'eng.tbl'
        extract_script_bins(
            file_name=args.source,
            folder_prefix=args.lang,
            table_filename=tbl_file,
        )

    elif args.command == 'verify':
        folder = 'jp_ptr_data' if args.lang == 'jp' else args.en_folder
        tbl_file = 'jap.tbl' if args.lang == 'jp' else args.table
        print(f'=== Round-trip verification: {args.source} vs {folder}/ ({tbl_file}) ===')
        ok = verify_roundtrip(
            rom_path=args.source,
            folder=folder,
            table_filename=tbl_file,
            tables_filter=tables_filter,
        )
        print(f'=== {"ALL PASS" if ok else "FAILURES DETECTED"} ===')

    elif args.command == 'hexify':
        print(f'=== Converting Japanese text to hex in {args.en_folder}/ ===')
        hexify_en_files(
            en_folder=args.en_folder,
            tables_filter=tables_filter,
        )

    elif args.command == 'jptest':
        output = args.output.replace('_en.sfc', '_jptest.sfc') if '_en' in args.output else 'out/lm3_jptest.sfc'
        all_table_names = set(t['name'] for t in SCRIPT_TABLES)
        if tables_filter:
            all_table_names = all_table_names & set(tables_filter)
        print(f'=== jptest: re-inserting JP scripts into expanded layout ===')
        print(f'  source: {args.source} → {output}')
        build_scripted(
            source=args.source,
            output=output,
            font_png=args.font,
            table_filename='jap.tbl',
            tables_filter=tables_filter,
            jp_tables=all_table_names,
            force=args.force,
        )

    elif args.command == 'jptest-orig':
        output = 'out/lm3_jptest_orig.sfc'
        print(f'=== jptest-orig: re-inserting JP scripts at original locations ===')
        print(f'  source: {args.source} → {output}')
        jptest_orig(
            rom_path=args.source,
            output_path=output,
            tables_filter=tables_filter,
        )
