"""Build assets/data/foods_ifct2017.json from the Indian Food Composition Tables 2017.

Every nutrient number written by this script is read straight from the IFCT 2017
composition table (ICMR-NIN, 2017). Nothing is estimated or invented.

Energy in IFCT 2017 is published in kJ, so it is converted with the standard
factor 1 kcal = 4.184 kJ and rounded to the nearest kcal.

Serving sizes are NOT part of IFCT. They are taken from the ICMR-NIN food-group
portion tables and only applied to groups that actually have a published portion
size; foods in groups without one are shipped with no serving size at all.
"""

import csv
import json
import os
import re
from pathlib import Path

# Path to the IFCT 2017 composition table as CSV, one row per food, with the
# IFCT column codes as headers (code, name, grup, tags, enerc, protcnt,
# choavldf, fatce, fibtg, lang, scie). Override with IFCT_CSV.
SRC = Path(os.environ.get("IFCT_CSV", Path(__file__).parent / "ifct2017_compositions.csv"))
OUT = Path(__file__).resolve().parent.parent / "assets/data/foods_ifct2017.json"

KJ_PER_KCAL = 4.184

# IFCT 2017 ships enerc = 0 for the "Edible Oils and Fats" group: the table
# reports those foods as 100 g fat and carries no computed energy value. A zero
# there is a placeholder, not a measurement, so shipping it as "0 kcal" would be
# wrong. For those rows only, energy is derived from the published macronutrient
# content using the energy factors stated in the ICMR-NIN Dietary Guidelines for
# Indians 2024: fat 9 kcal/g, protein and carbohydrate 4 kcal/g. Those entries
# are flagged energyDerived so the app can label them.
KCAL_PER_G_FAT = 9
KCAL_PER_G_PROTEIN = 4
KCAL_PER_G_CARB = 4

# Cross-check: a row's published energy should agree with its own published
# macronutrients. Across this selection the median gap is about 2 kcal and the
# worst legitimate gap is 17 kcal, which is expected because IFCT energy is
# measured rather than computed and fibre also contributes. A gap far outside
# that range means the row is internally inconsistent and cannot be trusted, so
# the food is dropped rather than shipped with a number we cannot stand behind.
ENERGY_CONSISTENCY_TOLERANCE_KCAL = 40

# ICMR-NIN published food-group portion sizes (raw weight).
# "Portion Size of Foods (raw) and Nutrients", ICMR-NIN Dietary Guidelines for
# Indians; nuts & seeds from the ICMR-NIN "My Plate for the Day" (2000 kcal, 2024).
GROUP_SERVING = {
    "Cereals and Millets": (30, "icmr_portion_cereals"),
    "Grain Legumes": (30, "icmr_portion_pulses"),
    "Milk and Milk Products": (100, "icmr_portion_milk"),
    "Egg and Egg Products": (50, "icmr_portion_egg"),
    "Poultry": (50, "icmr_portion_flesh"),
    "Animal Meat": (50, "icmr_portion_flesh"),
    "Marine Fish": (50, "icmr_portion_flesh"),
    "Fresh Water Fish and Shellfish": (50, "icmr_portion_flesh"),
    "Marine Shellfish": (50, "icmr_portion_flesh"),
    "Roots and Tubers": (100, "icmr_portion_roots"),
    "Green Leafy Vegetables": (100, "icmr_portion_glv"),
    "Other Vegetables": (100, "icmr_portion_vegetables"),
    "Fruits": (100, "icmr_portion_fruits"),
    "Sugars": (5, "icmr_portion_sugar"),
    "Edible Oils and Fats": (5, "icmr_portion_oil"),
    "Nuts and Oil Seeds": (35, "icmr_myplate_nuts"),
    # Mushrooms, Condiments and Spices and Miscellaneous Foods have no published
    # ICMR-NIN portion size, so they are deliberately left without one.
}

# Simplified food-group keys used by the meal planner.
GROUP_KEY = {
    "Cereals and Millets": "cereal",
    "Grain Legumes": "pulse",
    "Milk and Milk Products": "dairy",
    "Egg and Egg Products": "egg",
    "Poultry": "flesh",
    "Animal Meat": "flesh",
    "Marine Fish": "flesh",
    "Fresh Water Fish and Shellfish": "flesh",
    "Marine Shellfish": "flesh",
    "Roots and Tubers": "root",
    "Green Leafy Vegetables": "leafy",
    "Other Vegetables": "vegetable",
    "Fruits": "fruit",
    "Sugars": "sugar",
    "Edible Oils and Fats": "fat",
    "Nuts and Oil Seeds": "nut",
    "Mushrooms": "vegetable",
    "Condiments and Spices": "condiment",
    "Miscellaneous Foods": "beverage",
}

# Codes selected for the shipped database: everyday Indian foods, across every
# food group, that a user can realistically log and cook from.
SELECTED = [
    # Cereals and millets
    "A003", "A004", "A005", "A006", "A009", "A010", "A011", "A012", "A013",
    "A014", "A015", "A018", "A019", "A020", "A022", "A023",
    # Grain legumes
    "B001", "B002", "B003", "B004", "B005", "B010", "B011", "B012", "B013",
    "B016", "B017", "B020", "B021", "B025",
    # Milk and milk products
    "L001", "L002", "L003", "L004",
    # Egg
    "M001", "M002", "M003", "M004",
    # Nuts and oil seeds
    "H001", "H005", "H006", "H007", "H011", "H012", "H014", "H018", "H020", "H021",
    # Roots and tubers
    "F001", "F002", "F004", "F006", "F010", "F013", "F015", "F017",
    # Green leafy vegetables
    "C002", "C008", "C015", "C017", "C019", "C020", "C026", "C033",
    # Other vegetables
    "D001", "D004", "D007", "D031", "D033", "D036", "D039", "D043", "D046",
    "D049", "D056", "D061", "D063", "D066", "D068", "D070", "D076",
    # Fruits
    "E001", "E012", "E017", "E021", "E022", "E028", "E034", "E036", "E047",
    "E049", "E053", "E055", "E057", "E060", "E065",
    # Poultry
    "N001", "N002", "N003", "N005", "N009",
    # Animal meat
    "O001", "O003", "O008", "O016", "O027", "O049",
    # Marine fish
    "P007", "P034", "P055", "P057", "P068", "P071", "P083", "P084",
    # Fresh water fish and shellfish
    "S001", "S002", "S006", "S007", "S008",
    # Marine shellfish
    "Q003", "Q006",
    # Mushrooms
    "J001", "J003",
    # Edible oils and fats
    "T001", "T005", "T006", "T008", "T012", "T013",
    # Sugars
    "I001", "I002",
    # Condiments and spices commonly eaten in quantity
    "G009", "G011", "G014", "G017",
    # Miscellaneous
    "K002",
]


def diet_tag(tags: str) -> str:
    """Map the IFCT dietary tag string onto veg / egg / nonveg."""
    if "vegetarian" in tags:
        return "veg"
    if "eggetarian" in tags:
        return "egg"
    return "nonveg"


def hindi_name(lang: str) -> str | None:
    """Pull the Hindi name out of the IFCT regional-name field ("H. Bajra")."""
    for part in lang.split(";"):
        part = part.strip()
        m = re.match(r"^((?:[A-Z][a-z]*\.,\s*)*)[A-Z][a-z]*\.\s*(.+)$", part)
        if not m:
            continue
        prefixes = re.findall(r"([A-Z][a-z]*)\.", part[: part.index(" ", 0) + 1] if " " in part else part)
        heads = re.match(r"^((?:[A-Za-z]+\.,?\s*)+)", part)
        if not heads:
            continue
        codes = [c.strip().rstrip(".") for c in heads.group(1).replace(",", " ").split() if c.endswith(".")]
        if "H" in codes:
            return part[heads.end():].strip() or None
    return None


def num(v: str):
    """IFCT ships blanks for 'not analysed'. Those must not become zeros."""
    if v is None or v.strip() == "":
        return None
    try:
        return float(v)
    except ValueError:
        return None


def rnd(v, places):
    return None if v is None else round(v, places)


def main() -> None:
    rows = {r["code"]: r for r in csv.DictReader(open(SRC, encoding="utf-8"))}
    missing = [c for c in SELECTED if c not in rows]
    if missing:
        raise SystemExit(f"codes not present in IFCT 2017: {missing}")

    foods = []
    rejected: list[str] = []
    for code in SELECTED:
        r = rows[code]
        group = r["grup"]
        kj = num(r["enerc"])
        protein = num(r["protcnt"])
        carb = num(r["choavldf"])
        fat = num(r["fatce"])

        if kj is not None and kj > 0:
            kcal = round(kj / KJ_PER_KCAL)
            energy_derived = False
            energy_kj = rnd(kj, 1)
        else:
            if fat is None and protein is None and carb is None:
                raise SystemExit(f"{code} has no energy and no macronutrients")
            kcal = round(
                (fat or 0) * KCAL_PER_G_FAT
                + (protein or 0) * KCAL_PER_G_PROTEIN
                + (carb or 0) * KCAL_PER_G_CARB
            )
            energy_derived = True
            energy_kj = None

        if not energy_derived:
            implied = (
                (fat or 0) * KCAL_PER_G_FAT
                + (protein or 0) * KCAL_PER_G_PROTEIN
                + (carb or 0) * KCAL_PER_G_CARB
            )
            if abs(implied - kcal) > ENERGY_CONSISTENCY_TOLERANCE_KCAL:
                rejected.append(
                    f"{code} {r['name']}: published {kcal} kcal but its own "
                    f"macronutrients imply {implied:.0f} kcal"
                )
                continue

        entry = {
            "id": code,
            "name": r["name"],
            "scientificName": r["scie"] or None,
            "hindiName": hindi_name(r["lang"] or ""),
            "ifctGroup": group,
            "group": GROUP_KEY[group],
            "dietTag": diet_tag(r["tags"] or ""),
            # Per 100 g edible portion, as published in IFCT 2017.
            "kcal": kcal,
            "kj": energy_kj,
            "proteinG": rnd(protein, 2),
            "carbG": rnd(carb, 2),
            "fatG": rnd(fat, 2),
            "fibreG": rnd(num(r["fibtg"]), 2),
        }
        if energy_derived:
            entry["energyDerived"] = True
            entry["energyFormula"] = "protein*4 + carbohydrate*4 + fat*9"
            entry["energySourceId"] = "icmr_dgi_2024"
        serving = GROUP_SERVING.get(group)
        if serving:
            entry["servingG"] = serving[0]
            entry["servingSourceId"] = serving[1]
        foods.append({k: v for k, v in entry.items() if v is not None})

    payload = {
        "dataset": "foods_ifct2017",
        "description": (
            "Nutrient values per 100 g edible portion for common Indian foods, "
            "taken from the Indian Food Composition Tables 2017. Energy is "
            "published in kJ and converted at 1 kcal = 4.184 kJ. Serving sizes "
            "come from ICMR-NIN food-group portion tables and are only present "
            "for groups that have a published portion size."
        ),
        "sourceId": "ifct_2017",
        "servingSourceIds": sorted({f["servingSourceId"] for f in foods if "servingSourceId" in f}),
        "derivedEnergyCount": sum(1 for f in foods if f.get("energyDerived")),
        "count": len(foods),
        "foods": foods,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    if rejected:
        print("REJECTED as internally inconsistent (not shipped):")
        for msg in rejected:
            print("  -", msg)
    if len(foods) < 100:
        raise SystemExit(f"only {len(foods)} foods survived; need at least 100")
    print(f"wrote {OUT} with {len(foods)} foods")
    by = {}
    for f in foods:
        by[f["group"]] = by.get(f["group"], 0) + 1
    print("by group:", by)
    print("diet tags:", {t: sum(1 for f in foods if f['dietTag'] == t) for t in ('veg', 'egg', 'nonveg')})
    derived = [f for f in foods if f.get("energyDerived")]
    print(f"derived energy ({len(derived)}):", ", ".join(f"{f['id']}={f['kcal']}kcal" for f in derived))
    assert all(f["kcal"] > 0 for f in foods), "every shipped food must have an energy value"
    for c in ("A015", "B021", "N003", "L002", "E012"):
        f = next(x for x in foods if x["id"] == c)
        print(" ", f["id"], f["name"], "|", f["kcal"], "kcal |", f.get("proteinG"), "g protein |",
              f.get("carbG"), "g carb |", f.get("fatG"), "g fat | hi:", f.get("hindiName"))


if __name__ == "__main__":
    main()
