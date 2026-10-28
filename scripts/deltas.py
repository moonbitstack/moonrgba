"""Colour differences 76, 94 and 2000, computed by colour-science.

colorjs.io implements 76 and 2000 but not 94, so the third measure has its
reference here. Two independent implementations agreeing on the two they share is
itself worth knowing, and `scripts/numbers.mjs` covers that.

    pip install colour-science
    python scripts/deltas.py deltas.tsv

Then `python scripts/fixtures.py deltas deltas.tsv src/deltas_wbtest.mbt`.

Output is tab separated: the measure, the space, six components, the value.
"""

import random
import sys

from colour.difference import delta_E_CIE1976, delta_E_CIE1994, delta_E_CIE2000


def main(target: str) -> None:
    rng = random.Random(1994)
    rows = []
    pairs = [
        (
            [rng.uniform(0, 100), rng.uniform(-100, 100), rng.uniform(-100, 100)],
            [rng.uniform(0, 100), rng.uniform(-100, 100), rng.uniform(-100, 100)],
        )
        for _ in range(80)
    ]
    # The pairs Sharma, Wu and Dalal publish as the test set for CIEDE2000,
    # which are the ones every implementation is checked against.
    pairs += [
        ([50.0, 2.6772, -79.7751], [50.0, 0.0, -82.7485]),
        ([50.0, 3.1571, -77.2803], [50.0, 0.0, -82.7485]),
        ([50.0, 2.8361, -74.0200], [50.0, 0.0, -82.7485]),
        ([50.0, -1.3802, -84.2814], [50.0, 0.0, -82.7485]),
        ([50.0, -1.1848, -84.8006], [50.0, 0.0, -82.7485]),
        ([50.0, -0.9009, -85.5211], [50.0, 0.0, -82.7485]),
        ([50.0, 0.0, 0.0], [50.0, -1.0, 2.0]),
        ([50.0, -1.0, 2.0], [50.0, 0.0, 0.0]),
        ([50.0, 2.49, -0.001], [50.0, -2.49, 0.0009]),
        ([50.0, 2.49, -0.001], [50.0, -2.49, 0.0011]),
        ([50.0, -0.001, 2.49], [50.0, 0.0009, -2.49]),
        ([50.0, 2.5, 0.0], [50.0, 0.0, -2.5]),
        ([50.0, 2.5, 0.0], [73.0, 25.0, -18.0]),
        ([50.0, 2.5, 0.0], [61.0, -5.0, 29.0]),
        ([50.0, 2.5, 0.0], [56.0, -27.0, -3.0]),
        ([50.0, 2.5, 0.0], [58.0, 24.0, 15.0]),
        ([60.2574, -34.0099, 36.2677], [60.4626, -34.1751, 39.4387]),
        ([63.0109, -31.0961, -5.8663], [62.8187, -29.7946, -4.0864]),
        ([61.2901, 3.7196, -5.3901], [61.4292, 2.2480, -4.9620]),
        ([35.0831, -44.1164, 3.7933], [35.0232, -40.0716, 1.5901]),
        ([22.7233, 20.0904, -46.6940], [23.0331, 14.9730, -42.5619]),
        ([36.4612, 47.8580, 18.3852], [36.2715, 50.5065, 21.2231]),
        ([90.8027, -2.0831, 1.4410], [91.1528, -1.6435, 0.0447]),
        ([90.9257, -0.5406, -0.9208], [88.6381, -0.8985, -0.7239]),
        ([6.7747, -0.2908, -2.4247], [5.8714, -0.0985, -2.2286]),
        ([2.0776, 0.0795, -1.1350], [0.9033, -0.0636, -0.5514]),
    ]
    for first, second in pairs:
        rows.append(["76", "lab", *first, *second, delta_E_CIE1976(first, second)])
        rows.append(
            ["94", "lab", *first, *second, delta_E_CIE1994(first, second, textiles=False)]
        )
        rows.append(["2000", "lab", *first, *second, delta_E_CIE2000(first, second)])
    lines = ["\t".join(str(field) for field in row) for row in rows]
    with open(target, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"{len(rows)} rows written to {target}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "deltas.tsv")
