n () {
    if [ -n $NNNLVL ] && [ "${NNNLVL:-0}" -ge 1 ]; then
        echo "nnn is already running"
        return
    fi

    LESS=${LESS//--quit-if-one-screen/}
    LESS=${LESS//-F/}

    NNN_TMPFILE="@configHome@/.lastd"

    @nnn@ "$@"

    if [ -f "$NNN_TMPFILE" ]; then
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE" > /dev/null
    fi
}
