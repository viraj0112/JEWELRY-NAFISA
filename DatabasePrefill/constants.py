
# Target columns to be processed
# NOTE (post-Phase-3 schema): "Category1"/"Category2"/"Category3" were
# dropped - the DB now has a single "Category" text[] column, so those three
# are removed rather than renamed. "Enamel work" is corrected to "Enamel
# Work" to match the real column name (was silently never matching before).
# "Category" and "Metal Color" are now text[] arrays, not scalars - callers
# reading TARGET_COLUMNS to build filters/updates must treat them as arrays.
TARGET_COLUMNS = [
    "Description",
    "Product Tags",
    "Metal Finish",
    "Stone Type",
    "Stone Used",
    "Stone Setting",
    "Stone Count",
    "Metal Color",
    "Stone Color",
    "Stone Cut",
    "Enamel Work",
    "Category",
    "Plain",
    "Studded",
]

