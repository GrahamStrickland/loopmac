import os
from pathlib import Path


def gather_licensed_file_paths(cwd: str) -> set[Path]:
    licensed_files = set()
    for dirpath, _, files in os.walk(cwd):
        for file in files:
            path = Path(dirpath, file)
            if os.path.splitext(path)[1] in (".cpp", ".h", ".mm") or file == "CMakeLists.txt":
                licensed_files.add(path)

    return licensed_files


def strip_license_header(path: Path) -> list[str]: 
    strip = True
    lines = []

    with open(path, "r") as file: 
        for line in file.readlines():
            if strip: 
                if line.startswith("//") or line.startswith("#"):
                    continue
                else:
                    strip = False
            else:
                lines.append(line)

    return lines


def save_file(path: Path, lines: list[str]):
    with open(path, "w") as file:
        file.writelines(lines)


def main():
    licensed_file_paths = gather_licensed_file_paths(os.getcwd())
    for path in licensed_file_paths:
        lines = strip_license_header(path)
        save_file(path, lines)


if __name__ == "__main__":
    main()
