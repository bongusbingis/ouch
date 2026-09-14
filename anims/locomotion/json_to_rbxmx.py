"""Convert sampled locomotion clips (JSON written by clips.export_all inside Blender) into
KeyframeSequence .rbxmx files that load through a rig's AnimSaves folder in the Animation
Editor, exactly like anims/hammerswing.py and anims/emotes.py.

usage: python json_to_rbxmx.py <json dir> [<out dir>]
Each JSON holds 30 Hz samples of every R15 Motor6D transform (position + quaternion) in
Roblox joint space; every sample becomes a Keyframe with Linear poses, so playback matches
the Blender curves without depending on the engine's easing.
"""
import json, os, sys

TREE = {
    "HumanoidRootPart": ["LowerTorso"],
    "LowerTorso": ["UpperTorso", "LeftUpperLeg", "RightUpperLeg"],
    "UpperTorso": ["Head", "LeftUpperArm", "RightUpperArm"],
    "LeftUpperArm": ["LeftLowerArm"], "LeftLowerArm": ["LeftHand"], "LeftHand": [],
    "RightUpperArm": ["RightLowerArm"], "RightLowerArm": ["RightHand"], "RightHand": [],
    "LeftUpperLeg": ["LeftLowerLeg"], "LeftLowerLeg": ["LeftFoot"], "LeftFoot": [],
    "RightUpperLeg": ["RightLowerLeg"], "RightLowerLeg": ["RightFoot"], "RightFoot": [],
    "Head": [],
}
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4, "Action4": 5, "Core": 1000}
AUTHORED_HIP_HEIGHT = 1.579  # the blob rig the clips were tuned on

_ref = [0]


def next_ref():
    _ref[0] += 1
    return f"RBX{_ref[0]}"


def quat_to_rows(x, y, z, w):
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]


def cframe_xml(vals, indent):
    pad = " " * indent
    if vals:
        px, py, pz = vals[0], vals[1], vals[2]
        m = quat_to_rows(vals[3], vals[4], vals[5], vals[6])
    else:
        px = py = pz = 0.0
        m = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    out = [f'{pad}<CoordinateFrame name="CFrame">']
    for tag, v in (("X", px), ("Y", py), ("Z", pz)):
        out.append(f"{pad}  <{tag}>{v:.6f}</{tag}>")
    for i in range(3):
        for j in range(3):
            out.append(f"{pad}  <R{i}{j}>{m[i][j]:.6f}</R{i}{j}>")
    out.append(f"{pad}</CoordinateFrame>")
    return "\n".join(out)


def pose_xml(joint, row, indent):
    pad = " " * indent
    out = [f'{pad}<Item class="Pose" referent="{next_ref()}">',
           f"{pad}  <Properties>",
           f'{pad}    <string name="Name">{joint}</string>',
           cframe_xml(row.get(joint), indent + 4),
           f'{pad}    <token name="EasingDirection">0</token>',
           f'{pad}    <token name="EasingStyle">0</token>',
           f'{pad}    <float name="Weight">1</float>',
           f"{pad}  </Properties>"]
    for child in TREE[joint]:
        out.append(pose_xml(child, row, indent + 2))
    out.append(f"{pad}</Item>")
    return "\n".join(out)


def build(data, name):
    _ref[0] = 0
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'  <Item class="KeyframeSequence" referent="{next_ref()}">',
           "    <Properties>",
           f'      <string name="Name">{name}</string>',
           f'      <float name="AuthoredHipHeight">{AUTHORED_HIP_HEIGHT}</float>',
           f'      <bool name="Loop">{"true" if data["loop"] else "false"}</bool>',
           f'      <token name="Priority">{PRIORITY[data.get("priority", "Core")]}</token>',
           "    </Properties>"]
    for t, row in data["frames"]:
        out.append(f'    <Item class="Keyframe" referent="{next_ref()}">')
        out.append("      <Properties>")
        out.append('        <string name="Name">Keyframe</string>')
        out.append(f'        <float name="Time">{t:.4f}</float>')
        out.append("      </Properties>")
        out.append(pose_xml("HumanoidRootPart", row, 6))
        out.append("    </Item>")
    out += ["  </Item>", "</roblox>", ""]
    return "\n".join(out)


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".json"):
            continue
        with open(os.path.join(src, fn), encoding="utf-8") as fh:
            data = json.load(fh)
        name = "Loco" + data["name"]
        path = os.path.join(dst, name + ".rbxmx")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(build(data, name))
        print(f"{name}: {len(data['frames'])} keyframes, {data['frames'][-1][0]:.2f}s, loop={data['loop']} -> {os.path.basename(path)}")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else here)
