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


def extract_script_bins(file_name='base.sfc', folder_prefix='test', table_filename='jp_data/jap.tbl'):
    folder_name = f'{folder_prefix}_ptr_data'
    tables = _build_extract_tables()

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
            full_extent = kwargs.get('full_extent_entries') or []
            if kwargs.get('event_script', False) or ptr_index in full_extent:
                # Event script entries have embedded 0x00 in bytecodes, so
                # find_entry_end would truncate them.  Use the next unique
                # pointer address as the boundary instead.
                # full_extent_entries forces the same behavior per-index for
                # slots that hold orphan data past the first 0x00 terminator.
                if max_addr is not None:
                    data_end = max_addr
                else:
                    # Last entry: fall back to find_entry_end
                    data_end = tbl.find_entry_end(bin_data, data_start, max_addr=max_addr)
            else:
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

                    field_data = data[e_start:e_end]
                    fill = e.get('fill', None)
                    if fill is not None:
                        # Strip trailing fill bytes so the decoder sees clean text
                        while field_data and field_data[-1] == fill:
                            field_data = field_data[:-1]
                    bin_list.append({'id': f'{this_id}.{e.get("label", e_start)}',
                                     'addr': data_start + e_start,
                                     'data': field_data, 'trim': fill})
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
    Decode event-text binary using the standard table, with two guards:
      1. 0x00 is ALWAYS a sub-entry terminator ([end]) — never consumed
         by a multi-byte character lookup.
      2. 0xFF commands use @ctrl byte lengths so their parameter bytes
         (which may include 0x00) are never misinterpreted.
    Everything else (including 0x01-0x08 kanji high bytes) goes through
    the normal 3→2→1 byte table lookup, identical to interpret_binary_data.
    """
    if not bin_data:
        return ''

    ctrl = tbl.ctrl_lengths
    result = ''
    i = 0

    while i < len(bin_data):
        b = bin_data[i]

        # 0x00: sub-entry terminator — must be caught before table lookup
        if b == 0x00:
            result += '[end]'
            i += 1
            continue

        # 0xFF: extended command — use @ctrl lengths to skip params
        if b == 0xFF and i + 1 < len(bin_data):
            cmd = bin_data[i + 1]
            ctrl_len = ctrl.get(cmd, 3)

            # Try named 3-byte lookup first (e.g. [msg], [cls], [pink])
            if i + 2 < len(bin_data):
                val_3byte = (0xFF << 16) | (bin_data[i+1] << 8) | bin_data[i+2]
                char = tbl.get_chars(val_3byte, False)
                if char:
                    result += char
                    i += 3
                    continue

            # Emit full command as hex bracket with @ctrl length
            end = min(i + ctrl_len, len(bin_data))
            code_bytes = bin_data[i:end]
            hex_str = ''.join(f'{b:02X}' for b in code_bytes)
            result += f'[{hex_str}]'
            i += ctrl_len
            continue

        # Standard table lookup: 3-byte → 2-byte → 1-byte (same as interpret_binary_data)
        # Guard: never let a multi-byte match span across a 0x00 byte
        matched = False
        for size in (3, 2, 1):
            if i + size > len(bin_data):
                continue
            # Don't consume a 0x00 as part of a multi-byte character
            if size > 1 and any(bin_data[i + j] == 0x00 for j in range(1, size)):
                continue
            val = 0
            for j in range(size):
                val = (val << 8) | bin_data[i + j]
            char = tbl.get_chars(val, False)
            if char:
                result += char
                i += size
                matched = True
                break

        if not matched:
            result += tbl.get_chars(b, True) or f'[{b:02X}]'
            i += 1

    return result


def dump_event_script(filename, dict_data, tbl, deduplicate=True):
    """
    Dump event script data using the standard table-based text decoder.
    Event-text is processed identically to other script tables — the only
    special handling is during insertion (embedded SNES pointer fixup).
    :param filename: output file path
    :param dict_data: list of dicts with 'id', 'addr', 'data' keys
    :param tbl: Table instance
    :param deduplicate: skip duplicate addresses
    """
    tbl.dump_script(filename, dict_data, deduplicate)


def _find_text_windows(bin_data, ctrl_lengths):
    """
    Scan event-script binary data for text windows: regions between
    [P] (0x10, enters text mode) and [end] (0x00, exits text mode).

    Returns list of (start, end) tuples where start is the offset of 0x10
    and end is the offset of the terminating 0x00.
    """
    windows = []
    pos = 0
    in_text = False
    text_start = None
    while pos < len(bin_data):
        b = bin_data[pos]
        if b == 0xFF and pos + 1 < len(bin_data):
            sub = bin_data[pos + 1]
            cl = ctrl_lengths.get(sub, 2)
            pos += cl
        elif b == 0x10 and not in_text:
            in_text = True
            text_start = pos
            pos += 1
        elif b == 0x00 and in_text:
            windows.append((text_start, pos))
            in_text = False
            pos += 1
        elif b == 0x00:
            pos += 1
        else:
            pos += 1
    # Window that extends to end of entry (no explicit [end])
    if in_text:
        windows.append((text_start, len(bin_data)))
    return windows


def dump_event_script_windowed(filename, dict_data, tbl, deduplicate=True):
    """
    Dump event script data in windowed format.  Each entry shows only its
    text windows (between [P] and [end]).  Bytecodes are invisible.

    Output format:
        <<$TBLADDR:INDEX[$DATAADDR]>>
        <<<window[0]:$START-$END>>>
        [FF0A0C]LITTLE MASTER[pink]EPISODE 3
        <<<window[1]:$START-$END>>>
        PLANNER: TADATO KAWANO
    """
    ctrl = tbl.ctrl_lengths
    nl = '\n'
    line1 = True
    dumped_addrs = []

    with open(filename, 'w', encoding='utf-8') as of:
        for data in dict_data:
            of.write(f"{'' if line1 else nl}<<{data.get('id')}>>{nl}")
            line1 = False

            addr = data.get('addr', None)
            if deduplicate and addr is not None:
                if addr in dumped_addrs:
                    continue
                dumped_addrs.append(addr)

            raw = data['data']
            windows = _find_text_windows(raw, ctrl)

            if not windows:
                # Pure bytecode entry — blank (no windows to show)
                continue

            for wi, (tw_start, tw_end) in enumerate(windows):
                # Decode only the text content (after [P], before [end])
                text_data = raw[tw_start + 1:tw_end]
                decoded = interpret_event_script(text_data, tbl)

                of.write(f"<<<window[{wi}]:${tw_start:04X}-${tw_end:04X}>>>{nl}")
                of.write(f"{decoded}{nl}")


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


def hexify_en_files(en_folder, jp_table_path='jp_data/jap.tbl', en_table_path='en_data/eng.tbl',
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


def encode_text(text_str, tbl, fallback_tbl=None, track_bytecode_offsets=False):
    """
    Encode a text string to bytes using the Table's character map.
    All control codes and character mappings come from the table file —
    nothing is hardcoded here.
    :param text_str: the text to encode
    :param tbl: Table instance with character mappings (primary, e.g. eng.tbl)
    :param fallback_tbl: optional fallback Table (e.g. jap.tbl) for characters
                         not in the primary table — used to pass through
                         untranslated Japanese text as raw bytes
    :param track_bytecode_offsets: if True, return (bytes, bc_offsets) where
                                   bc_offsets is a set of output byte indices
                                   that came from {XX} bytecode notation.
    :return: bytes, or (bytes, set[int]) when track_bytecode_offsets=True

    Entry-reference syntax: [FFC0@N] emits FF C0 + 3 placeholder bytes (FF FF FF)
    and records a fixup: (byte_offset_of_addr, target_entry_index).  The caller
    must patch the 3 address bytes once entry N's SNES address is known.
    Fixups are returned in encoded.ffc0_fixups (list of (offset, entry_idx) tuples)
    as an attribute on the returned bytes object.
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
    ffc0_fixups = []   # list of (byte_offset, target_entry_index, label_or_None)
    labels = {}        # label_name -> byte_offset within this entry
    bc_offsets = set() if track_bytecode_offsets else None
    i = 0
    while i < len(text_str):
        ch = text_str[i]

        # Skip newlines and carriage returns (format artifacts, not game data)
        if ch in '\n\r':
            i += 1
            continue

        # {XX} bytecode notation — raw hex bytes from event script extraction.
        # These are non-text bytecodes that must be preserved verbatim.
        if ch == '{':
            close = text_str.find('}', i + 1)
            if close != -1:
                hex_str = text_str[i + 1:close]
                if len(hex_str) == 2 and all(c in '0123456789ABCDEFabcdef' for c in hex_str):
                    if bc_offsets is not None:
                        bc_offsets.add(len(result))
                    result.append(int(hex_str, 16))
                    i = close + 1
                    continue

        # Longest-match against the primary table — multi-char matches always preferred.
        # For '[', try multi-char table entries first, then hex escape [XX]/[XXXX]/etc.,
        # and only fall back to single-char '[' match as last resort.
        matched = False
        if ch == '[':
            # First: try multi-char table matches (length >= 2) for named sequences
            # like [FF7F01], [nl], [end], etc.
            for length in range(min(max_key_len, len(text_str) - i), 1, -1):
                substr = text_str[i:i + length]
                val = char_map.get(substr)
                if val is not None:
                    result.extend(_int_to_bytes_be(val))
                    i += length
                    matched = True
                    break

            # Second: [FFC0@N] or [FFC0@N:label] entry-reference syntax
            if not matched:
                import re as _re
                m = _re.match(r'\[FFC0@(\d+)(?::(\w+))?\]', text_str[i:])
                if m:
                    target_idx = int(m.group(1))
                    label = m.group(2)  # None if no :label
                    result.extend(b'\xFF\xC0')       # FF C0 opcode
                    ffc0_fixups.append((len(result), target_idx, label))
                    result.extend(b'\xFF\xFF\xFF')    # 3-byte placeholder
                    i += m.end()
                    matched = True

            # [label:NAME] — zero-width marker recording byte offset
            if not matched:
                m = _re.match(r'\[label:(\w+)\]', text_str[i:])
                if m:
                    labels[m.group(1)] = len(result)
                    i += m.end()
                    matched = True

            # Third: try hex escape [XX], [XXXX], [XXXXXX], [XXXXXXXX]
            if not matched:
                close = text_str.find(']', i + 1)
                if close != -1:
                    hex_str = text_str[i + 1:close]
                    if len(hex_str) >= 2 and len(hex_str) % 2 == 0 and all(c in '0123456789ABCDEFabcdef' for c in hex_str):
                        result.extend(bytes.fromhex(hex_str))
                        i = close + 1
                        matched = True

            # Fourth: multi-char match from fallback table (e.g. [c] defined
            # only in jap.tbl). Must run before single-char '[' steal.
            if not matched and fb_map:
                for length in range(min(fb_max_key_len, len(text_str) - i), 1, -1):
                    substr = text_str[i:i + length]
                    if not substr.startswith('['):
                        continue
                    val = fb_map.get(substr)
                    if val is not None:
                        result.extend(_int_to_bytes_be(val))
                        i += length
                        matched = True
                        break

            # Fifth: single-char '[' from table (e.g. display bracket character)
            if not matched:
                val = char_map.get('[')
                if val is not None:
                    result.extend(_int_to_bytes_be(val))
                    i += 1
                    matched = True
        else:
            # Longest-match across primary AND fallback tables. At each length
            # (descending from max), try primary first then fallback — so a
            # 3-char jap.tbl entry like "(ぇ)"=$5F wins over eng.tbl's 1-char
            # "("=$28 instead of the single-char steal short-circuiting it.
            combined_max = max(max_key_len, fb_max_key_len)
            for length in range(min(combined_max, len(text_str) - i), 0, -1):
                substr = text_str[i:i + length]
                val = char_map.get(substr)
                if val is None and fb_map:
                    val = fb_map.get(substr)
                if val is not None:
                    result.extend(_int_to_bytes_be(val))
                    i += length
                    matched = True
                    break

        if matched:
            continue

        # Fallback: printable ASCII → identity, else '?'
        if 0x20 <= ord(ch) <= 0x7E:
            result.append(ord(ch))
        else:
            result.append(0x3F)  # '?'
        i += 1

    encoded = bytes(result)
    if track_bytecode_offsets:
        return encoded, bc_offsets, ffc0_fixups, labels
    if ffc0_fixups or labels:
        return encoded, ffc0_fixups, labels
    return encoded


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
        # Strip trailing newlines/tabs but NOT game characters like \u3000
        content = content.rstrip('\n\r\t ')
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
    # Char $00 must stay blank (all zeros) in both halves — the game uses it
    # as a transparent background tile in menus that use the inverted font set.
    font_inverted[0:16] = bytearray(16)

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


def font_width_preview(font_bin_path='en_data/bin/fonts/font_accented_1bpp.bin',
                       widths_bin_path='en_data/fonts/font_accented_widths.bin',
                       table_path='en_data/eng.tbl', output_path='en_data/fonts/font_accented_preview.png',
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
import os as _os
from retrotool.project import load_project, load_datadefs

_PROJECT_ROOT = _os.path.dirname(_os.path.abspath(__file__))
_PROJECT = load_project(_PROJECT_ROOT)
_DATADEFS = load_datadefs(_PROJECT)


def _datadef_to_script_entry(d):
    out = {'name': d.name,
           'ptr_tbl_pos': d.pointers.address,
           'tbl_len': d.pointers.count * d.pointers.size}
    if d.pointers.size != 2:
        out['ptr_size'] = d.pointers.size
    if d.data and d.data.start is not None:
        out['data_start_pc'] = d.data.start
    for k in ('event_script', 'word_wrap', 'textbuf_limit', 'dte', 'group',
              'full_extent_entries', 'mirror_ptr_tables'):
        if k in d.extras:
            out[k] = d.extras[k]
    return out


def _datadef_to_fixed_entry(d):
    out = {'name': d.name,
           'data_pos': d.data.start,
           'entries': d.extras['entries'],
           'block_len': d.extras['block_len'],
           'fields': d.extras['fields']}
    for k in ('source_data_start', 'extract_data_len',
              'extract_block_len', 'extract_fields'):
        if k in d.extras:
            out[k] = d.extras[k]
    return out


def _build_extract_tables():
    """Rebuild the legacy extract_script_bins tables list from _DATADEFS.
    Preserves pointer/fixed ordering and LM3-specific extras
    (mirror_ptr_tables, full_extent_entries, event_script, field overrides)."""
    tables = []
    for d in _DATADEFS:
        if d.type == 'pointer':
            entry = {
                'ptr_tbl_pos': d.pointers.address,
                'tbl_len': d.pointers.count * d.pointers.size,
                'table_name': d.name,
            }
            if d.extras.get('event_script'):
                entry['event_script'] = True
            if 'full_extent_entries' in d.extras:
                entry['full_extent_entries'] = list(d.extras['full_extent_entries'])
            mirrors = d.extras.get('mirror_ptr_tables')
            if mirrors:
                primary = dict(entry)
                primary['output'] = False
                group = [primary]
                for i, addr in enumerate(mirrors):
                    sub = {'ptr_tbl_pos': addr}
                    if i == len(mirrors) - 1:
                        sub['output'] = True
                    group.append(sub)
                tables.append(group)
            else:
                tables.append(entry)
        elif d.type == 'fixed':
            data_pos = d.extras.get('source_data_start', d.data.start)
            data_len = d.extras.get('extract_data_len',
                                    d.extras['entries'] * d.extras['block_len'])
            block_len = d.extras.get('extract_block_len', d.extras['block_len'])
            fields = d.extras.get('extract_fields', d.extras['fields'])
            tables.append({
                'data_pos': data_pos,
                'data_len': data_len,
                'block_len': block_len,
                'block_eval': fields,
                'table_name': d.name,
            })
    return tables


SCRIPT_TABLES = [_datadef_to_script_entry(d) for d in _DATADEFS if d.type == 'pointer']
FIXED_TABLES  = [_datadef_to_fixed_entry(d)  for d in _DATADEFS if d.type == 'fixed']
DIALOG_TEXT_BASE = _PROJECT.extras.get('dialog_text_base', 0x1B83D0)


def _bin_dir(folder: str) -> str:
    """Map a data folder to its sibling bin cache dir.
    e.g. 'en_data/scripts' -> 'en_data/bin/scripts';
         'en_data/fonts'   -> 'en_data/bin/fonts'."""
    parent = _os.path.dirname(folder)
    if not parent:
        return _os.path.join(folder, 'bin')
    return _os.path.join(parent, 'bin', _os.path.basename(folder))


def build_font(font_png='en_data/fonts/font_accented.png', force=False):
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

    font_dir = os.path.dirname(font_png) or 'en_data/fonts'
    cache_dir = _bin_dir(font_dir)
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


def _read_script_text(script_file: str) -> str:
    """Read a script text file, auto-detecting UTF-16-LE (BOM) vs UTF-8 encoding."""
    with open(script_file, 'rb') as f:
        bom = f.read(2)
    encoding = 'utf-16' if bom == b'\xff\xfe' else 'utf-8'
    with open(script_file, 'r', encoding=encoding) as f:
        return f.read()


def _entry_in_range(idx: int, entries_spec) -> bool:
    """Check if entry index matches an entries spec.

    entries_spec can be:
      None          — matches all entries
      '0-57'        — range (inclusive)
      '0,5,10-20'   — comma-separated values and ranges
      [0, 1, 2]     — explicit list
    """
    if entries_spec is None:
        return True
    if isinstance(entries_spec, (list, set)):
        return idx in entries_spec
    # Parse string spec: comma-separated values and ranges
    for part in str(entries_spec).split(','):
        part = part.strip()
        if '-' in part:
            lo, hi = part.split('-', 1)
            if int(lo) <= idx <= int(hi):
                return True
        elif part.isdigit():
            if idx == int(part):
                return True
    return False


def _word_wrap_text(text: str, line_width: int, max_lines: int) -> str:
    """Word-wrap text for fixed-width display, inserting [nl] at line breaks.

    - Replaces \\n / \\r\\n between words with spaces (source file line breaks
      are not game line breaks).
    - Existing [nl] in text forces a line break.
    - Hex control codes like [FFC000B222] are zero-width (preserved in output).
    - Named table codes like [end] are zero-width and preserved.
    - After max_lines, remaining text is truncated.  Hex control codes
      ([XXYY...] and {XX}) after the truncation point are preserved;
      named table codes are not.
    - Returns the wrapped/truncated text ready for encoding.
    """
    import re

    # --- Step 1: Normalize source newlines to spaces ---
    # \r\n or \r or \n between content becomes a single space.
    normalized = text.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ')
    # Collapse multiple spaces into one.
    normalized = re.sub(r' {2,}', ' ', normalized).strip()

    # --- Step 2: Tokenize into words and control codes ---
    # Tokens: [xxx] control codes, {XX} bytecodes, spaces, or runs of other chars.
    tokens = re.findall(r'\[[^\]]*\]|\{[0-9A-Fa-f]{2}\}| +|[^ \[\{]+', normalized)

    # --- Step 3: Word-wrap ---
    # lines[] holds completed lines; line_nl[] is parallel — True means an
    # explicit [nl] is needed after this line.  When a line fills to exactly
    # line_width the game auto-wraps, so no [nl] is emitted (avoids double
    # line break).
    lines = []
    line_nl = []       # parallel to lines: True = emit [nl], False = auto-wrap
    current_line = ''
    col = 0  # visible character position on current line

    def _flush_line(explicit):
        """Flush current_line to lines[]. explicit=True → emit [nl]."""
        nonlocal current_line, col
        lines.append(current_line.rstrip(' '))
        line_nl.append(explicit)
        current_line = ''
        col = 0

    for token in tokens:
        # [nl] = forced line break
        if token == '[nl]':
            _flush_line(True)
            continue

        # Control codes: [xxx] or {XX} — zero visible width
        if (token.startswith('[') and token.endswith(']')) or \
           (token.startswith('{') and token.endswith('}')):
            current_line += token
            continue

        # Space
        if token.strip() == '':
            if col > 0 and col < line_width:
                current_line += ' '
                col += 1
            continue

        # Visible word
        word_len = len(token)

        if col + word_len <= line_width:
            # Fits on current line
            current_line += token
            col += word_len
            # If we exactly filled the line, the game auto-wraps — flush
            # without [nl] so we don't get a double line break.
            if col == line_width:
                _flush_line(False)
        elif word_len <= line_width:
            # Doesn't fit — wrap to next line (needs [nl])
            _flush_line(True)
            current_line = token
            col = word_len
        else:
            # Word longer than line_width — force-break it
            while token:
                remaining = line_width - col
                if remaining <= 0:
                    _flush_line(True)
                    remaining = line_width
                chunk = token[:remaining]
                current_line += chunk
                col += len(chunk)
                token = token[remaining:]
                # Auto-wrap if we exactly filled the line
                if col == line_width and token:
                    _flush_line(False)

    # Flush last line
    if current_line:
        lines.append(current_line.rstrip(' '))
        line_nl.append(False)  # no trailing [nl] after last line

    # --- Step 4: Truncate to max_lines ---
    truncated = len(lines) > max_lines
    if truncated:
        # Collect hex control codes from dropped lines
        dropped = lines[max_lines:]
        dropped_text = ''.join(dropped)
        trailing_hex = re.findall(r'\[FFC0@\d+(?::\w+)?\]|\[[0-9A-Fa-f]{2,}\]|\{[0-9A-Fa-f]{2}\}', dropped_text)
        lines = lines[:max_lines]
        line_nl = line_nl[:max_lines]
        # Append preserved hex codes to last line
        if trailing_hex:
            lines[-1] += ''.join(trailing_hex)

    # Join lines: [nl] only where line_nl[i] is True (explicit break).
    # Auto-wrapped lines (line_nl[i] == False) are joined without [nl]
    # because the game already wraps at line_width.
    parts = []
    for i, line in enumerate(lines):
        parts.append(line)
        if i < len(lines) - 1 and line_nl[i]:
            parts.append('[nl]')
    result = ''.join(parts)
    return result, truncated, len(lines)


def encode_script_file(script_file: str, table_filename: str,
                       cache_dir: str = None, force: bool = False,
                       fallback_table: str = None,
                       word_wrap: dict = None,
                       sub_table_filter: int = None,
                       textbuf_limit: int = None) -> list[bytes]:
    """
    Encode a script file into a list of binary entries, one per <<index>> block.

    Uses a bin cache in cache_dir (e.g. en_data/bin/scripts/) to skip re-encoding
    when neither the script file nor the table file have changed.  The cache
    stores:
      {cache_dir}/{name}.bin       — concatenated encoded entries with 4-byte
                                     length prefix per entry
      {cache_dir}/{name}.checksum  — hex digest of (script_file + tbl_file)

    Returns list of encoded byte strings (one per entry, including \\x00 terminator).
    """
    import hashlib, os

    name = os.path.splitext(os.path.basename(script_file))[0]

    # Compute checksum over script + table file.
    # Use --force to invalidate cache after encoder logic changes.
    h = hashlib.sha256()
    for path in [script_file, table_filename]:
        with open(path, 'rb') as f:
            h.update(f.read())
    if sub_table_filter is not None:
        h.update(f'sub_table_filter={sub_table_filter}'.encode())
    if textbuf_limit is not None:
        h.update(f'textbuf_limit={textbuf_limit}'.encode())
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
                import json as _json
                encoded_entries = []
                with open(bin_path, 'rb') as f:
                    data = f.read()
                pos = 0
                while pos < len(data):
                    addr = int.from_bytes(data[pos:pos+8], 'little', signed=True)
                    pos += 8
                    if addr == -1:
                        addr = None
                    num_fixups = int.from_bytes(data[pos:pos+2], 'little')
                    pos += 2
                    fixups = []
                    for _ in range(num_fixups):
                        foff = int.from_bytes(data[pos:pos+4], 'little')
                        pos += 4
                        fidx = int.from_bytes(data[pos:pos+4], 'little')
                        pos += 4
                        lbl_len = int.from_bytes(data[pos:pos+2], 'little')
                        pos += 2
                        flabel = data[pos:pos+lbl_len].decode('utf-8') or None
                        pos += lbl_len
                        fixups.append((foff, fidx, flabel))
                    labels_len = int.from_bytes(data[pos:pos+4], 'little')
                    pos += 4
                    entry_labels = _json.loads(data[pos:pos+labels_len].decode('utf-8'))
                    pos += labels_len
                    entry_len = int.from_bytes(data[pos:pos+4], 'little')
                    pos += 4
                    encoded_entries.append((data[pos:pos+entry_len], addr, fixups, entry_labels))
                    pos += entry_len
                return encoded_entries

    # Cache miss — encode from scratch.
    tbl = Table(table_filename)
    fb_tbl = Table(fallback_table) if fallback_table else None

    text = _read_script_text(script_file)

    import re

    entries = text.split('<<')[1:]
    # Parse each entry; key by the header index `:N` so that file order can
    # diverge from sub-entry order (e.g. battle-menu extracted entry 0 to the
    # end of the file). encoded_entries is then built in header-index order.
    parsed = {}  # header_idx -> (content, orig_addr)
    file_order = []
    for entry in entries:
        if '>>' not in entry:
            continue
        header = entry.split('>>')[0]
        # Skip <<<window>>> markers caught by the << split.
        if not header.startswith('$'):
            continue
        content = '>>'.join(entry.split('>>')[1:])
        if content.startswith('\n'):
            content = content[1:]
        content = content.rstrip('\n\r\t ')

        # Parse header: <<$TBLPTR:ENTRYIDX[$DATAPTR]>>
        orig_addr = None
        addr_match = re.search(r'\[\$(\d+)\]', header)
        if addr_match:
            orig_addr = int(addr_match.group(1))
        tbl_match = re.match(r'\$(\d+):', header)
        tbl_addr = int(tbl_match.group(1)) if tbl_match else None
        idx_match = re.search(r':(\d+)', header)
        header_idx = int(idx_match.group(1)) if idx_match else len(file_order)
        # When a sub_table_filter is given, skip entries whose header $TBLPTR
        # doesn't match.  Files with multiple sub-tables (e.g. unit-attacks)
        # would otherwise have duplicate :N headers collide in `parsed`.
        if sub_table_filter is not None and tbl_addr is not None and tbl_addr != sub_table_filter:
            continue
        if header_idx in parsed:
            print(f'  WARNING: {name} duplicate header index {header_idx} in {script_file}')
        parsed[header_idx] = (content, orig_addr)
        file_order.append(header_idx)

    # Build encoded_entries in header-index order, filling any gaps with empty.
    encoded_entries = []
    if parsed:
        max_idx = max(parsed)
        for entry_idx in range(max_idx + 1):
            if entry_idx not in parsed:
                encoded_entries.append((b'\x00', None, [], {}))
                continue
            content, orig_addr = parsed[entry_idx]
            if not content or content == '[end]':
                encoded_entries.append((b'\x00', orig_addr, [], {}))
                continue
            # Windowed entries are handled by insert_event_script_windowed();
            # emit empty here so insert_dte_table() preserves original ROM.
            if '<<<window' in content:
                encoded_entries.append((b'\x00', orig_addr, [], {}))
                continue
            if word_wrap is not None and _entry_in_range(entry_idx, word_wrap.get('entries')):
                lw = word_wrap['line_width']
                ml = word_wrap['max_lines']
                content, was_truncated, num_lines = _word_wrap_text(content, lw, ml)
                if was_truncated:
                    print(f'  WARNING: {name} entry {entry_idx}: text exceeds '
                          f'{ml} lines of {lw} chars, truncated')
            result = encode_text(content, tbl, fallback_tbl=fb_tbl)
            if isinstance(result, tuple):
                encoded, fixups, entry_labels = result
            else:
                encoded, fixups, entry_labels = result, [], {}
            encoded_entries.append((encoded, orig_addr, fixups, entry_labels))

    # Enforce total buffer byte limit (e.g. $0400 WRAM text buffer = $01F0 bytes).
    # Walks each entry's FFC0 chain and sums encoded bytes of the whole chain,
    # since Phase 1 keeps buffering across FFC0 redirects.
    if textbuf_limit is not None and encoded_entries:
        def _chain_bytes(idx, visited):
            if idx in visited or idx >= len(encoded_entries):
                return 0
            visited.add(idx)
            entry_bytes, _, entry_fixups, _ = encoded_entries[idx]
            total = len(entry_bytes)
            for fixup in entry_fixups:
                target = fixup[1] if len(fixup) > 1 else None
                if target is not None:
                    total += _chain_bytes(target, visited)
            return total

        for entry_idx in range(len(encoded_entries)):
            encoded = encoded_entries[entry_idx][0]
            if encoded == b'\x00':
                continue
            total = _chain_bytes(entry_idx, set())
            if total > textbuf_limit:
                print(f'  WARNING: {name} entry {entry_idx}: chain total '
                      f'{total} bytes exceeds textbuf_limit {textbuf_limit}')

    # Write cache.
    if bin_path:
        import json as _json
        with open(bin_path, 'wb') as f:
            for data, addr, fixups, entry_labels in encoded_entries:
                # addr as 8-byte signed (-1 for None)
                f.write((addr if addr is not None else -1).to_bytes(8, 'little', signed=True))
                # fixups: 2-byte count, then (4-byte offset, 4-byte entry_idx, label_str)
                f.write(len(fixups).to_bytes(2, 'little'))
                for fixup_tuple in fixups:
                    foff, fidx = fixup_tuple[0], fixup_tuple[1]
                    flabel = fixup_tuple[2] if len(fixup_tuple) > 2 else None
                    f.write(foff.to_bytes(4, 'little'))
                    f.write(fidx.to_bytes(4, 'little'))
                    label_bytes = (flabel or '').encode('utf-8')
                    f.write(len(label_bytes).to_bytes(2, 'little'))
                    f.write(label_bytes)
                # labels: JSON blob
                labels_json = _json.dumps(entry_labels).encode('utf-8')
                f.write(len(labels_json).to_bytes(4, 'little'))
                f.write(labels_json)
                # entry data
                f.write(len(data).to_bytes(4, 'little'))
                f.write(data)
        with open(cksum_path, 'w') as f:
            f.write(current_checksum)

    return encoded_entries


def encode_event_script_windowed(script_file: str, table_filename: str,
                                 fallback_table: str = None,
                                 force: bool = False,
                                 cache_dir: str = None) -> list:
    """
    Encode a windowed event-script file.  Each entry may have zero or more
    <<<window[N]:$START-$END>>> blocks containing translatable text.

    Uses a bin cache in cache_dir to skip re-encoding when neither the script
    file nor the table file have changed.  Cache files:
      {cache_dir}/{name}-windowed.bin       — serialized window data
      {cache_dir}/{name}-windowed.checksum  — hex digest

    Returns list of entries indexed by header :N.  Each entry is either:
      - None (pure bytecode, no windows — skip during insertion)
      - list of (start, end, encoded_bytes) tuples, one per window
        start/end are original ROM offsets (relative to entry data start)
        encoded_bytes is the text content encoded (WITHOUT [P] or [end])
    """
    import re, hashlib, os, struct

    name = os.path.splitext(os.path.basename(script_file))[0]

    # Compute checksum over script + table file(s).
    h = hashlib.sha256()
    for path in [script_file, table_filename]:
        with open(path, 'rb') as f:
            h.update(f.read())
    if fallback_table:
        with open(fallback_table, 'rb') as f:
            h.update(f.read())
    current_checksum = h.hexdigest()

    # Check cache.
    bin_path = cksum_path = None
    if cache_dir:
        os.makedirs(cache_dir, exist_ok=True)
        bin_path = os.path.join(cache_dir, f'{name}-windowed.bin')
        cksum_path = os.path.join(cache_dir, f'{name}-windowed.checksum')

        if not force and os.path.exists(cksum_path) and os.path.exists(bin_path):
            with open(cksum_path, 'r') as f:
                cached_checksum = f.read().strip()
            if cached_checksum == current_checksum:
                # Deserialize cached windowed entries.
                result = []
                with open(bin_path, 'rb') as f:
                    data = f.read()
                pos = 0
                while pos < len(data):
                    entry_marker = data[pos]; pos += 1
                    if entry_marker == 0:
                        result.append(None)
                    else:
                        win_count = struct.unpack_from('<H', data, pos)[0]; pos += 2
                        windows = []
                        for _ in range(win_count):
                            s, e, blen = struct.unpack_from('<HHI', data, pos); pos += 8
                            encoded = data[pos:pos+blen]; pos += blen
                            windows.append((s, e, encoded))
                        result.append(windows)
                return result

    tbl = Table(table_filename)
    fb_tbl = Table(fallback_table) if fallback_table else None

    text = _read_script_text(script_file)

    # Split on entry headers <<$...>> but NOT on <<<window...>>>.
    # Use regex to find entry headers and split around them.
    entry_header_re = re.compile(r'^(<<\$[^>]+>>)', re.MULTILINE)
    parts = entry_header_re.split(text)

    parsed = {}  # header_idx -> list of (start, end, text_content)
    current_header = None
    for part in parts:
        header_match = entry_header_re.match(part)
        if header_match:
            current_header = part
            continue
        if current_header is None:
            continue
        # part is the content after the header
        header = current_header
        rest = part
        idx_match = re.search(r':(\d+)', header)
        if not idx_match:
            current_header = None
            continue
        header_idx = int(idx_match.group(1))

        # Parse window blocks
        windows = []
        window_pattern = re.compile(
            r'<<<window\[(\d+)\]:\$([0-9A-Fa-f]+)-\$([0-9A-Fa-f]+)>>>\s*\n(.*?)(?=<<<window|<<\$|$)',
            re.DOTALL
        )
        for m in window_pattern.finditer(rest):
            wi = int(m.group(1))
            start = int(m.group(2), 16)
            end = int(m.group(3), 16)
            content = m.group(4).rstrip('\n\r\t ')
            windows.append((start, end, content))

        if windows:
            parsed[header_idx] = windows
        # else: pure bytecode, parsed[idx] stays absent → None
        current_header = None

    # Encode each window's text content
    result = []
    if parsed:
        max_idx = max(parsed)
        for entry_idx in range(max_idx + 1):
            if entry_idx not in parsed:
                result.append(None)
                continue
            encoded_windows = []
            for start, end, content in parsed[entry_idx]:
                if not content:
                    # Empty window — no text to encode
                    encoded_windows.append((start, end, b''))
                    continue
                encoded = encode_text(content, tbl, fallback_tbl=fb_tbl)
                if isinstance(encoded, tuple):
                    encoded_bytes = encoded[0]
                else:
                    encoded_bytes = encoded
                # Strip trailing 0x00 terminator — we don't want it in the
                # overflow since the redirect-back FFC0 points to the original
                # ROM's [end] byte.
                if encoded_bytes.endswith(b'\x00'):
                    encoded_bytes = encoded_bytes[:-1]
                encoded_windows.append((start, end, encoded_bytes))
            result.append(encoded_windows)

    # Write cache.
    if bin_path:
        with open(bin_path, 'wb') as f:
            for entry in result:
                if entry is None:
                    f.write(b'\x00')  # marker: no windows
                else:
                    f.write(b'\x01')  # marker: has windows
                    f.write(struct.pack('<H', len(entry)))
                    for s, e, enc in entry:
                        f.write(struct.pack('<HHI', s, e, len(enc)))
                        f.write(enc)
        with open(cksum_path, 'w') as f:
            f.write(current_checksum)

    return result


def insert_table_into_rom(rom: bytearray, script_file: str, table_filename: str,
                          ptr_tbl_pos: int, tbl_len: int,
                          ptr_bank: int = None, ptr_addr_type=None,
                          ptr_size: int = 2, data_start_pc: int = None,
                          cache_dir: str = None, force: bool = False,
                          fallback_table: str = None,
                          word_wrap: dict = None) -> int:
    """
    Encode a translated script file and write it into a ROM bytearray in place.

    :param ptr_size: 2 for standard 16-bit LoROM pointers (bank implicit),
                     3 for 24-bit absolute SNES pointers [lo, hi, bank].
                     When ptr_size=3, tbl_len must be num_entries * 3.
    :param data_start_pc: Override where text data begins in the ROM file.
                          Defaults to ptr_tbl_pos + tbl_len.
                          Use this to skip preserved JP data structures or to
                          pack multiple tables into a shared text region.
    :param cache_dir: Directory for encoded bin cache (e.g. en_data/bin/scripts/).

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
                                         fallback_table=fallback_table,
                                         word_wrap=word_wrap)

    if data_start_pc is None:
        data_start_pc = ptr_tbl_pos + tbl_len

    # Only count bytes for entries that will actually be written (skip duplicates).
    # Duplicate-address entries (empty content, same orig_addr as earlier entry)
    # reuse the earlier entry's pointer — no new data written.
    seen_addrs = {}  # orig_addr -> pointer value
    total_size = 0
    for entry_tuple in encoded_entries:
        encoded, orig_addr = entry_tuple[0], entry_tuple[1]
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
    entry_pc_map = {}     # entry_index -> PC offset where entry data starts
    pending_fixups = []   # (rom_pc_of_placeholder, target_entry_idx)
    entry_labels_map = {}  # entry_idx -> {label_name: byte_offset}
    for entry_idx, entry_tuple in enumerate(encoded_entries):
        encoded, orig_addr = entry_tuple[0], entry_tuple[1]
        fixups = entry_tuple[2] if len(entry_tuple) > 2 else []
        entry_labels = entry_tuple[3] if len(entry_tuple) > 3 else {}

        # Check if this is a duplicate pointer entry
        is_dup = (orig_addr is not None and orig_addr in seen_addrs
                  and encoded == b'\x00')

        if is_dup:
            # Reuse the pointer from the first occurrence
            new_ptrs.append(seen_addrs[orig_addr])
        else:
            pc = data_start_pc + data_offset
            entry_pc_map[entry_idx] = pc
            if entry_labels:
                entry_labels_map[entry_idx] = entry_labels
            if ptr_size == 3:
                snes = SFCAddress(pc).get_address(SFCAddressType.LOROM2)
                ptr_val = bytes([snes & 0xFF, (snes >> 8) & 0xFF, (snes >> 16) & 0xFF])
            else:
                snes_addr = SFCAddress(pc)
                ptr_val = snes_addr.get_address(ptr_addr_type) & 0xFFFF
            new_ptrs.append(ptr_val)
            rom[pc:pc + len(encoded)] = encoded
            # Collect FFC0@ fixups — byte_offset is relative to entry start
            for fixup_tuple in fixups:
                foff, fidx = fixup_tuple[0], fixup_tuple[1]
                flabel = fixup_tuple[2] if len(fixup_tuple) > 2 else None
                pending_fixups.append((pc + foff, fidx, flabel))
            data_offset += len(encoded)
            # Record this address's pointer for future duplicates
            if orig_addr is not None:
                seen_addrs[orig_addr] = ptr_val

    # Apply [FFC0@N] and [FFC0@N:label] fixups
    for rom_pc, target_idx, label in pending_fixups:
        if target_idx not in entry_pc_map:
            print(f'  WARNING: [FFC0@{target_idx}] references missing entry {target_idx}')
            continue
        target_pc = entry_pc_map[target_idx]
        # If a label is specified, add its byte offset within the target entry
        if label:
            target_labels = entry_labels_map.get(target_idx, {})
            if label not in target_labels:
                print(f'  WARNING: [FFC0@{target_idx}:{label}] — label "{label}" '
                      f'not found in entry {target_idx}')
                continue
            target_pc += target_labels[label]
        target_snes = SFCAddress(target_pc).get_address(SFCAddressType.LOROM2)
        rom[rom_pc]     = target_snes & 0xFF
        rom[rom_pc + 1] = (target_snes >> 8) & 0xFF
        rom[rom_pc + 2] = (target_snes >> 16) & 0xFF
        ref = f'FFC0@{target_idx}:{label}' if label else f'FFC0@{target_idx}'
        print(f'    {ref} → ${target_snes:06X}')

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


# ---------------------------------------------------------------------------
# DTE (Dual Table Encoding) — overflow insertion for non-relocatable tables
# ---------------------------------------------------------------------------
# For tables like script_ext and event-text, entries contain bytecodes with
# absolute addresses that cannot be relocated.  English text may be longer
# than the original Japanese.  DTE writes as much text inline as fits, then
# redirects the remainder to an expansion area via FF F7/F8 + INDEX codes.
#
# DTE trigger codes (defined in dte_patch.asm):
#   FF F7 INDEX  → redirect to DTE table 1 expansion string (3 bytes)
#   FF F8 INDEX  → redirect to DTE table 2 expansion string (3 bytes)
#   FF F6        → return from expansion to inline text (2 bytes, auto-appended)
#
# Expansion area: bank $C6
#   Table 1 pointers: $C6:$8000  (256 × 2-byte within-bank pointers)
#   Table 2 pointers: $C6:$C000  (256 × 2-byte within-bank pointers)
# ---------------------------------------------------------------------------

DTE_TABLE1_PTR_PC = 0x230000    # PC offset: $C6:$8000 in LoROM
DTE_TABLE1_DATA_PC = 0x230200   # after 256 × 2-byte pointers
DTE_TABLE2_PTR_PC = 0x234000    # PC offset: $C6:$C000 in LoROM
DTE_TABLE2_DATA_PC = 0x234200   # after 256 × 2-byte pointers
DTE_BANK = 0xC6

DTE_TRIGGER_TBL1 = bytes([0xFF, 0xF7])  # FF F7 INDEX
DTE_TRIGGER_TBL2 = bytes([0xFF, 0xF8])  # FF F8 INDEX
DTE_RETURN = bytes([0xFF, 0xF6])         # FF F6 (appended to expansion string)


def _collect_ffc0_pins(en_folder: str = 'en_data/scripts') -> set:
    """
    Scan all en_data/scripts .txt files for raw [FFC0HHLLBB] hex literals and
    return the set of target PC offsets they reference.

    These pins represent absolute SNES addresses baked into text data — typically
    references to the middle of an entry.  When such a target falls inside an
    entry's interior, the entry must NOT be FFC0-overflowed past that offset
    (and ideally must not be translated at all, since the byte sequence at that
    offset carries meaning that the cross-reference depends on).
    """
    import os, re, glob
    from retrotool.snes import SFCAddress, SFCAddressType

    pat = re.compile(r'\[FFC0([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})\]')
    pins = set()
    for path in sorted(glob.glob(os.path.join(en_folder, '*.txt'))):
        try:
            with open(path, 'rb') as f:
                raw = f.read()
            if raw[:2] == b'\xff\xfe':
                text = raw[2:].decode('utf-16-le')
            else:
                text = raw.decode('utf-8', errors='replace')
        except Exception:
            continue
        for m in pat.finditer(text):
            lo = int(m.group(1), 16)
            hi = int(m.group(2), 16)
            bk = int(m.group(3), 16)
            snes = (bk << 16) | (hi << 8) | lo
            try:
                pc = SFCAddress(snes, SFCAddressType.LOROM1).get_address(SFCAddressType.PC)
                pins.add(pc)
            except Exception:
                pass
    return pins


def _find_last_overflow_text_window(encoded: bytes, max_inline: int,
                                    ctrl_lengths: dict, reserve: int = 5):
    """
    For event_script entries that overflow, find the last text window where
    we can place an FFC0 redirect.  A text window is [P](0x10) ... [end](0x00).

    The redirect needs: [P] + FF C0 + 3-byte addr = 6 bytes inline at the
    window start.  The [end] at window end stays in ROM (untouched).

    Returns (tw_start, tw_end) — byte offsets of [P] and [end], or (None, None).
    """
    # Walk the encoded data to find all text windows.
    windows = []
    pos = 0
    in_text = False
    text_start = None
    while pos < len(encoded):
        b = encoded[pos]
        if b == 0xFF and pos + 1 < len(encoded):
            sub = encoded[pos + 1]
            cl = ctrl_lengths.get(sub, 2)
            pos += cl
        elif b == 0x10 and not in_text:
            in_text = True
            text_start = pos
            pos += 1
        elif b == 0x00 and in_text:
            windows.append((text_start, pos))
            in_text = False
            pos += 1
        elif b == 0x00 and not in_text:
            pos += 1
        else:
            pos += 1

    # Find the last window where [P] + FFC0 (6 bytes) fits within the inline budget.
    # tw_start must be such that tw_start + 1 + reserve <= max_inline.
    for tw_start, tw_end in reversed(windows):
        if tw_start + 1 + reserve <= max_inline:
            return (tw_start, tw_end)
    return (None, None)


def _find_safe_split(encoded: bytes, max_inline: int, ctrl_lengths: dict,
                     event_script: bool = False, reserve: int = 4) -> int:
    """
    Find the latest safe byte-boundary split point in encoded data that
    leaves room for a redirect sequence at the split point.

    A "safe" split point is between complete characters/control codes — never
    in the middle of a multi-byte FF sequence.

    :param encoded: full encoded entry (including trailing 0x00 terminator)
    :param max_inline: maximum bytes available for inline data
    :param ctrl_lengths: dict {sub_opcode: total_length} from Table.ctrl_lengths
    :param event_script: if True, 0x00 inside FF command params is not a terminator
    :param reserve: bytes to reserve for the redirect sequence (default 4 for DTE:
                    FF Fx INDEX 00; use 5 for FFC0: FF C0 aa bb cc)
    :return: byte offset to split at (inline = encoded[:split], overflow = encoded[split:])
    """
    budget = max_inline - reserve
    if budget <= 0:
        return 0  # no room for any inline content

    # Walk through the encoded bytes tracking character boundaries.
    pos = 0
    last_safe = 0
    in_text_mode = False       # event_script: True between 0x10 [P] and 0x00 [end]
    last_text_safe = 0         # event_script: last safe split inside a text window
    while pos < len(encoded):
        b = encoded[pos]
        if b == 0xFF and pos + 1 < len(encoded):
            sub = encoded[pos + 1]
            ctrl_len = ctrl_lengths.get(sub, 2)  # default 2 if unknown
            if pos + ctrl_len <= budget:
                last_safe = pos + ctrl_len
                if event_script and in_text_mode:
                    last_text_safe = pos + ctrl_len
                pos += ctrl_len
            else:
                break  # can't fit this control code inline
        elif b == 0x00:
            if event_script:
                # 0x00 ends text mode → back to event bytecodes.
                if pos + 1 <= budget:
                    if in_text_mode:
                        in_text_mode = False
                    last_safe = pos + 1
                    pos += 1
                else:
                    break
            else:
                # Non-event: 0x00 is final terminator → stop.
                break
        elif event_script and b == 0x10:
            # [P] — enters text display mode.
            in_text_mode = True
            if pos + 1 <= budget:
                last_safe = pos + 1
                pos += 1
            else:
                break
        else:
            if pos + 1 <= budget:
                last_safe = pos + 1
                if event_script and in_text_mode:
                    last_text_safe = pos + 1
                pos += 1
            else:
                break

    if event_script:
        return last_text_safe
    return last_safe


def insert_table_with_expansion(rom: bytearray, script_file: str, table_filename: str,
                                ptr_tbl_pos: int, tbl_len: int, source_rom: bytes,
                                data_start_pc: int = None,
                                cache_dir: str = None, force: bool = False,
                                fallback_table: str = None,
                                event_script: bool = False,
                                word_wrap: dict = None,
                                textbuf_limit: int = None,
                                verbose=False) -> dict:
    """
    Universal in-place script insertion.  Each entry is written back to its
    original ROM location.  If the encoded English text is longer than the
    original Japanese entry, the excess is redirected to expansion space in
    bank $C6 via FFC0 (native game mechanism — no custom ASM needed).

    Also resolves [FFC0@N] and [FFC0@N:label] cross-entry fixups.

    :param source_rom: original (unmodified) ROM bytes for reading original pointers
    :param dte_table_num: legacy DTE table number (unused, kept for API compat)
    :param data_start_pc: override data start (default: ptr_tbl_pos + tbl_len)
    :param word_wrap: word wrap config (passed to encode_script_file)
    :returns: dict with 'ffc0_overflow', 'inline_bytes', 'overflow_count', etc.
    """
    from retrotool.snes import SFCAddress, SFCAddressType

    num_ptrs = tbl_len // 2

    # Read original pointers from the UNMODIFIED source ROM to get entry positions.
    ptr_table_addr = SFCAddress(ptr_tbl_pos)
    ptr_bank = ptr_table_addr.get_bank_byte(SFCAddressType.LOROM1)

    orig_pcs = []
    for i in range(num_ptrs):
        off = ptr_tbl_pos + i * 2
        addr16 = source_rom[off] | (source_rom[off + 1] << 8)
        snes = (ptr_bank << 16) | addr16
        pc = SFCAddress(snes, SFCAddressType.LOROM1).get_address(SFCAddressType.PC)
        orig_pcs.append(pc)

    # Load table for ctrl_lengths (needed for entry size scanning and safe splitting).
    tbl = Table(table_filename)
    ctrl_lengths = tbl.ctrl_lengths

    # Measure each entry's actual size from the source ROM.
    # Uses find_entry_end (same as extraction) for text tables — this correctly
    # handles FF control code parameters that contain 0x00 bytes.
    # For event_script, 0x00 is not a terminator; use pointer-distance instead.
    ref_pc = data_start_pc if data_start_pc else ptr_tbl_pos
    bank_end_pc = ((ref_pc // 0x8000) + 1) * 0x8000
    # retrotool 0.9.0: SFCAddress returns None for SNES addrs outside the
    # LoROM window (e.g. $22:0011 system-area mirror ptrs that appear as
    # unused trailer entries in scene-desc-name). These get skipped below
    # (empty encoded → continue at the seen/encoded==\\x00 checks).
    valid_pcs = [pc for pc in orig_pcs if pc is not None]
    sorted_pcs = sorted(set(valid_pcs))
    rom_as_list = list(source_rom)  # find_entry_end expects list

    orig_entry_sizes = {}  # pc -> entry size as extraction sees it
    for pc in set(valid_pcs):
        idx = sorted_pcs.index(pc)
        next_pc = sorted_pcs[idx + 1] if idx + 1 < len(sorted_pcs) else bank_end_pc
        if event_script:
            # Event-script: 0x00 is not a terminator → use pointer distance.
            orig_entry_sizes[pc] = next_pc - pc
        else:
            # Must match verify_roundtrip's extraction: find_entry_end with
            # max_addr=next_pc.  This may return a size 1 byte larger than
            # the pointer distance when a multi-byte char match straddles
            # the boundary — that trailing byte matches the next entry's
            # first byte, so the overlap is benign when entries are written
            # in sorted order.
            end = tbl.find_entry_end(rom_as_list, pc, max_addr=next_pc)
            orig_entry_sizes[pc] = end - pc

    # Encode the English script file.
    # Pass ptr_tbl_pos as sub_table_filter so files with multiple sub-tables
    # (e.g. unit-attacks) only emit entries matching this table's headers.
    encoded_entries = encode_script_file(script_file, table_filename,
                                         cache_dir=cache_dir, force=force,
                                         fallback_table=fallback_table,
                                         word_wrap=word_wrap,
                                         sub_table_filter=ptr_tbl_pos,
                                         textbuf_limit=textbuf_limit)

    ffc0_overflow = []  # list of (entry_idx, fixup_pc, overflow_tail)
    overflow_count = 0
    inline_total = 0

    # Ensure ROM is large enough.
    if bank_end_pc > len(rom):
        rom.extend(b'\xff' * (bank_end_pc - len(rom)))

    seen = {}  # orig_pc -> already handled
    entry_pc_map = {}   # entry_idx -> PC offset (for FFC0@ fixup resolution)
    entry_labels_map = {}  # entry_idx -> {label: byte_offset}
    pending_fixups = []  # (rom_pc, target_idx, label)

    for i, entry_tuple in enumerate(encoded_entries):
        encoded = entry_tuple[0]
        fixups = entry_tuple[2] if len(entry_tuple) > 2 else []
        entry_labels = entry_tuple[3] if len(entry_tuple) > 3 else {}
        if i >= num_ptrs:
            break

        pc = orig_pcs[i]
        max_size = orig_entry_sizes.get(pc, 0)

        # Track entry position for FFC0@ fixup resolution.
        entry_pc_map[i] = pc
        if entry_labels:
            entry_labels_map[i] = entry_labels

        # Skip duplicate-pointer entries (share same data location).
        if pc in seen:
            continue
        seen[pc] = True

        # Skip empty entries (just a null terminator) — preserve original ROM
        # data.  Event-script tables have bytecodes at these positions; writing
        # 0x00 over them crashes the event engine.
        if encoded == b'\x00':
            continue

        if len(encoded) <= max_size:
            # Fits inline — write directly.
            # No padding: tables share banks, and padding could overwrite
            # another table's data.  The 0x00 terminator in encoded data
            # is sufficient — leftover JP bytes are never read.
            rom[pc:pc + len(encoded)] = encoded
            inline_total += len(encoded)
        else:
            # Overflow — split with FFC0 redirect to expansion space.
            # FFC0 permanently redirects the text pointer.  The entire tail
            # goes to expansion space in bank $C6.  No custom ASM needed.

            if event_script:
                # Event-script overflow: find the last text window whose text
                # we can redirect.  Layout:
                #   Inline: encoded[:tw_start+1] + FF C0 (placeholder)
                #           [P] stays inline, FFC0 right after it
                #   Overflow: encoded[tw_start+1:tw_end] + FF C0 → back to ROM [end]
                #           text content in $C6, then redirect back for [end]
                # Bytecodes are NEVER overwritten — [end] and everything after
                # remain intact in original ROM.
                tw_start, tw_end = _find_last_overflow_text_window(
                    encoded, max_size, ctrl_lengths, reserve=5)
                if tw_start is None:
                    print(f'  SKIP entry {i}: no text window found for overflow')
                    continue

                # Split right after [P] (tw_start is the 0x10 position).
                split = tw_start + 1
                inline_part = encoded[:split]

                # Build redirect: inline up to [P], then FF C0 placeholder.
                redirect = inline_part + b'\xFF\xC0\xFF\xFF\xFF'
                assert len(redirect) <= max_size, (
                    f'Entry {i}: FFC0 redirect ({len(redirect)}) > max_size ({max_size})')
                rom[pc:pc + len(redirect)] = redirect
                ffc0_fixup_pc = pc + len(inline_part) + 2

                # Overflow tail: text content (without [P] and without [end]),
                # plus FF C0 redirect back to [end] in original ROM.
                text_content = encoded[split:tw_end]  # text between [P] and [end]
                # Build return redirect: FF C0 + SNES addr of (pc + tw_end)
                return_pc = pc + tw_end
                return_snes = SFCAddress(return_pc).get_address(SFCAddressType.LOROM1)
                return_addr = bytes([
                    return_snes & 0xFF,
                    (return_snes >> 8) & 0xFF,
                    (return_snes >> 16) & 0xFF
                ])
                overflow_tail = text_content + b'\xFF\xC0' + return_addr

                if verbose:
                    print(f'  SPLIT entry {i}: encoded={len(encoded)} max={max_size} '
                          f'tw={tw_start}-{tw_end} split={split} '
                          f'text={len(text_content)}b overflow={len(overflow_tail)}b '
                          f'return→${return_snes:06X}')
            else:
                split = _find_safe_split(encoded, max_size, ctrl_lengths,
                                         event_script=False, reserve=5)
                if split == 0 and max_size < 5:
                    # Original slot is smaller than a 5-byte FFC0 redirect —
                    # can't overflow, preserve original JP bytes.
                    continue

                inline_part = encoded[:split]

                # Build FFC0 redirect: inline_part + FF C0 + placeholder (3 bytes).
                redirect = inline_part + b'\xFF\xC0\xFF\xFF\xFF'
                assert len(redirect) <= max_size, (
                    f'Entry {i}: FFC0 redirect ({len(redirect)}) > max_size ({max_size})')

                # Write inline portion + redirect (no padding — banks are shared).
                rom[pc:pc + len(redirect)] = redirect

                # Record the fixup position and the overflow tail.
                ffc0_fixup_pc = pc + len(inline_part) + 2  # offset of the 3-byte addr
                overflow_tail = encoded[split:]  # includes the final 0x00 terminator

            # Track which fixups land in the overflow tail (tail-relative offset).
            tail_fixups = []
            for fixup_tuple in fixups:
                foff, fidx = fixup_tuple[0], fixup_tuple[1]
                flabel = fixup_tuple[2] if len(fixup_tuple) > 2 else None
                if foff >= split:
                    tail_fixups.append((foff - split, fidx, flabel))
                else:
                    pending_fixups.append((pc + foff, fidx, flabel))

            ffc0_overflow.append((i, ffc0_fixup_pc, overflow_tail, tail_fixups))
            overflow_count += 1
            inline_total += len(redirect)
            continue

        # Non-overflow: all fixups are in the inline slot.
        for fixup_tuple in fixups:
            foff, fidx = fixup_tuple[0], fixup_tuple[1]
            flabel = fixup_tuple[2] if len(fixup_tuple) > 2 else None
            pending_fixups.append((pc + foff, fidx, flabel))

    # Resolve [FFC0@N] and [FFC0@N:label] cross-entry fixups (inline slots only).
    def _resolve_target(target_idx, label):
        if target_idx not in entry_pc_map:
            print(f'  WARNING: [FFC0@{target_idx}] references missing entry {target_idx}')
            return None
        target_pc = entry_pc_map[target_idx]
        if label:
            target_labels = entry_labels_map.get(target_idx, {})
            if label not in target_labels:
                print(f'  WARNING: [FFC0@{target_idx}:{label}] — label "{label}" '
                      f'not found in entry {target_idx}')
                return None
            target_pc += target_labels[label]
        return SFCAddress(target_pc).get_address(SFCAddressType.LOROM2)

    # Resolve overflow-tail fixups: convert each (tail_off, target_idx, label)
    # into (tail_off, resolved_snes) so write_ffc0_overflow can patch the tail
    # after it lands in bank $C6.  Must happen now, while entry_pc_map is in
    # scope for this table.
    resolved_overflow = []
    for entry_idx, fixup_pc, tail, tail_fixups in ffc0_overflow:
        resolved_tail_fixups = []
        for tail_off, target_idx, label in tail_fixups:
            snes = _resolve_target(target_idx, label)
            if snes is None:
                continue
            resolved_tail_fixups.append((tail_off, snes))
            ref = f'FFC0@{target_idx}:{label}' if label else f'FFC0@{target_idx}'
            if verbose:
                print(f'    entry {entry_idx} tail {ref} → ${snes:06X}')
        resolved_overflow.append((entry_idx, fixup_pc, tail, resolved_tail_fixups))
    ffc0_overflow = resolved_overflow

    for rom_pc, target_idx, label in pending_fixups:
        target_snes = _resolve_target(target_idx, label)
        if target_snes is None:
            continue
        rom[rom_pc]     = target_snes & 0xFF
        rom[rom_pc + 1] = (target_snes >> 8) & 0xFF
        rom[rom_pc + 2] = (target_snes >> 16) & 0xFF
        ref = f'FFC0@{target_idx}:{label}' if label else f'FFC0@{target_idx}'
        if verbose:
            print(f'    {ref} → ${target_snes:06X}')

    return {
        'ffc0_overflow': ffc0_overflow,
        'inline_bytes': inline_total,
        'overflow_count': overflow_count,
        'total_entries': len(encoded_entries),
    }


# def write_dte_expansion(rom: bytearray, dte_results: list[dict]):
#     """
#     Write DTE expansion strings and pointer tables into bank $C6.
#
#     :param dte_results: list of dicts from insert_dte_table() calls
#     """
#     from retrotool.snes import SFCAddress, SFCAddressType
#
#     for result in dte_results:
#         tbl_num = result['dte_table_num']
#         entries = result['dte_entries']
#         if not entries:
#             continue
#
#         if tbl_num == 1:
#             ptr_pc = DTE_TABLE1_PTR_PC
#             data_pc = DTE_TABLE1_DATA_PC
#         else:
#             ptr_pc = DTE_TABLE2_PTR_PC
#             data_pc = DTE_TABLE2_DATA_PC
#
#         # Ensure ROM is large enough for expansion area.
#         max_needed = data_pc + sum(len(exp) for _, exp in entries)
#         if max_needed > len(rom):
#             rom.extend(b'\xff' * (max_needed - len(rom)))
#
#         # Write expansion strings and build pointer table.
#         data_offset = data_pc
#         for dte_idx, expansion in entries:
#             # Write 2-byte within-bank pointer.
#             snes_addr = SFCAddress(data_offset).get_address(SFCAddressType.LOROM2)
#             ptr_val = snes_addr & 0xFFFF  # within-bank 16-bit address
#             ptr_off = ptr_pc + dte_idx * 2
#             rom[ptr_off] = ptr_val & 0xFF
#             rom[ptr_off + 1] = (ptr_val >> 8) & 0xFF
#
#             # Write expansion string data.
#             rom[data_offset:data_offset + len(expansion)] = expansion
#             data_offset += len(expansion)
#
#         total_data = data_offset - data_pc
#         print(f'  DTE table {tbl_num}: {len(entries)} expansion strings, '
#               f'{total_data} bytes in bank $C6')


# ---------------------------------------------------------------------------
# FFC0 overflow — write event-text overflow tails to expansion space
# ---------------------------------------------------------------------------
# For event_script tables where DTE can't work (interleaved bytecodes),
# FFC0 redirects the text pointer permanently.  The overflow tail (all
# remaining bytes including subsequent sub-entries) is placed in bank $C6.
# No custom ASM needed — FFC0 is a native game mechanism.
# ---------------------------------------------------------------------------

FFC0_OVERFLOW_DATA_PC = DTE_TABLE1_DATA_PC   # reuse DTE table 1 data area


def insert_event_script_windowed(rom: bytearray, script_file: str,
                                 table_filename: str, ptr_tbl_pos: int,
                                 tbl_len: int, source_rom: bytes,
                                 fallback_table: str = None,
                                 force: bool = False,
                                 cache_dir: str = None,
                                 verbose: bool = False) -> dict:
    """
    Insert event-script text using the windowed format.  For each text window
    in each entry, writes [P] + FFC0 redirect at the window's original ROM
    position, puts the encoded EN text + FFC0-back in $C6 expansion space.

    Bytecodes are never touched — only the text within windows is replaced.

    Returns dict with 'ffc0_overflow' list for write_ffc0_overflow().
    """
    from retrotool.snes import SFCAddress, SFCAddressType

    num_ptrs = tbl_len // 2

    # Read original pointers from source ROM.
    ptr_table_addr = SFCAddress(ptr_tbl_pos)
    ptr_bank = ptr_table_addr.get_bank_byte(SFCAddressType.LOROM1)

    orig_pcs = []
    for i in range(num_ptrs):
        off = ptr_tbl_pos + i * 2
        addr16 = source_rom[off] | (source_rom[off + 1] << 8)
        snes = (ptr_bank << 16) | addr16
        pc = SFCAddress(snes, SFCAddressType.LOROM1).get_address(SFCAddressType.PC)
        orig_pcs.append(pc)

    # Load table for ctrl_lengths (needed for auto-expanding small windows).
    tbl = Table(table_filename)
    ctrl_lengths = tbl.ctrl_lengths

    # Encode windowed script file.
    windowed_entries = encode_event_script_windowed(
        script_file, table_filename,
        fallback_table=fallback_table, force=force,
        cache_dir=cache_dir)

    ffc0_overflow = []
    window_count = 0

    for i, entry_windows in enumerate(windowed_entries):
        if entry_windows is None or i >= num_ptrs:
            continue

        pc = orig_pcs[i]

        for start, end, encoded_text in entry_windows:
            if not encoded_text:
                continue  # empty window, skip

            # Need 6 bytes minimum: $START(1) + FF C0(2) + addr(3).
            # Byte at $START stays in ROM; FFC0 written at start+1.
            window_size = end - start
            absorbed_suffix = b''

            # When window too small, absorb the byte at $END (typically
            # [end]=0x00) into the overflow.  This extends the overwrite
            # region by 1 byte, giving FFC0 room to fit.  The absorbed
            # byte is appended to the overflow text so the text engine
            # still processes it.  Return FFC0 jumps past absorbed byte.
            if window_size < 6:
                end_byte = source_rom[pc + end]
                if end_byte == 0x00:  # [end]
                    absorbed_suffix = b'\x00'
                    end += 1
                    window_size = end - start
                elif end_byte == 0xFF:
                    # Absorb a safe FF control code (not FFC0/FFF0).
                    code = source_rom[pc + end + 1]
                    if code not in (0xC0, 0xF0):
                        cmd_len = ctrl_lengths.get(code, 2)
                        absorbed_suffix = bytes(
                            source_rom[pc + end : pc + end + cmd_len])
                        end += cmd_len
                        window_size = end - start
                if window_size < 6:
                    continue  # still too small

            # Compare encoded text to original ROM bytes.  If identical,
            # skip the redirect — no point rewriting unchanged text, and
            # false-positive 0x10 windows would corrupt bytecodes.
            orig_end = end - len(absorbed_suffix)
            orig_text = bytes(source_rom[pc + start + 1 : pc + orig_end])
            if encoded_text == orig_text:
                continue  # unchanged, skip redirect

            # Write FFC0 placeholder at start+1 in ROM.
            # Byte at $START stays in place.
            ffc0_pc = pc + start + 1
            rom[ffc0_pc:ffc0_pc + 5] = b'\xFF\xC0\xFF\xFF\xFF'

            # Build overflow: encoded text + absorbed suffix + FFC0 return.
            # Return FFC0 points to the byte after the absorbed region.
            return_pc = pc + end
            return_snes = SFCAddress(return_pc).get_address(SFCAddressType.LOROM1)
            return_addr = bytes([
                return_snes & 0xFF,
                (return_snes >> 8) & 0xFF,
                (return_snes >> 16) & 0xFF
            ])
            overflow_tail = encoded_text + absorbed_suffix + b'\xFF\xC0' + return_addr

            # Record: (entry_idx, fixup_pc, overflow_tail, tail_fixups)
            # fixup_pc = location of the 3-byte addr placeholder in the forward FFC0
            ffc0_overflow.append((i, ffc0_pc + 2, overflow_tail, []))
            window_count += 1

    print(f'  event-text windowed: {window_count} windows redirected')
    return {'ffc0_overflow': ffc0_overflow}


def write_ffc0_overflow(rom: bytearray, dte_results: list[dict], verbose: bool = False):
    """
    Write FFC0 overflow tails into bank $C6 and patch the inline FFC0
    placeholders with the resolved SNES addresses.

    :param dte_results: list of dicts from insert_dte_table() calls
    """
    from retrotool.snes import SFCAddress, SFCAddressType

    all_overflow = []
    for result in dte_results:
        all_overflow.extend(result.get('ffc0_overflow', []))

    if not all_overflow:
        return

    data_pc = FFC0_OVERFLOW_DATA_PC

    # Ensure ROM is large enough.
    total_bytes = sum(len(item[2]) for item in all_overflow)
    max_needed = data_pc + total_bytes
    if max_needed > len(rom):
        rom.extend(b'\xff' * (max_needed - len(rom)))

    data_offset = data_pc
    for item in all_overflow:
        entry_idx, fixup_pc, overflow_tail = item[0], item[1], item[2]
        tail_fixups = item[3] if len(item) > 3 else []
        # Write overflow tail to expansion area.
        rom[data_offset:data_offset + len(overflow_tail)] = overflow_tail

        # Patch any [FFC0@N] cross-entry fixups embedded in the tail.  These
        # were resolved to SNES addresses at encode time (when entry_pc_map
        # was still in scope for the table).
        for tail_off, target_snes in tail_fixups:
            abs_pc = data_offset + tail_off
            rom[abs_pc]     = target_snes & 0xFF
            rom[abs_pc + 1] = (target_snes >> 8) & 0xFF
            rom[abs_pc + 2] = (target_snes >> 16) & 0xFF

        # Resolve the 3-byte SNES address at the FFC0 fixup location.
        snes = SFCAddress(data_offset).get_address(SFCAddressType.LOROM2)
        rom[fixup_pc]     = snes & 0xFF
        rom[fixup_pc + 1] = (snes >> 8) & 0xFF
        rom[fixup_pc + 2] = (snes >> 16) & 0xFF

        if verbose:
            print(f'    entry {entry_idx}: FFC0 → ${snes:06X} ({len(overflow_tail)} bytes)')
        data_offset += len(overflow_tail)

    total_data = data_offset - data_pc
    print(f'  FFC0 overflow: {len(all_overflow)} entries, {total_data} bytes in bank $C6')


def copy_entry0_raw_strings(rom: bytearray) -> int:
    """
    Copy meta-table entry 0's 16 raw JP strings (sub 0-15) from their
    original bank $02 location into the $C5 data area, building 3-byte
    pointers at $C5:$8000 for each.

    These entries contain raw binary data (PPU register sequences, DMA
    descriptors, control codes) with embedded 0x00 bytes — NOT null-terminated
    text.  They must be copied byte-for-byte using pointer-based bounding.

    Must be called BEFORE battle table insertion (which chains after).

    Returns the PC address of the next free byte after the copied strings.
    """
    from retrotool.snes import SFCAddress, SFCAddressType

    # Original entry 0 pointer table: 2-byte ptrs, bank $02
    SRC_PTR_TBL = 0x0130E0
    SRC_BANK = 0x02
    NUM_RAW = 16

    # Destination: bank $C5
    DST_PTR_TBL = 0x228000   # 200-entry 3-byte ptr table
    DST_DATA_START = 0x228258  # after 200 × 3 = 0x258 bytes of pointers

    # Read ALL 200 original 2-byte pointers (need full set for bounding).
    all_src_pcs = []
    for i in range(200):
        off = SRC_PTR_TBL + i * 2
        snes_addr = rom[off] | (rom[off + 1] << 8) | (SRC_BANK << 16)
        pc = SFCAddress(snes_addr, SFCAddressType.LOROM1).get_address(SFCAddressType.PC)
        all_src_pcs.append(pc)

    # Build sorted unique addresses from all 200 pointers for bounding.
    # Entry 0's sub-entries contain raw binary data (PPU register sequences,
    # DMA descriptors) with embedded 0x00 bytes — NOT null-terminated text.
    # We must use pointer ordering to determine entry boundaries.
    sorted_unique = sorted(set(all_src_pcs))

    data_pos = DST_DATA_START

    # Ensure ROM is large enough for destination
    est_max = DST_DATA_START + 4096  # generous estimate
    if est_max > len(rom):
        rom.extend(b'\xff' * (est_max - len(rom)))

    # Copy each unique source address once, map duplicates to same dest ptr.
    src_to_dst_ptr = {}  # src_pc -> 3-byte SNES pointer bytes

    for i in range(NUM_RAW):
        src_pc = all_src_pcs[i]

        if src_pc in src_to_dst_ptr:
            # Duplicate pointer — reuse already-copied data
            ptr_bytes = src_to_dst_ptr[src_pc]
        else:
            # Bound by next unique pointer address
            idx_in_sorted = sorted_unique.index(src_pc)
            if idx_in_sorted + 1 < len(sorted_unique):
                end = sorted_unique[idx_in_sorted + 1]
            else:
                end = src_pc + 256  # fallback for last entry
            raw_data = bytes(rom[src_pc:end])

            # Ensure space
            if data_pos + len(raw_data) > len(rom):
                rom.extend(b'\xff' * (data_pos + len(raw_data) - len(rom)))

            # Write raw string data to $C5
            rom[data_pos:data_pos + len(raw_data)] = raw_data

            # Build 3-byte SNES pointer
            snes = SFCAddress(data_pos).get_address(SFCAddressType.LOROM2)
            ptr_bytes = bytes([snes & 0xFF, (snes >> 8) & 0xFF, (snes >> 16) & 0xFF])
            src_to_dst_ptr[src_pc] = ptr_bytes

            data_pos += len(raw_data)

        # Write 3-byte pointer for this sub-index
        ptr_off = DST_PTR_TBL + i * 3
        rom[ptr_off:ptr_off + 3] = ptr_bytes

    total_raw = data_pos - DST_DATA_START
    print(f'  entry-0 raw strings: {total_raw} bytes copied to $C5 (sub 0-15)')

    return data_pos


def insert_fixed_table(rom: bytearray, script_file: str, table_filename: str,
                       tbl_info: dict, fallback_table: str = None,
                       cache_dir: str = None, force: bool = False):
    """
    Insert translated text into fixed-length fields within ROM data records.

    Reads the script file, matches each entry to its field by index+label,
    encodes the text, pads/truncates to the fixed field width, and patches
    it directly into the ROM at the correct offset within each record.

    Caches encoded patches as:
      {cache_dir}/{name}.bin       — packed (offset:4, len:4, data) patches
      {cache_dir}/{name}.checksum  — SHA-256 of inputs

    Returns the number of fields written.
    """
    import re, hashlib, os

    name = tbl_info['name']

    # Compute checksum over script + table file + source files.
    h = hashlib.sha256()
    # NO NEED TO COMPUTE HASH INCLUDING SOURCE FILES
    # WHEN A BREAKING CHANGE IS MADE, USE --FORCE
    # src_dir = os.path.dirname(os.path.abspath(__file__))
    # source_files = [
    #     os.path.join(src_dir, 'lm3.py'),
    #     os.path.join(src_dir, 'retrotool', 'script.py'),
    #     os.path.join(src_dir, 'retrotool', 'snes.py'),
    # ]
    for path in [script_file, table_filename]:
        with open(path, 'rb') as f:
            h.update(f.read())
    if fallback_table:
        with open(fallback_table, 'rb') as f:
            h.update(f.read())
    current_checksum = h.hexdigest()

    # Check cache if it's not forced
    bin_path = cksum_path = None
    if cache_dir and not force:
        os.makedirs(cache_dir, exist_ok=True)
        bin_path = os.path.join(cache_dir, f'{name}.bin')
        cksum_path = os.path.join(cache_dir, f'{name}.checksum')

        if os.path.exists(cksum_path) and os.path.exists(bin_path):
            with open(cksum_path, 'r') as f:
                cached_checksum = f.read().strip()
            if cached_checksum == current_checksum:
                # Cache hit — replay patches directly into ROM.
                with open(bin_path, 'rb') as f:
                    data = f.read()
                pos = 0
                written = 0
                while pos < len(data):
                    rom_offset = int.from_bytes(data[pos:pos+4], 'little')
                    pos += 4
                    field_len = int.from_bytes(data[pos:pos+4], 'little')
                    pos += 4
                    padded = data[pos:pos+field_len]
                    pos += field_len
                    if rom_offset + field_len > len(rom):
                        rom.extend(b'\xff' * (rom_offset + field_len - len(rom)))
                    rom[rom_offset:rom_offset + field_len] = padded
                    written += 1
                return written

    # Cache miss — encode from scratch.
    tbl = Table(table_filename)
    fb_tbl = Table(fallback_table) if fallback_table else None

    text = _read_script_text(script_file)

    data_pos = tbl_info['data_pos']
    block_len = tbl_info['block_len']
    entries = tbl_info['entries']
    fields = tbl_info['fields']

    # Build a lookup: (index, label) -> field config
    field_by_label = {f['label']: f for f in fields}

    # Parse the script file into (index, label, content) tuples
    parsed = []
    for entry in text.split('<<')[1:]:
        if '>>' not in entry:
            continue
        header = entry.split('>>')[0]
        content = entry.split('>>')[1]
        if content.startswith('\n'):
            content = content[1:]
        content = content.rstrip('\n\r\t ')

        # Header format: $73808:5.name or $377344:0.class
        m = re.match(r'\$\d+:(\d+)\.(\w+)', header)
        if not m:
            continue
        idx = int(m.group(1))
        label = m.group(2)
        parsed.append((idx, label, content))

    # Ensure the ROM is large enough for the table data.
    required_end = data_pos + entries * block_len
    if required_end > len(rom):
        rom.extend(b'\xff' * (required_end - len(rom)))

    patches = []  # (rom_offset, padded_bytes) for cache
    written = 0
    for idx, label, content in parsed:
        if idx >= entries:
            print(f'  WARNING: {script_file} entry {idx} exceeds table size ({entries})')
            continue
        field = field_by_label.get(label)
        if field is None:
            print(f'  WARNING: {script_file} unknown field label "{label}"')
            continue

        field_len = field['len']
        fill = field['fill']

        # Encode the text
        encoded = encode_text(content, tbl, fallback_tbl=fb_tbl)

        if len(encoded) > field_len:
            print(f'  WARNING: {name}:{idx}.{label} '
                  f'encoded to {len(encoded)} bytes, truncating to {field_len}')
            encoded = encoded[:field_len]

        # Pad to field length
        padded = encoded + bytes([fill]) * (field_len - len(encoded))

        # Write into ROM
        rom_offset = data_pos + idx * block_len + field['start']
        rom[rom_offset:rom_offset + field_len] = padded
        patches.append((rom_offset, padded))
        written += 1

    # Write cache.
    if bin_path:
        with open(bin_path, 'wb') as f:
            for rom_offset, padded in patches:
                f.write(rom_offset.to_bytes(4, 'little'))
                f.write(len(padded).to_bytes(4, 'little'))
                f.write(padded)
        if cksum_path:
            with open(cksum_path, 'w') as f:
                f.write(current_checksum)

    return written


def insert_all_fixed(rom: bytearray,
                     en_folder: str = 'en_data/scripts',
                     table_filename: str = 'en_data/eng.tbl',
                     tables_filter: list = None,
                     force: bool = False,
                     verbose: bool = False):
    """
    Insert all fixed-length translated text tables into the ROM bytearray.
    """
    import os

    for tbl_info in FIXED_TABLES:
        name = tbl_info['name']
        if tables_filter is not None and name not in tables_filter:
            continue

        script_file = os.path.join(en_folder, f'{name}.txt')
        if not os.path.exists(script_file):
            print(f'  skip {name} (not found: {script_file})')
            continue

        fb_tbl = 'jp_data/jap.tbl' if table_filename != 'jp_data/jap.tbl' else None
        cache_dir = _bin_dir(en_folder)
        written = insert_fixed_table(rom, script_file, table_filename,
                                     tbl_info, fallback_table=fb_tbl,
                                     cache_dir=cache_dir, force=force)
        print(f'  {name}: {written} fields written')


def fixup_event_text_addresses(rom: bytearray, source_rom_path: str,
                               old_ptr_tbl_pos: int, new_ptr_tbl_pos: int,
                               tbl_len: int, bank: int = 0x22,
                               **_kwargs) -> int:
    """
    Patch embedded 3-byte SNES addresses in event-text bytecodes after relocation.

    Uses forward-scan alignment between old (JP) and new (EN) entry data.
    Bytecodes are identical in both; only text regions differ in content and
    length.  The alignment walks both byte streams in parallel, matching runs
    of identical bytes (bytecodes) and skipping divergent runs (text).

    :param rom: The ROM bytearray (already has new data inserted).
    :param source_rom_path: Path to the original (unpatched) ROM.
    :param old_ptr_tbl_pos: PC address of the original pointer table.
    :param new_ptr_tbl_pos: PC address of the relocated pointer table.
    :param tbl_len: Pointer table size in bytes (num_entries * 2).
    :param bank: Bank byte for the data (default 0x22).
    :returns: Number of addresses patched.
    """
    import struct
    from bisect import bisect_right

    num_entries = tbl_len // 2
    bank_base_pc = (bank & 0x7F) * 0x8000

    def snes_to_pc(snes_addr):
        return bank_base_pc + ((snes_addr & 0xFFFF) - 0x8000)

    def pc_to_snes(pc):
        return (bank << 16) | ((pc - bank_base_pc) + 0x8000)

    # --- Read pointer tables ---
    with open(source_rom_path, 'rb') as f:
        orig_rom = f.read()

    old_snes = []
    for i in range(num_entries):
        ptr = struct.unpack_from('<H', orig_rom, old_ptr_tbl_pos + i * 2)[0]
        old_snes.append((bank << 16) | ptr)
    old_pc = [snes_to_pc(s) for s in old_snes]

    new_snes = []
    for i in range(num_entries):
        ptr = struct.unpack_from('<H', rom, new_ptr_tbl_pos + i * 2)[0]
        new_snes.append((bank << 16) | ptr)
    new_pc = [snes_to_pc(s) for s in new_snes]

    old_unique_sorted = sorted(set(old_pc))
    new_unique_sorted = sorted(set(new_pc))

    def get_old_entry_end(pc):
        idx = old_unique_sorted.index(pc)
        if idx + 1 < len(old_unique_sorted):
            return old_unique_sorted[idx + 1]
        pos = pc
        while pos < len(orig_rom) - 1:
            if orig_rom[pos] == 0x00:
                if pos + 1 < len(orig_rom) and orig_rom[pos + 1] in (0xAA, 0xA8, 0xA2):
                    return pos + 1
            pos += 1
        return pos

    def get_new_entry_end(npc_val):
        idx = new_unique_sorted.index(npc_val)
        if idx + 1 < len(new_unique_sorted):
            return new_unique_sorted[idx + 1]
        # Last unique entry: use generous bound from old entry size.
        return None

    # --- Forward-scan alignment ---
    def align_entries(old_bytes, new_bytes):
        """Build old→new byte offset mapping.

        Walk old and new in parallel.  When bytes match, record mapping.
        When they diverge (text region), find the best reconvergence
        point — the longest matching anchor in both streams.
        """
        mapping = {}
        oi, ni = 0, 0

        while oi < len(old_bytes) and ni < len(new_bytes):
            if old_bytes[oi] == new_bytes[ni]:
                mapping[oi] = ni
                oi += 1
                ni += 1
            else:
                # Divergent region.  Find the best reconvergence: try each
                # skip distance in old_bytes, measure match length, and
                # pick the candidate with the longest contiguous match.
                max_skip = min(800, len(old_bytes) - oi)
                best = None  # (match_len, d_o, new_pos)

                for d_o in range(1, max_skip):
                    if oi + d_o + 3 > len(old_bytes):
                        break
                    anchor = old_bytes[oi + d_o:oi + d_o + 3]
                    search_lo = max(ni + 1, ni - 20)
                    search_hi = min(ni + d_o + 400, len(new_bytes) - 2)

                    # Check all occurrences of anchor in the window.
                    sf = search_lo
                    while sf < search_hi:
                        pos = new_bytes.find(anchor, sf, search_hi)
                        if pos == -1:
                            break
                        # Measure total contiguous match length.
                        ml = 3
                        while (oi + d_o + ml < len(old_bytes) and
                               pos + ml < len(new_bytes) and
                               old_bytes[oi + d_o + ml] == new_bytes[pos + ml]):
                            ml += 1
                        if ml >= 3:
                            if best is None or ml > best[0]:
                                best = (ml, d_o, pos)
                            if ml >= 8:
                                break  # long enough, accept early
                        sf = pos + 1

                    # Once we have a match >= 8, stop searching further.
                    if best and best[0] >= 8:
                        break

                if best:
                    _, d_o, pos = best
                    oi += d_o
                    ni = pos
                else:
                    break

        return mapping

    # --- Build per-entry alignment maps ---
    old_entry_data = {}
    old_to_new_pc = {}
    offset_maps = {}
    processed = set()

    for i in range(num_entries):
        opc = old_pc[i]
        if opc in processed:
            continue
        processed.add(opc)

        old_end = get_old_entry_end(opc)
        old_data = bytes(orig_rom[opc:old_end])
        old_entry_data[opc] = old_data
        npc = new_pc[i]
        old_to_new_pc[opc] = npc

        ne = get_new_entry_end(npc)
        if ne is None:
            ne = npc + len(old_data) + 500
            if ne > len(rom):
                ne = len(rom)
        new_data = bytes(rom[npc:ne])

        offset_maps[opc] = align_entries(old_data, new_data)

    # --- Scan and patch ---
    old_data_min_snes = min(old_snes)
    old_data_max_snes = max(old_snes)
    last_entry_pc = snes_to_pc(old_data_max_snes)
    old_data_max_snes_end = pc_to_snes(get_old_entry_end(last_entry_pc))

    patched = 0

    for i in range(num_entries):
        opc = old_pc[i]
        if opc in set(old_pc[:i]):
            continue

        npc = new_pc[i]
        old_data = old_entry_data.get(opc)
        if old_data is None:
            continue
        mapping = offset_maps.get(opc, {})

        for off in range(len(old_data) - 2):
            if old_data[off + 2] != bank:
                continue
            old_addr_snes = (bank << 16) | (old_data[off + 1] << 8) | old_data[off]
            if old_addr_snes < old_data_min_snes or old_addr_snes >= old_data_max_snes_end:
                continue
            if off not in mapping or (off + 1) not in mapping or (off + 2) not in mapping:
                continue

            old_target_pc = snes_to_pc(old_addr_snes)
            idx = bisect_right(old_unique_sorted, old_target_pc) - 1
            if idx < 0:
                continue
            containing_opc = old_unique_sorted[idx]

            target_old_offset = old_target_pc - containing_opc
            target_mapping = offset_maps.get(containing_opc)
            if target_mapping is None or target_old_offset not in target_mapping:
                continue

            target_new_offset = target_mapping[target_old_offset]
            target_npc = old_to_new_pc.get(containing_opc)
            if target_npc is None:
                continue

            new_target_snes = pc_to_snes(target_npc + target_new_offset)
            new_lo = new_target_snes & 0xFF
            new_hi = (new_target_snes >> 8) & 0xFF

            rom_pos_lo = npc + mapping[off]
            rom_pos_hi = npc + mapping[off + 1]

            if rom[rom_pos_lo] != new_lo or rom[rom_pos_hi] != new_hi:
                rom[rom_pos_lo] = new_lo
                rom[rom_pos_hi] = new_hi
                patched += 1

    return patched


def insert_all_scripts(rom_path: str,
                       en_folder: str = 'en_data/scripts',
                       table_filename: str = 'en_data/eng.tbl',
                       tables_filter: list = None,
                       jp_tables: set = None,
                       force: bool = False,
                       source_rom: str = 'lm3.sfc',
                       verbose=False):
    """
    Insert translated script tables into rom_path in place.

    All tables are written at their original ROM positions using the original
    pointer tables.  Entries that overflow their original space are redirected
    to expansion space in bank $C6 via FFC0 (native game mechanism).
    No metatbl patches or table relocation needed.

    :param tables_filter: Optional list of table names to process.
    :param jp_tables: Set of table names to skip (preserve original JP ROM data).
    """
    import os
    from concurrent.futures import ProcessPoolExecutor
    import multiprocessing

    if jp_tables is None:
        jp_tables = set()

    with open(rom_path, 'rb') as f:
        rom = bytearray(f.read())

    # Build the list of tables to process with their source info.
    jobs = []
    for tbl_info in SCRIPT_TABLES:
        name = tbl_info['name']
        if tables_filter is not None and name not in tables_filter:
            continue

        if name in jp_tables:
            # JP tables: original ROM data is already correct — skip reinsertion.
            print(f'  skip {name} (JP — original ROM data preserved)')
            continue
        else:
            folder = en_folder
            tbl_file = table_filename
            lang_tag = ''

        script_file = os.path.join(folder, f'{name}.txt')
        if not os.path.exists(script_file):
            print(f'  skip {name} (not found: {script_file})')
            continue

        cache_dir = _bin_dir(folder)
        # When encoding with eng.tbl, use jap.tbl as fallback for untranslated chars
        fb_tbl = 'jp_data/jap.tbl' if tbl_file != 'jp_data/jap.tbl' else None
        jobs.append((tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl))

    # Pre-encode all scripts in parallel (encoding is CPU-bound; ROM writes are serial).
    print(f'Encoding {len(jobs)} script table(s)...')
    max_workers = max(1, int(multiprocessing.cpu_count() * 0.8))
    with ProcessPoolExecutor(max_workers=max_workers) as pool:
        futures = {}
        for tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl in jobs:
            fut = pool.submit(encode_script_file, script_file, tbl_file,
                              cache_dir=cache_dir, force=force,
                              fallback_table=fb_tbl,
                              word_wrap=tbl_info.get('word_wrap'),
                              sub_table_filter=tbl_info.get('ptr_tbl_pos'),
                              textbuf_limit=tbl_info.get('textbuf_limit'))
            futures[tbl_info['name']] = fut
        # Wait for all to finish (also raises any exceptions).
        for name, fut in futures.items():
            fut.result()
            print(f'  encoded: {name}')

    # Read original ROM for pointer positions.
    with open(source_rom, 'rb') as f:
        orig_rom = f.read()

    # Pre-scan all en files for raw [FFC0HHLLBB] pins.  Entries whose interior
    # is referenced by such pins must be preserved as JP (translation would
    # invalidate the external reference). No longer used.
    # ffc0_pins = _collect_ffc0_pins(en_folder)
    # if ffc0_pins:
    #     print(f'  collected {len(ffc0_pins)} external FFC0 pin target(s)')

    # Insert all tables in-place with FFC0 overflow to bank $C6.
    print('Inserting into ROM (in-place + FFC0 overflow)...')
    all_results = []

    for tbl_info, script_file, tbl_file, cache_dir, lang_tag, fb_tbl in jobs:
        name = tbl_info['name']

        if tbl_info.get('event_script', False):
            # Windowed insertion for event-script tables.
            result = insert_event_script_windowed(
                rom, script_file, tbl_file,
                tbl_info['ptr_tbl_pos'], tbl_info['tbl_len'],
                source_rom=orig_rom,
                fallback_table=fb_tbl,
                force=force,
                cache_dir=cache_dir,
                verbose=verbose
            )
            all_results.append(result)
            ffc0_count = len(result.get('ffc0_overflow', []))
            print(f'  {name}: {ffc0_count} window redirects → FFC0{lang_tag}')
        else:
            result = insert_table_with_expansion(
                rom, script_file, tbl_file,
                tbl_info['ptr_tbl_pos'], tbl_info['tbl_len'],
                source_rom=orig_rom,
                data_start_pc=tbl_info.get('data_start_pc'),
                cache_dir=cache_dir, force=force,
                fallback_table=fb_tbl,
                event_script=False,
                word_wrap=tbl_info.get('word_wrap'),
                textbuf_limit=tbl_info.get('textbuf_limit'),
                verbose=verbose,
            )
            all_results.append(result)
            oc = result['overflow_count']
            ffc0_count = len(result.get('ffc0_overflow', []))
            total = result['total_entries']
            if ffc0_count:
                print(f'  {name}: {total} entries, {ffc0_count} overflow → FFC0{lang_tag}')
            elif oc:
                print(f'  {name}: {total} entries, {oc} overflow (preserved JP){lang_tag}')
            else:
                print(f'  {name}: {total} entries, all inline{lang_tag}')

            # If the script file has <<<window>>> entries, run a windowed pass
            # for those entries (insert_dte_table skipped them as empty).
            script_text = _read_script_text(script_file)
            if '<<<window' in script_text:
                windowed_result = insert_event_script_windowed(
                    rom, script_file, tbl_file,
                    tbl_info['ptr_tbl_pos'], tbl_info['tbl_len'],
                    source_rom=orig_rom,
                    fallback_table=fb_tbl,
                    force=force,
                    cache_dir=cache_dir,
                )
                all_results.append(windowed_result)
                wc = len(windowed_result.get('ffc0_overflow', []))
                if wc:
                    print(f'  {name}: {wc} windowed entries → FFC0{lang_tag}')

    # Write FFC0 overflow data to bank $C6.
    if all_results:
        write_ffc0_overflow(rom, all_results, verbose)

    with open(rom_path, 'wb') as f:
        f.write(rom)

    print(f'All scripts inserted → {rom_path}')


def build_scripted(source: str = 'lm3.sfc',
                   output: str = 'out/lm3_scripted.sfc',
                   font_png: str = 'en_data/fonts/font_accented.png',
                   font_rom_offset: int = 0x170000,
                   scripts_folder: str = 'en_data/scripts',
                   table_filename: str = 'en_data/eng.tbl',
                   tables_filter: list = None,
                   jp_tables: set = None,
                   force: bool = False,
                   verbose: bool = False):
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
    font_dir = os.path.dirname(font_png) or 'en_data/fonts'
    stem = os.path.splitext(os.path.basename(font_png))[0]
    il_path = os.path.join(_bin_dir(font_dir), f'{stem}_1bppil.bin')
    with open(il_path, 'rb') as f:
        font_data = f.read()
    with open(output, 'r+b') as f:
        f.seek(font_rom_offset)
        f.write(font_data)
    print(f'  Font patched into ROM at 0x{font_rom_offset:X}')

    insert_all_scripts(output, en_folder=scripts_folder, table_filename=table_filename,
                       tables_filter=tables_filter, jp_tables=jp_tables,
                       force=force, verbose=verbose)

    # Insert fixed-length tables (unit names, classes, items, equipment).
    with open(output, 'rb') as f:
        rom = bytearray(f.read())
    insert_all_fixed(rom, en_folder=scripts_folder, table_filename=table_filename,
                     tables_filter=tables_filter, force=force, verbose=verbose)
    with open(output, 'wb') as f:
        f.write(rom)

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

    # Apply ASM patches via asar.
    # With in-place insertion + FFC0 overflow, no metatbl patches are needed.
    # name_expansion_patch.asm: unit name relocation to bank $C4 (fixed-width table).
    import os as _os
    import subprocess

    asm_patches = ['asm/debug_mode_patch.asm']
    # name_expansion_patch relocates unit-name reads to $C4:8000.  Only safe
    # when unit-names is actually being inserted — otherwise the expansion
    # region is uninitialized (0xFF) and the space-terminated copy loop runs
    # away forever.
    building_unit_names = tables_filter is None or 'unit-names' in tables_filter
    if target >= 4 * 1024 * 1024 and building_unit_names:
        asm_patches.append('asm/name_expansion_patch.asm')

    for patch_file in asm_patches:
        if not _os.path.exists(patch_file):
            continue
        result = subprocess.run(
            ['disassembly/asar', patch_file, output],
            capture_output=True, text=True,
        )
        if result.stdout:
            print(result.stdout.strip())
        if result.stderr:
            print(result.stderr.strip())
        if result.returncode != 0:
            print(f'ERROR: {patch_file} failed')
            return
        print(f'  {patch_file} applied')

    print(f'=== scripted ROM ready: {output} ===')


def build_vwf(source: str = 'out/lm3_scripted.sfc',
              output: str = 'out/lm3_en.sfc',
              patch: str = 'asm/vwf_patch.asm',
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
          patch: str = 'asm/vwf_patch.asm',
          font_png: str = 'en_data/fonts/font_accented.png',
          en_folder: str = 'en_data/scripts',
          table_filename: str = 'en_data/eng.tbl',
          verbose: bool = False):
    """Full build: font → scripts → VWF patch."""
    print('=== FULL BUILD ===')
    build_scripted(source=source, output=scripted, font_png=font_png,
                   scripts_folder=en_folder, table_filename=table_filename, verbose=verbose)
    build_vwf(source=scripted, output=output, patch=patch)
    print('=== BUILD COMPLETE ===')


# ============================================================================
# Round-trip verification
# ============================================================================

# Extraction table definitions — derived from SCRIPT_TABLES (TOML-driven).
# Only the fields needed by verify_roundtrip are kept.
def _extract_entry_from_script(e):
    out = {'ptr_tbl_pos': e['ptr_tbl_pos'], 'tbl_len': e['tbl_len']}
    if e.get('event_script'):
        out['event_script'] = True
    return out


EXTRACT_TABLES = {e['name']: _extract_entry_from_script(e) for e in SCRIPT_TABLES}


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
        is_event_script = ext_info.get('event_script', False)
        orig_entries = []  # (data_bytes, data_start_pc)
        for idx in range(num_ptrs):
            data_start = all_starts[idx]

            # Use next unique pointer address as upper bound
            addr_idx = sorted_unique_addrs.index(data_start) if data_start in sorted_unique_addrs else -1
            max_addr = sorted_unique_addrs[addr_idx + 1] if addr_idx >= 0 and addr_idx + 1 < len(sorted_unique_addrs) else None

            if is_event_script and max_addr is not None:
                # Event script entries have embedded 0x00 in bytecodes;
                # find_entry_end would truncate them.  Use pointer distance.
                data_end = max_addr
            else:
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
        for entry_tuple in encoded_entries:
            enc_data, orig_addr = entry_tuple[0], entry_tuple[1]
            if orig_addr is not None and orig_addr not in addr_to_encoded:
                if enc_data != b'\x00':
                    addr_to_encoded[orig_addr] = enc_data

        for idx in range(max_entries):
            orig_data, orig_pc = orig_entries[idx]
            enc_data, orig_addr = encoded_entries[idx][0], encoded_entries[idx][1]

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


# ============================================================================
# EN structural validation
# ============================================================================

# Tables to validate (pointer-based only — derived from SCRIPT_TABLES).
# Bytecode tables (cutscene-bytecode, cutscene-bytecode-2) excluded since their
# JP content is raw bytecodes, not translatable text.  DISABLED -- All need validated
_VALIDATE_EXCLUDE = {}# 'cutscene-bytecode', 'cutscene-bytecode-2'}
VALIDATE_TABLES = [e['name'] for e in SCRIPT_TABLES if e['name'] not in _VALIDATE_EXCLUDE]


def _parse_entries(filepath):
    """Parse a text dump file into a list of (header, content) tuples."""
    import re
    with open(filepath, 'r', encoding='utf-16-le') as f:
        text = f.read()
    if text and text[0] == '\ufeff':
        text = text[1:]
    # Split on entry headers
    parts = re.split(r'(<<[^>]+>>)', text)
    entries = []
    for i in range(1, len(parts), 2):
        header = parts[i]
        content = parts[i + 1] if i + 1 < len(parts) else ''
        if content.startswith('\n'):
            content = content[1:]
        content = content.rstrip('\n\r\t ')
        # Extract entry index from header
        idx_match = re.search(r':(\d+)', header)
        idx = int(idx_match.group(1)) if idx_match else len(entries)
        entries.append((idx, header, content))
    return entries


def _extract_skeleton(content):
    """Extract ordered list of bracketed control codes from entry content."""
    import re
    return re.findall(r'\[[^\]]+\]', content)


def _has_translation(content):
    """Check if content has Latin characters (actual EN translation present)."""
    import re
    # Strip all bracketed codes first
    plain = re.sub(r'\[[^\]]+\]', '', content)
    # Check for Latin letters
    return bool(re.search(r'[A-Za-z]', plain))


def _is_raw_hex(content):
    """Check if content is mostly single-byte hex brackets (old broken extraction)."""
    import re
    codes = re.findall(r'\[[^\]]+\]', content)
    plain = re.sub(r'\[[^\]]+\]', '', content).strip()
    if not codes:
        return False
    hex_codes = sum(1 for c in codes if re.match(r'^\[[0-9A-Fa-f]{2}\]$', c))
    return hex_codes > len(codes) * 0.5 and not plain


def validate_en_scripts(jp_folder='jp_data/scripts', en_folder='en_data/scripts',
                        tables_filter=None, fix=False, report_file=None):
    """
    Compare EN script files against JP originals to find missing or malformed
    structural control codes.

    Returns dict: {table_name: [(idx, severity, message), ...]}
    """
    import os, re

    results = {}
    total_critical = 0
    total_warning = 0
    total_info = 0
    total_ok = 0
    fixes_applied = {}

    for name in VALIDATE_TABLES:
        if tables_filter and name not in tables_filter:
            continue

        jp_file = os.path.join(jp_folder, f'{name}.txt')
        en_file = os.path.join(en_folder, f'{name}.txt')
        if not os.path.exists(jp_file):
            print(f'  skip {name} (no JP file)')
            continue
        if not os.path.exists(en_file):
            print(f'  skip {name} (no EN file)')
            continue

        jp_entries = _parse_entries(jp_file)
        en_entries = _parse_entries(en_file)

        # Index by entry number
        jp_by_idx = {idx: (hdr, content) for idx, hdr, content in jp_entries}
        en_by_idx = {idx: (hdr, content) for idx, hdr, content in en_entries}

        issues = []
        fixed_entries = {}  # idx -> new content (for --fix mode)

        for idx in sorted(jp_by_idx.keys()):
            jp_hdr, jp_content = jp_by_idx[idx]
            if idx not in en_by_idx:
                issues.append((idx, 'CRITICAL', 'EN entry missing entirely'))
                total_critical += 1
                if fix:
                    fixed_entries[idx] = (jp_hdr, jp_content)
                continue

            en_hdr, en_content = en_by_idx[idx]

            jp_skel = _extract_skeleton(jp_content)
            en_skel = _extract_skeleton(en_content)

            if jp_skel == en_skel:
                total_ok += 1
                continue

            # Classify the mismatch
            is_raw = _is_raw_hex(en_content)
            has_trans = _has_translation(en_content)

            # Check for spurious [end] mid-entry (old 0x00-as-end bug)
            en_end_count = en_skel.count('[end]')
            jp_end_count = jp_skel.count('[end]')

            # Count FF codes
            jp_ff = [c for c in jp_skel if c.startswith('[FF') or c.startswith('[ff')]
            en_ff = [c for c in en_skel if c.startswith('[FF') or c.startswith('[ff')]

            if is_raw:
                severity = 'CRITICAL'
                msg = f'Raw hex (never translated) — {len(en_ff)} EN FF codes vs {len(jp_ff)} JP'
                if fix:
                    fixed_entries[idx] = (en_hdr, jp_content)
            elif en_end_count > jp_end_count and len(en_skel) < len(jp_skel):
                severity = 'CRITICAL'
                msg = (f'Truncated — extra [end] markers ({en_end_count} vs {jp_end_count} in JP), '
                       f'missing {len(jp_skel) - len(en_skel)} codes')
                if fix:
                    if has_trans:
                        # Preserve EN text, append JP tail after truncation point
                        # Find where EN diverges from JP
                        fixed_content = _repair_truncated(jp_content, en_content)
                        fixed_entries[idx] = (en_hdr, fixed_content)
                    else:
                        fixed_entries[idx] = (en_hdr, jp_content)
            elif len(en_ff) < len(jp_ff):
                severity = 'CRITICAL'
                msg = f'Missing FF codes — EN has {len(en_ff)} vs JP has {len(jp_ff)}'
                if fix:
                    if has_trans:
                        fixed_content = _repair_truncated(jp_content, en_content)
                        fixed_entries[idx] = (en_hdr, fixed_content)
                    else:
                        fixed_entries[idx] = (en_hdr, jp_content)
            elif en_ff != jp_ff:
                severity = 'WARNING'
                msg = f'FF code mismatch — EN: {en_ff[:3]}... vs JP: {jp_ff[:3]}...'
                if fix:
                    if has_trans and len(en_ff) == len(jp_ff):
                        # Same number of FF codes but different format — upgrade old 3-byte
                        # codes to correct lengths by positional replacement
                        fixed_content = _upgrade_ff_codes(en_content, en_ff, jp_ff)
                        fixed_entries[idx] = (en_hdr, fixed_content)
                    elif not has_trans:
                        fixed_entries[idx] = (en_hdr, jp_content)
            else:
                severity = 'INFO'
                msg = f'Non-FF skeleton differs (EN: {len(en_skel)} codes, JP: {len(jp_skel)})'

            issues.append((idx, severity, msg))
            if severity == 'CRITICAL':
                total_critical += 1
            elif severity == 'WARNING':
                total_warning += 1
            else:
                total_info += 1

        results[name] = issues

        # Print summary per table
        crits = sum(1 for _, s, _ in issues if s == 'CRITICAL')
        warns = sum(1 for _, s, _ in issues if s == 'WARNING')
        infos = sum(1 for _, s, _ in issues if s == 'INFO')
        ok = len(jp_by_idx) - len(issues)
        if not issues:
            print(f'  {name}: OK ({ok} entries)')
        else:
            print(f'  {name}: {crits} CRITICAL, {warns} WARNING, {infos} INFO '
                  f'({ok} OK / {len(jp_by_idx)} total)')
            for idx, sev, msg in issues[:5]:
                print(f'    [{sev}] #{idx}: {msg}')
            if len(issues) > 5:
                print(f'    ... ({len(issues) - 5} more)')

        # Apply fixes
        if fix and fixed_entries:
            _apply_fixes(en_file, en_entries, fixed_entries)
            fixes_applied[name] = len(fixed_entries)
            print(f'    → Fixed {len(fixed_entries)} entries in {en_file}')

    # Summary
    print(f'\n  Total: {total_ok} OK, {total_critical} CRITICAL, '
          f'{total_warning} WARNING, {total_info} INFO')

    if fix and fixes_applied:
        print(f'  Fixes applied: {sum(fixes_applied.values())} entries across '
              f'{len(fixes_applied)} files')

    # Write report file
    if report_file:
        with open(report_file, 'w') as f:
            f.write('EN Structural Validation Report\n')
            f.write('=' * 60 + '\n\n')
            for name, issues in results.items():
                if not issues:
                    f.write(f'{name}: OK\n')
                    continue
                f.write(f'{name}: {len(issues)} issues\n')
                for idx, sev, msg in issues:
                    f.write(f'  [{sev}] #{idx}: {msg}\n')
                f.write('\n')
        print(f'  Report written to {report_file}')

    return results


def _upgrade_ff_codes(en_content, en_ff, jp_ff):
    """
    Replace old-format FF codes in EN content with correct JP versions.
    en_ff and jp_ff must have the same length (1:1 positional correspondence).
    Also removes spurious [end] markers that follow upgraded codes
    (from parameter bytes that were decoded as 0x00 terminators).
    """
    result = en_content
    for old_code, new_code in zip(en_ff, jp_ff):
        if old_code != new_code:
            # Replace old code with new code, also clean up trailing garbage
            # Old pattern: [FFC000][end] or [FFC000]ん「 (parameter bytes as chars)
            # New pattern: [FFC000B222]
            result = result.replace(old_code, new_code, 1)

    # Remove spurious [end] that directly follows an upgraded FF code
    # (but only if JP doesn't end with [end] at that position)
    import re
    # Remove [end] that appears right after a ] from an FF code, unless it's the last code
    result = re.sub(r'(\[FF[0-9A-Fa-f]{6,}\])\[end\]', r'\1', result)
    return result


def _repair_truncated(jp_content, en_content):
    """
    Repair a truncated EN entry by finding where EN text diverges from JP
    structural codes and appending the missing JP tail.
    """
    import re

    # Tokenize both into (is_code, text) sequences
    jp_tokens = re.split(r'(\[[^\]]+\])', jp_content)
    en_tokens = re.split(r'(\[[^\]]+\])', en_content)

    # Remove spurious [end] in the middle of EN (from 0x00-as-end bug)
    cleaned_en = []
    for i, tok in enumerate(en_tokens):
        if tok == '[end]' and i < len(en_tokens) - 1:
            # Skip mid-entry [end] — it's a false terminator
            continue
        cleaned_en.append(tok)

    # Find the last matching structural code between cleaned EN and JP
    jp_codes = [(i, tok) for i, tok in enumerate(jp_tokens) if re.match(r'^\[', tok)]
    en_codes = [(i, tok) for i, tok in enumerate(cleaned_en) if re.match(r'^\[', tok)]

    # Find divergence point in JP tokens
    match_up_to = 0
    for j, (ei, etok) in enumerate(en_codes):
        if j < len(jp_codes) and jp_codes[j][1] == etok:
            match_up_to = j + 1
        else:
            break

    if match_up_to > 0 and match_up_to < len(jp_codes):
        # EN matches up to match_up_to codes, append rest from JP
        last_jp_match_idx = jp_codes[match_up_to - 1][0]
        # Take EN up to its last matching code + following text
        last_en_match_idx = en_codes[match_up_to - 1][0]
        en_prefix = ''.join(cleaned_en[:last_en_match_idx + 2])  # +2 to include text after code
        jp_suffix = ''.join(jp_tokens[last_jp_match_idx + 2:])   # rest of JP after match point

        return en_prefix + jp_suffix
    else:
        # Can't align — return JP content
        return jp_content


def _apply_fixes(en_file, en_entries, fixed_entries):
    """Rewrite the EN file with fixed entries replacing originals."""
    with open(en_file, 'r', encoding='utf-16-le') as f:
        text = f.read()
    if text and text[0] == '\ufeff':
        text = text[1:]

    import re
    parts = re.split(r'(<<[^>]+>>)', text)

    # Build index map: entry idx -> position in parts list
    entry_positions = {}
    for i in range(1, len(parts), 2):
        header = parts[i]
        idx_match = re.search(r':(\d+)', header)
        if idx_match:
            idx = int(idx_match.group(1))
            entry_positions[idx] = i

    for idx, (new_hdr, new_content) in fixed_entries.items():
        if idx in entry_positions:
            pos = entry_positions[idx]
            parts[pos + 1] = '\n' + new_content + '\n'
        else:
            # Entry missing — append at end
            parts.append(new_hdr)
            parts.append('\n' + new_content + '\n')

    result = '\ufeff' + ''.join(parts)
    with open(en_file, 'w', encoding='utf-16-le') as f:
        f.write(result)


def jptest_orig(rom_path: str, output_path: str, jp_folder: str = 'jp_data/scripts',
                table_filename: str = 'jp_data/jap.tbl', tables_filter: list = None):
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
            content = content.rstrip('\n\r\t ')

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
  validate-en  Check EN scripts have correct structural control codes vs JP
  hexify   Convert untranslated Japanese in en_data/scripts to [XX] hex placeholders
  jptest   Re-insert JP scripts into expanded ROM layout (round-trip insertion test)
  jptest-orig  Re-insert JP scripts at original ROM locations (data integrity test)
""",
    )
    parser.add_argument('command', choices=['font', 'font-preview', 'script', 'vwf', 'build', 'extract', 'verify', 'validate-en', 'hexify', 'jptest', 'jptest-orig'])
    parser.add_argument('--source',   default='lm3.sfc',          help='Source ROM (default: lm3.sfc)')
    parser.add_argument('--scripted', default='out/lm3_scripted.sfc',  help='Scripted ROM intermediate')
    parser.add_argument('--output',   default='out/lm3_en.sfc',        help='Final output ROM')
    parser.add_argument('--patch',    default='asm/vwf_patch.asm',     help='VWF patch file (default: vwf_patch.asm)')
    parser.add_argument('--font',     default='en_data/fonts/font_accented.png', help='Font PNG (default: font/font_accented.png)')
    parser.add_argument('--lang',     default='jp',                help='Language for extract (jp or en, default: jp)')
    parser.add_argument('--table',    default='en_data/eng.tbl',           help='Character table for insert (default: eng.tbl)')
    parser.add_argument('--en-folder',default='en_data/scripts',       help='English text folder (default: en_data/scripts)')
    parser.add_argument('--tables',   default=None,
                        help='Comma-separated list of tables to insert '
                             '(e.g. "script,dialog-2"). Default: all tables.')
    parser.add_argument('--jp-tables', default=None,
                        help='Comma-separated list of tables to insert from JP source '
                             'instead of EN (e.g. "battle-msg,battle-menu"). '
                             'Uses jp_data/scripts/ with jap.tbl.')
    parser.add_argument('--force', action='store_true',
                        help='Force re-encode all scripts (ignore bin cache).')
    parser.add_argument('--fix', action='store_true',
                        help='Auto-repair EN entries with broken structural codes.')
    parser.add_argument('--verbose', action='store_true',
                        help='Output extra stuff.')
    parser.add_argument('--report', default=None,
                        help='Write validation report to file.')

    args = parser.parse_args()
    import os
    tables_filter = [t.strip() for t in args.tables.split(',')] if args.tables else None
    jp_tables = set(t.strip() for t in args.jp_tables.split(',')) if args.jp_tables else set()

    if args.command == 'font':
        build_font(args.font, force=args.force)

    elif args.command == 'font-preview':
        stem = os.path.splitext(os.path.basename(args.font))[0]
        font_dir = os.path.dirname(args.font) or 'en_data/fonts'
        font_width_preview(
            font_bin_path=os.path.join(_bin_dir(font_dir), f'{stem}_1bpp.bin'),
            widths_bin_path=os.path.join(font_dir, f'{stem}_widths.bin'),
            table_path=args.table,
            output_path=os.path.join(font_dir, f'{stem}_preview.png'),
        )

    elif args.command == 'script':
        build_scripted(
            source=args.source,
            output=args.scripted,
            font_png=args.font,
            scripts_folder=args.en_folder,
            table_filename=args.table,
            tables_filter=tables_filter,
            jp_tables=jp_tables,
            force=args.force,
            verbose=args.verbose,
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
            verbose=args.verbose,
        )

    elif args.command == 'extract':
        tbl_file = 'jp_data/jap.tbl' if args.lang == 'jp' else 'en_data/eng.tbl'
        extract_script_bins(
            file_name=args.source,
            folder_prefix=args.lang,
            table_filename=tbl_file,
        )

    elif args.command == 'verify':
        """
        Build original Japanese data back into original areas to verify the encoded data matches original
        """

        folder = 'jp_data/scripts' if args.lang == 'jp' else args.en_folder
        tbl_file = 'jp_data/jap.tbl' if args.lang == 'jp' else args.table
        print(f'=== Round-trip verification: {args.source} vs {folder}/ ({tbl_file}) ===')
        ok = verify_roundtrip(
            rom_path=args.source,
            folder=folder,
            table_filename=tbl_file,
            tables_filter=tables_filter,
        )
        print(f'=== {"ALL PASS" if ok else "FAILURES DETECTED"} ===')

    elif args.command == 'validate-en':
        print(f'=== EN structural validation: jp_data/scripts/ vs {args.en_folder}/ ===')
        validate_en_scripts(
            jp_folder='jp_data/scripts',
            en_folder=args.en_folder,
            tables_filter=tables_filter,
            fix=args.fix,
            report_file=args.report,
        )

    elif args.command == 'hexify':
        print(f'=== Converting Japanese text to hex in {args.en_folder}/ ===')
        hexify_en_files(
            en_folder=args.en_folder,
            tables_filter=tables_filter,
        )

    elif args.command == 'jptest':
        """
        This is deprecated since we should no longer be relocating original code
        (FFC0XXXXXX control code is built in, so we can simply relocate any text without modifying pointers)
        """
        output = args.output.replace('_en.sfc', '_jptest.sfc') if '_en' in args.output else 'out/lm3_jptest.sfc'
        print(f'=== jptest: re-inserting JP scripts into expanded layout ===')
        print(f'  source: {args.source} → {output}')
        build_scripted(
            source=args.source,
            output=output,
            font_png=args.font,
            scripts_folder='jp_data/scripts',
            table_filename='jp_data/jap.tbl',
            tables_filter=tables_filter,
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
