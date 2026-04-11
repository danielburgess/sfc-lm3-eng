"""Mesen2-Diz IPC helper for debugger communication."""
import socket, json, sys

PIPE_PATH = '/tmp/CoreFxPipe_Mesen2Diz_DebuggerIpc'

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

if __name__ == '__main__':
    sock = connect()
    print(json.dumps(send_cmd(sock, 'getStatus'), indent=2))
