# Input 1: overrides. Input 2: ROM baseline. Preserve all unrelated lines.
FNR == NR {
    if ($0 ~ /^[ \t]*[#!]/ || index($0, "=") == 0) next
    key = substr($0, 1, index($0, "=") - 1)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    if (!(key in overrides)) order[++count] = key
    overrides[key] = $0
    next
}
{
    key = substr($0, 1, index($0, "=") - 1)
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    if ($0 !~ /^[ \t]*[#!]/ && index($0, "=") > 0 && key in overrides) {
        if (!(key in emitted)) print overrides[key]
        emitted[key] = 1
    } else print
}
END {
    for (i = 1; i <= count; i++) {
        key = order[i]
        if (!(key in emitted)) print overrides[key]
    }
}
