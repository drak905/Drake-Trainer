"""Legacy CSV-style (Excel quoting aware) parser that was used to extract the translation strings (kept so that the
translation index can be rebuilt exactly)."""


def parse(t):
    rows = []
    i, n = 0, len(t)
    while i < n:
        row = []
        while True:
            start = i
            if i < n and t[i] == '"':
                j = i + 1
                val = []
                while j < n:
                    if t[j] == '"':
                        if j + 1 < n and t[j + 1] == '"':
                            val.append('"')
                            j += 2
                            continue
                        break
                    val.append(t[j])
                    j += 1
                j += 1
                row.append([start, j, ''.join(val)])
                i = j
            else:
                j = i
                while j < n and t[j] not in '\t\r\n':
                    j += 1
                row.append([start, j, t[i:j]])
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
