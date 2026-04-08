

class Table:
    def __init__(self, table_file, warn_duplicates=False):
        """
        Load and interpret the table file, set up class variables
        :param table_file: the path to the table file
        :param warn_duplicates: if True, print warnings for characters with
                                multiple byte encodings (round-trip hazard)
        """
        enc, val_map, char_map, err_count, cnt = self._load_table(table_file)
        self.__val_map = val_map
        self.__chr_map = char_map
        self.__errors = err_count
        self.__parsed_lines = cnt
        self.__file_name = table_file
        self.__encoding = enc
        if warn_duplicates:
            self._check_duplicates()

    def _load_table(self, table_file, enc=None):
        """
        Load a given table file. Supports encoding type overrides.
        :param table_file: the path to the table file
        :param enc: Optional Encoding type
        :return: encoding, value_map, character_map, error_count, line_count
        """
        enc = enc if enc is not None else self.detect_encoding(table_file)
        val_map = {}
        char_map = {}
        err_count = 0
        cnt = 1
        with open(table_file, encoding=enc) as to:
            line = to.readline()
            if line and line[0] == '\ufeff':
                line = line[1:]  # strip BOM
            while line:
                try:
                    # split the line using the '=' sign, ignore all else including
                    line_data = line.split('=')
                    if len(line_data) == 2:
                        # value first, character second
                        val = line_data[0]
                        ch = line_data[1]

                        # character will have new line codes removed unless the backslash-escape '\\' is used
                        ch = ch.replace('\n', '').replace('\r', '').replace('\\n', '\n')

                        # supports variable filling for table files
                        if self.exists(val, '**'):
                            # fill the table with equivalent values for a byte range
                            for d in range(0, 256):
                                prep_ch = ch.replace('**', self.hex(d))
                                prep_val = val.replace('**', self.hex(d))
                                if self.exists(val, '%%'):
                                    for e in range(0, 256):
                                        ch_val = prep_ch.replace('%%', self.hex(e))
                                        val_val = prep_val.replace('%%', self.hex(e))

                                        self._set_maps(val_val, ch_val, val_map, char_map)
                                else:
                                    self._set_maps(prep_val, prep_ch, val_map, char_map)
                        else:
                            self._set_maps(val, ch, val_map, char_map)
                except Exception as ex:
                    print(f"ERROR: {repr(ex)}")
                    err_count += 1
                # read next line and increment line count
                line = to.readline()
                cnt += 1
        return enc, val_map, char_map, err_count, cnt

    @staticmethod
    def _set_maps(in_val, in_ch, val_map, char_map):
        """
        Add the value and character to the map objects
        :param in_val: value
        :param in_ch: character
        :param val_map: value map
        :param char_map: character map
        """
        dec_val = int(in_val, 16)

        if dec_val not in val_map.keys():
            val_map[dec_val] = in_ch
        if in_ch not in char_map.keys():
            char_map[in_ch] = dec_val

    def _check_duplicates(self):
        """Warn about characters with multiple byte encodings."""
        from collections import defaultdict
        char_to_vals = defaultdict(list)
        for val, ch in self.__val_map.items():
            char_to_vals[ch].append(val)
        dupes = {ch: sorted(vals) for ch, vals in char_to_vals.items()
                 if len(vals) > 1}
        if dupes:
            print(f'WARNING: {self.__file_name} has {len(dupes)} characters '
                  f'with duplicate encodings (round-trip mismatch risk):')
            for ch, vals in sorted(dupes.items(), key=lambda x: x[1][0]):
                hex_vals = ', '.join(f'${v:04X}' for v in vals)
                used = self.__chr_map.get(ch)
                print(f'  {repr(ch):8s}: {hex_vals}  (encoder uses ${used:04X})')

    @property
    def encoding(self):
        return self.__encoding

    @staticmethod
    def exists(str_val: str, search: str):
        """
        Search a given string for another string
        :param str_val: searchable string
        :param search: Value to search for
        :return: True/False
        """
        try:
            str_val.index(search)
            return True
        except ValueError:
            return False

    def get_value(self, word: str, infer_value=True):
        """
        Return value for a string
        :param word: character/word string
        :param infer_value: if the word comes in [00] format
        :return: The value or None
        """
        if type(word) is not str:
            raise ValueError("Value must be a string!")
        if word in self.__chr_map.keys():
            return self.__chr_map[word]
        if infer_value and '[' in word and ']' in word:
            try:
                word = word.replace('[', '').replace(']', '')
                return int(word, 16)
            except:
                print("Warning: Value could not be determined.")
        return None

    def get_chars(self, value: int, return_hex_repr=True):
        if value in self.__val_map.keys():
            return self.__val_map[value]
        return f'[{self.hex(value)}]' if return_hex_repr else None

    @staticmethod
    def hex(value):
        """
        Return a hex representation
        Only currently supports up to 64 bit encoded characters
        :param value: the input value
        :return: String representation of the given value
        """
        if value < 0x100:
            pad = 2
        elif value < 0x10000:
            pad = 4
        elif value < 0x1000000:
            pad = 6
        elif value < 0x100000000:
            pad = 8
        else:
            raise ValueError("Error: Table Value is not supported!")
        return f'{value:0{pad}X}'

    @staticmethod
    def byte_size(value: int):
        """
        Get the number of bytes representing the value
        :param value: integer value
        :return: number of bytes
        """
        from math import log
        if value == 0:
            return 1
        return int(log(value, 256)) + 1

    @staticmethod
    def __get_byte_multiplier(value):
        if value == 0:
            return 1
        final = '1'
        for i in range(0, value):
            final += '00'
        return int(final, 16)

    @staticmethod
    def bytes_to_val(byte_list: list, reverse=False):
        final_val = 0
        if reverse:
            byte_list.reverse()
        for b in range(0, len(byte_list)):
            final_val |= (byte_list[b] << (b * 8))  # self.__get_byte_multiplier(b)
        return final_val

    def interpret_binary(self, input_filename, max_bytes=3):
        with open(input_filename, "rb") as data_file:
            bin_data = list(data_file.read())
        return self.interpret_binary_data(bin_data, max_bytes)

    def interpret_binary_data(self, bin_data, max_bytes=3, trim_bytes=None):
        final_string = ''
        i = 0

        # can trim certain expected bytes from the end of each output string
        if trim_bytes is not None:
            if type(trim_bytes) is int:
                trim_bytes = [trim_bytes]
            if trim_bytes is not None and len(trim_bytes) > 0:
                exclude_count = 0
                for i in range(len(bin_data), 0):
                    if bin_data[i] in trim_bytes:
                        exclude_count += 1
                    else:
                        break
                if exclude_count > 0:
                    bin_data = bin_data[:len(bin_data)-exclude_count]

        while i < len(bin_data):
            len_check = max_bytes
            char = None
            found_char = False
            while len_check > 0:
                end_check = i + len_check
                if end_check > len(bin_data):
                    len_check -= 1
                    continue
                val = self.bytes_to_val(bin_data[i: end_check], True)
                char = self.get_chars(val, False)
                if char:
                    found_char = True
                    i += len_check
                    break
                else:
                    len_check -= 1

            if not found_char:
                char = self.get_chars(bin_data[i], True)
                i += 1
            if char is None:
                print(f"ERROR - Unable to resolve byte ({hex(bin_data[i - 1])})???")
            else:
                final_string += char
        return final_string

    def has_char(self, bin_data):
        """
        Check for a valid character using all given bytes
        :param bin_data: the list of bytes
        :return: if there is a valid character using these bytes
        """
        # get the value by OR'ing and shifting the bytes together
        val = self.bytes_to_val(bin_data)

        # check for valid value...
        if len(bin_data) > 1 and val in bin_data:
            # in the case of [00, 00] or [00, 90] or etc.
            # the total value cannot equal a single byte value
            return None

        # using the value, check for a defined character
        char = self.get_chars(val, False)

        return char

    def check_for_lone_byte(self, bin_data, index, value=0x0):
        """
        Used to check for the end of a text block
        :param bin_data: a list of values
        :param index: current list index
        :param value: check for this value
        :return: if the value is found,
        check to see if it is part of a larger value
        """
        start1 = index - 3
        start2 = index - 2
        end0 = index + 1

        if bin_data[index] == value:
            char1 = self.has_char(bin_data[start1: end0])
            char2 = self.has_char(bin_data[start2: end0])

            if char1 is not None or char2 is not None:
                return 0, char1 or char2

            return -1, None

        return 0, None

    def find_entry_end(self, bin_data, start, max_bytes=3, max_addr=None):
        """
        Find the end of a text entry by decoding left-to-right with the table.
        When a byte starts a multi-byte entry (e.g. FF -> 3 bytes), the entry
        size is determined by the table and all bytes are consumed. A $00 is
        only a terminator when it appears as a standalone single-byte value.
        :param bin_data: full ROM data (list of ints)
        :param start: index to begin scanning
        :param max_bytes: max multi-byte entry size
        :param max_addr: optional upper bound address (next entry's start);
                         scanning stops if position reaches or exceeds this
        :return: index one past the terminating $00 (i.e. data = bin_data[start:result])
        """
        i = start
        while i < len(bin_data):
            if max_addr is not None and i >= max_addr:
                return i
            # Try longest match first (left-to-right decode)
            matched = False
            for size in range(max_bytes, 1, -1):
                if i + size > len(bin_data):
                    continue
                window = list(bin_data[i:i + size])
                val = self.bytes_to_val(window, True)
                # Only match if the value's byte size equals the window size
                # (prevents e.g. [00,92] → val $92 consuming 2 bytes for a 1-byte value)
                if self.byte_size(val) != size:
                    continue
                if self.get_chars(val, False) is not None:
                    i += size
                    matched = True
                    break
            if not matched:
                # Single byte: if it's the terminator value, stop
                if bin_data[i] == 0x00:
                    return i + 1
                i += 1

        return i

    @staticmethod
    def detect_encoding(file_path, lines=80):
        """
        Given a file, use the first X number of lines to detect the encoding
        :param file_path: path to text file
        :param lines: defaults to 80
        :return: the assumed file encoding using chardet
        """
        import chardet
        with open(file_path, 'rb') as f:
            raw_data = b''.join([f.readline() for _ in range(lines)])
        return chardet.detect(raw_data)['encoding']

    @staticmethod
    def _is_binary_block(decoded_str, raw_data=None):
        """Check if decoded output looks like binary data (mostly control codes).
        Two checks: (1) decoded output is mostly bracketed control codes,
        (2) raw data has interior $00 bytes (null bytes before the terminator)."""
        # Check 1: decoded output ratio
        in_bracket = 0
        out_bracket = 0
        inside = False
        for ch in decoded_str:
            if ch == '[':
                inside = True
            elif ch == ']':
                inside = False
                in_bracket += 1
            elif inside:
                pass
            else:
                out_bracket += 1
        total = in_bracket + out_bracket
        if total > 0 and in_bracket > out_bracket:
            return True
        # Check 2: interior $00 bytes in raw data
        if raw_data and len(raw_data) > 1:
            interior = raw_data[:-1] if raw_data[-1] == 0 else raw_data
            zero_count = sum(1 for b in interior if b == 0)
            if zero_count > 0 and zero_count >= len(interior) * 0.15:
                return True
        return False

    @staticmethod
    def hex_dump(bin_data):
        """Output all bytes as hex escapes: [04][00][B3]..."""
        return ''.join(f'[{b:02X}]' for b in bin_data)

    def dump_script(self, filename: str, dict_data: list, deduplicate=True):
        """
        Dump the script using a table from a list of mapped data (id, addr, data)
        :param filename: the output file path
        :param dict_data: a list of mapped data (id (formatted), addr (must be int), data (list of binary data))
        :param deduplicate: only supported if the addr key is given. will only display pointer map for data in the dump
        """
        line1 = True
        nl = "\n"
        with open(filename, 'w', encoding='utf-16') as of:
            dumped_addrs = []
            for data in dict_data:
                of.write(f"{'' if line1 else nl}<<{data.get('id')}>>{nl}")
                addr = data.get('addr', None)
                should_write = True
                if deduplicate and addr is not None:
                    if addr in dumped_addrs:
                        should_write = False
                    else:
                        dumped_addrs.append(addr)
                if should_write:
                    raw = data['data']
                    decoded = self.interpret_binary_data(raw)
                    if self._is_binary_block(decoded, raw):
                        of.write(self.hex_dump(raw))
                    else:
                        of.write(decoded)
                line1 = False

    @staticmethod
    def export_csv(filename, dict_data: list):
        import csv
        csv_columns = dict_data[0].keys()
        csv_file = f"./{filename}.csv"
        try:
            with open(csv_file, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=csv_columns)
                writer.writeheader()
                for data in dict_data:
                    writer.writerow(data)
        except IOError:
            print("I/O error")