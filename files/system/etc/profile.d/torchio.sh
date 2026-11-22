# Torchio host-local test install (undo by removing this file).
# Append, not prepend: keep the system CUPS CLI tools as the default; they
# reach torchiod through CUPS_SERVER. Call /opt/torchio/bin/{lp,lpr,lpstat}
# explicitly if you want to try torchio's limited built-in shims.
if [ -d /opt/torchio/bin ]; then
    case ":$PATH:" in
        *:/opt/torchio/bin:*) ;;
        *) PATH="$PATH:/opt/torchio/bin" ;;
    esac
    export PATH
fi
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -z "${CUPS_SERVER:-}" ]; then
    export CUPS_SERVER="$XDG_RUNTIME_DIR/torchio-proxy/cups.sock"
fi
