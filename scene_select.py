"""Scene select utility via Mesen2-Diz IPC.

Usage:
    python3 scene_select.py              # show current scenario
    python3 scene_select.py 98           # set scenario to 98 (Fusion Temple)
    python3 scene_select.py --list       # list known scenario names
"""
import sys
from mesen_ipc import connect, send_cmd

# Scenario names from scenario-desc.txt (indices 59-157 are the named ones)
SCENARIOS = {
    59: "Jewel Thieves",
    60: "Fire Jewel",
    61: "Soul of Fire",
    62: "Fire! Fire!",
    63: "Great Fire",
    64: "Fire Guardian",
    65: "Fire Treasure",
    66: "Flooded Path",
    67: "Draining Fortress",
    68: "Water Crossroads",
    69: "Water Jewel",
    70: "Water Guardian",
    71: "Water Treasure",
    72: "Scorching Desert",
    73: "Sandstorm",
    74: "Sand Ruins",
    75: "Desert Caves",
    76: "Wind Jewel",
    77: "Wind Guardian",
    78: "Wind Treasure",
    79: "Forest Maze",
    80: "Forest of Confusion",
    81: "Darkwood Trail",
    82: "Ancient Tree",
    83: "Earth Jewel",
    84: "Earth Guardian",
    85: "Earth Treasure",
    86: "Sealed Shrine",
    87: "Light and Shadow",
    88: "Shadow Tower",
    89: "Shadow Caves",
    90: "Light Jewel",
    91: "Light Guardian",
    92: "Light Treasure",
    93: "Thunderstorm Peak",
    94: "Lightning Shrine",
    95: "Thunder Jewel",
    96: "Phantom Temple",
    97: "Phantom Temple",
    98: "Fusion Temple",
    99: "Moved by Force",
    100: "Cave of Oblivion",
    101: "Water Fortress",
    102: "Liam Captured",
}

def main():
    sock = connect()

    if len(sys.argv) > 1 and sys.argv[1] == '--list':
        print("Known scenarios:")
        for idx, name in sorted(SCENARIOS.items()):
            print(f"  {idx:3d}: {name}")
        return

    # Read current scenario
    send_cmd(sock, 'pause')
    r = send_cmd(sock, 'readMemory', memoryType='SnesWorkRam', address=hex(0xEA82), length=2)
    current = r['data']['bytes'][0] | (r['data']['bytes'][1] << 8)
    name = SCENARIOS.get(current, "???")
    print(f"Current scenario: {current} ({name})")

    if len(sys.argv) > 1 and sys.argv[1] != '--list':
        new_scene = int(sys.argv[1])
        new_name = SCENARIOS.get(new_scene, "???")
        # Write new scenario number
        lo = new_scene & 0xFF
        hi = (new_scene >> 8) & 0xFF
        send_cmd(sock, 'writeMemory', memoryType='SnesWorkRam',
                 address=hex(0xEA82), values=[lo, hi])
        print(f"Set scenario to: {new_scene} ({new_name})")
        print("Note: You may need to trigger a scene transition in-game for it to take effect.")

    send_cmd(sock, 'resume')

if __name__ == '__main__':
    main()
