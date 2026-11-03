"""Span-preserving reader/editor for the engine's UTF-16 TSV language files.

Fields are tab separated, rows end with CRLF (or LF); a field may be wrapped in double quotes
(Excel style, "" = literal quote) and then may contain tabs / line breaks.
`parse(text)` returns rows -> list of fields (start, end, value) so one column can be replaced
without touching any other byte of the file.
"""


def decode(data):
    if data[:2] == b'\xff\xfe':
        return data[2:].decode('utf-16-le'), True
    return data.decode('utf-16-le'), False


def encode(text, bom):
    return (b'\xff\xfe' if bom else b'') + text.encode('utf-16-le')


def parse(t):
    """Engine-compatible parse (Language::AddLanguageFile): fields split at TAB, rows at CR/LF; quotes never group
    anything - only one leading and one trailing double quote of a field are dropped.
    Returns rows -> list of [start, end, value]."""
    rows = []
    i, n = 0, len(t)
    while i < n:
        row = []
        while True:
            start = i
            j = i
            while j < n and t[j] not in '\t\r\n':
                j += 1
            raw = t[i:j]
            val = raw
            if raw[:1] == '"':
                val = raw[1:]
                if raw[-1:] == '"' and len(raw) > 1:
                    val = val[:-1]
            row.append([start, j, val])
            i = j
            if i < n and t[i] == '\t':
                i += 1
                continue
            break
        if i < n and t[i] == '\r':
            i += 1
        if i < n and t[i] == '\n':
            i += 1
        rows.append(row)
    return rows


def quote(v):
    """Inverse of the engine's quote stripping."""
    if v[:1] == '"' or v[-1:] == '"':
        return '"' + v + '"'
    return v


def set_column(t, rows, col, values, header_name=None):
    """values: dict row_index -> new value (str). Rows with <=col fields are padded with tabs.
    Returns new text. Row 0 (header) gets header_name if given."""
    out = []
    pos = 0
    for ri, row in enumerate(rows):
        newval = values.get(ri)
        if ri == 0 and header_name is not None:
            newval = header_name
        if newval is None:
            continue
        if len(row) > col:
            s, e, _ = row[col]
            out.append((s, e, quote(newval)))
        else:
            # append at end of row (before line terminator), padding tabs
            e = row[-1][1]
            pad = '\t' * (col - len(row) + 1)
            out.append((e, e, pad + quote(newval)))
    res = []
    last = 0
    for s, e, rep in sorted(out):
        res.append(t[last:s])
        res.append(rep)
        last = e
    res.append(t[last:])
    return ''.join(res)
