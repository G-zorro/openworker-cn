"""Inject zh-CN translation JS into lib.rs using raw string (no escaping needed)."""
import re

lib_path = r'E:\openworker-cn\openworker\surfaces\gui\src-tauri\src\lib.rs'
js_path = r'E:\openworker-cn\zh-CN-inject.js'

with open(js_path, 'r', encoding='utf-8') as f:
    js_content = f.read()

with open(lib_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Verify no "# sequence in JS (would break raw string r#"..."#)
if '"#' in js_content:
    print('[ERROR] JS contains "# which would break raw string delimiter')
    exit(1)

start_marker = 'let inject = format!('
start_idx = content.find(start_marker)
if start_idx == -1:
    print('[ERROR] Could not find let inject = format!(')
    exit(1)

search_from = content[start_idx:]
end_pattern = '\n    );'
end_rel_idx = search_from.find(end_pattern)
if end_rel_idx == -1:
    end_pattern2 = '\n\t);'
    end_rel_idx = search_from.find(end_pattern2)
if end_rel_idx == -1:
    print('[ERROR] Could not find end of format! statement')
    exit(1)

end_idx = start_idx + end_rel_idx + len(end_pattern)
original = content[start_idx:end_idx]

# Build new: original format!(...) without trailing ;, then + raw string
new_stmt = original.rstrip()
if new_stmt.endswith(';'):
    new_stmt = new_stmt[:-1]

raw_string = "\n// === ZH-CN INJECTION START ===\n" + js_content + "\n// === ZH-CN INJECTION END ===\n"

# Use r#..."# raw string - JS has no "# sequence (verified above)
new_stmt += '\n        + r#"'
new_stmt += raw_string
new_stmt += '"#;'

content = content[:start_idx] + new_stmt + content[end_idx:]

with open(lib_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'[OK] Injected via raw string (no escaping needed)')
print(f'     JS size: {len(js_content)} bytes')
print(f'     Total inject size: ~{len(new_stmt)} bytes')
