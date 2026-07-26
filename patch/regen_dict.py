#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Regenerate the DICT block inside zh-CN-inject.js from zh-CN.json.

Run this whenever you edit zh-CN.json (e.g. after a new OpenWorker release
adds new UI strings). It keeps the dictionary source-of-truth in sync with
the injected script. Safe to run repeatedly.
"""
import json
import os
import re

BASE = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(BASE, "zh-CN.json")
JS_PATH = os.path.join(BASE, "zh-CN-inject.js")


def build_dict_block(data: dict) -> str:
    lines = ["  var DICT = {"]
    items = list(data.items())
    for i, (k, v) in enumerate(items):
        ek = k.replace("\\", "\\\\").replace('"', '\\"')
        ev = v.replace("\\", "\\\\").replace('"', '\\"')
        comma = "," if i < len(items) - 1 else ""
        lines.append(f'    "{ek}": "{ev}"{comma}')
    lines.append("  };")
    return "\n".join(lines)


def main() -> None:
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    with open(JS_PATH, "r", encoding="utf-8") as f:
        js = f.read()

    start = js.find("var DICT = {")
    if start == -1:
        print("[ERROR] 'var DICT = {' not found in zh-CN-inject.js")
        raise SystemExit(1)

    m = re.search(r"\n  \};", js[start:])
    if not m:
        print("[ERROR] DICT closing '};' not found in zh-CN-inject.js")
        raise SystemExit(1)
    end_pos = start + m.end()

    dict_block = build_dict_block(data)
    new_js = js[:start] + dict_block + js[end_pos:]

    with open(JS_PATH, "w", encoding="utf-8") as f:
        f.write(new_js)

    print(f"[OK] Regenerated DICT from zh-CN.json ({len(data)} entries)")


if __name__ == "__main__":
    main()
