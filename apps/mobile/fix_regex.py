path = r'd:\se hack\lumina\apps\mobile\lib\features\rag\rag_provider.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'buffer.write' in line and 'm.group()' in line:
        lines[i] = line.replace('m.group()', 'm.group(0)')
        print(f'Fixed line {i+1}')
        break

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Done')
