"""Mesen2-Diz IPC helper for debugger communication."""
import socket, json, sys

def _find_pipe():
    """Auto-detect Mesen IPC pipe in /tmp/."""
    import glob
    candidates = glob.glob('/tmp/CoreFxPipe_Mesen2Diz_*')
    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        # Prefer one matching lm3
        for c in candidates:
            if 'lm3' in c:
                return c
        return candidates[0]
    return '/tmp/CoreFxPipe_Mesen2Diz_DebuggerIpc'  # fallback

PIPE_PATH = _find_pipe()

def connect():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(PIPE_PATH)
    sock.settimeout(10)
    return sock

def send_cmd(sock, cmd, **params):
    msg = json.dumps({'command': cmd, **params}) + '\n'
    sock.sendall(msg.encode())
    data = b''
    while b'\n' not in data:
        data += sock.recv(65536)
    return json.loads(data.decode('utf-8-sig').strip())

def read_mem(sock, mem_type, addr, length):
    """Read memory, return bytes list."""
    r = send_cmd(sock, 'readMemory', memoryType=mem_type, address=hex(addr), length=length)
    if r['success']:
        return r['data']['bytes']
    print(f"Read failed: {r}", file=sys.stderr)
    return None

def read_rom(sock, pc_offset, length):
    """Read from PRG ROM at PC offset."""
    return read_mem(sock, 'SnesPrgRom', pc_offset, length)

def read_wram(sock, offset, length):
    """Read WRAM at offset."""
    return read_mem(sock, 'SnesWorkRam', offset, length)

def write_mem(sock, mem_type, addr, data):
    """Write bytes to memory. data may be a list[int] or bytes."""
    hex_str = ''.join(f'{b:02X}' for b in data)
    r = send_cmd(sock, 'writeMemory', memoryType=mem_type, address=hex(addr), hex=hex_str)
    if not r.get('success'):
        print(f"Write failed: {r}", file=sys.stderr)
    return r

def step_frames(sock, count):
    """Step the SNES CPU by `count` PPU frames."""
    return send_cmd(sock, 'step', cpuType='Snes', count=count, stepType='PpuFrame')

def set_controller(sock, port=0, **buttons):
    """Override controller input. Buttons: a, b, x, y, l, r, up, down, left, right, start, select."""
    return send_cmd(sock, 'setControllerInput', port=port, buttons=buttons)

def clear_controller(sock, port=0):
    return send_cmd(sock, 'clearControllerInput', port=port)

if __name__ == '__main__':
    sock = connect()
    print(json.dumps(send_cmd(sock, 'getStatus'), indent=2))
