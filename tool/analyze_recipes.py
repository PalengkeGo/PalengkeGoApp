import re

# Analyze breakfast.txt
with open(r'c:\Users\ADMIN\Documents\PalengkeGo\PalengkeGoAPP-main\tool\extracted\breakfast.txt', 'r', encoding='utf-8') as f:
    b = f.read()
lines = b.splitlines()

# Find recipe markers (lines starting with N. )
ids = []
for l in lines:
    m = re.match(r'^(\d+)\.', l)
    if m:
        ids.append(int(m.group(1)))

missing = [i for i in range(1, 51) if i not in ids]
print('breakfast total markers:', len(ids))
print('breakfast missing ids:', missing)
print('ids found:', ids)

# Analyze ulam.txt
with open(r'c:\Users\ADMIN\Documents\PalengkeGo\PalengkeGoAPP-main\tool\extracted\ulam.txt', 'r', encoding='utf-8') as f:
    u = f.read()
lines_u = u.splitlines()

ids_u = []
for l in lines_u:
    m = re.match(r'^(\d+)\.', l)
    if m:
        ids_u.append(int(m.group(1)))

missing_u = [i for i in range(1, 72) if i not in ids_u]
print('\nulam total markers:', len(ids_u))
print('ulam missing ids:', missing_u)
print('ids found:', ids_u)