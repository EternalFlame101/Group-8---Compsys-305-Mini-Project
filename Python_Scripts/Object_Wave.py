import random

OFF   = "00"
GIFT  = "01"
SHORT = "10"
TALL  = "11"

types = [OFF, GIFT, SHORT, TALL]

# Generate all 4^3 = 64 combinations
all_combos = []
for l2 in types:
    for l1 in types:
        for l0 in types:
            pattern = l2 + l1 + l0
            all_combos.append(pattern)

# 64 unique patterns — assign weights
def get_weight(l2, l1, l0):
    lanes = [l2, l1, l0]
    active = [l for l in lanes if l != OFF]
    num_active = len(active)
    num_gifts  = active.count(GIFT)
    num_tall   = active.count(TALL)

    if num_active == 0:
        return 8    # gaps — reasonably common

    if num_active == 1:
        if num_gifts == 1: return 4     # single gift — uncommon
        if num_tall  == 1: return 7     # single tall
        return 10                       # single short — most common

    if num_active == 2:
        if num_gifts >= 1: return 2     # any double with a gift — rare
        if num_tall  == 2: return 3     # double tall — hard
        if num_tall  == 1: return 5     # one tall one short
        return 7                        # double short

    if num_active == 3:
        if num_gifts >= 1: return 1     # triple with gift — very rare
        if num_tall  == 3: return 1     # triple tall — very rare
        if num_tall  >= 1: return 2     # mixed triple
        return 3                        # triple short

weighted_pool = []
for l2 in types:
    for l1 in types:
        for l0 in types:
            pattern = l2 + l1 + l0
            weight  = get_weight(l2, l1, l0)
            weighted_pool.append((pattern, weight))

# Print summary
print("All 64 combinations:")
print(f"{'Pattern':<10} {'L2':<6} {'L1':<6} {'L0':<6} {'Weight'}")
print("-" * 40)
label = {OFF: "off", GIFT: "gift", SHORT: "short", TALL: "tall"}
for pattern, weight in weighted_pool:
    l2, l1, l0 = pattern[0:2], pattern[2:4], pattern[4:6]
    print(f"{pattern:<10} {label[l2]:<6} {label[l1]:<6} {label[l0]:<6} {weight}")

total_weight = sum(w for _, w in weighted_pool)
print(f"\nTotal weight: {total_weight}")
print(f"Unique patterns: {len(weighted_pool)}")

# Build weighted pool of 256 entries
pool = []
for pattern, weight in weighted_pool:
    pool.extend([pattern] * weight)

# Scale to exactly 256
random.shuffle(pool)
while len(pool) < 256:
    # top up by sampling proportionally
    pattern, _ = random.choices(weighted_pool, weights=[w for _, w in weighted_pool])[0]
    pool.append(pattern)
pool = pool[:256]

with open("Images_To_mif/mif/spawn_patterns.mif", "w") as f:
    f.write("-- spawn_patterns.mif\n")
    f.write("-- 6-bit pattern: [5:4]=lane2  [3:2]=lane1  [1:0]=lane0\n")
    f.write("-- 00=nothing  01=gift  10=short  11=tall\n")
    f.write("--\n")

    # Embed the full legend as comments
    f.write("-- All 64 combinations and their weights:\n")
    for pattern, weight in weighted_pool:
        l2, l1, l0 = pattern[0:2], pattern[2:4], pattern[4:6]
        f.write(f"--   {pattern}  l2={label[l2]:<5} l1={label[l1]:<5} l0={label[l0]:<5} weight={weight}\n")
    f.write("--\n\n")

    f.write("DEPTH = 256;\n")
    f.write("WIDTH = 6;\n\n")
    f.write("ADDRESS_RADIX = HEX;\n")
    f.write("DATA_RADIX = BIN;\n\n")
    f.write("CONTENT BEGIN\n")
    for i, p in enumerate(pool):
        l2, l1, l0 = p[0:2], p[2:4], p[4:6]
        f.write(f"    {i:02X} : {p};   -- l2={label[l2]:<5} l1={label[l1]:<5} l0={label[l0]}\n")
    f.write("END;\n")

print("\nspawn_patterns.mif written")

# Sanity check — frequency analysis
from collections import Counter
counts = Counter(pool)
print("\nFrequency in generated MIF:")
print(f"{'Pattern':<10} {'L2':<6} {'L1':<6} {'L0':<6} {'Count':<6} {'%'}")
print("-" * 50)
for pattern, weight in sorted(weighted_pool, key=lambda x: -x[1]):
    l2, l1, l0 = pattern[0:2], pattern[2:4], pattern[4:6]
    count = counts.get(pattern, 0)
    print(f"{pattern:<10} {label[l2]:<6} {label[l1]:<6} {label[l0]:<6} {count:<6} {count/256*100:.1f}%")