import csv

def normalize_int(value):
    """
    Converts CSV value to integer or NULL for SQL.
    """
    if not value or value.strip().lower() in ("null", "none", "na", "n/a"):
        return "NULL"
    try:
        # handle numbers that might be formatted as floats like "12.0"
        return str(int(float(value)))
    except (ValueError, TypeError):
        return "NULL"

def create_sql_insert_from_csv(csv_filepath, table_name):
    """
    Reads a cleaned CSV file and generates SQL INSERT statements for the 'products' table.
    """
    sql_statements = []
    
    with open(csv_filepath, mode='r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        
        for row in reader:
            # Escape single quotes for all text fields
            title = row.get('title', '').replace("'", "''")
            description = row.get('description', '').replace("'", "''")
            image_url = row.get('image_url', '')
            category = row.get('category', '').replace("'", "''")
            sub_category = row.get('sub_category', '').replace("'", "''")
            metal = row.get('metal', '').replace("'", "''")
            purity = row.get('purity', '').replace("'", "''")
            stone_type = row.get('stone_type', '').replace("'", "''")
            dimensions = row.get('dimensions', '').replace("'", "''")

            # --- NUMERIC FIELDS ---
            # Remove commas from price and normalize
            price_str = row.get('price', '').replace(',', '')
            price = normalize_int(price_str)

            # Normalize weight fields
            gold_weight = normalize_int(row.get('gold_weight'))
            stone_weight = normalize_int(row.get('stone_weight'))

            # --- TAGS FIELD (THE FIX) ---
            # Get tags and escape single quotes
            tags_str = row.get('tags', '').replace("'", "''")
            
            # --- CONSTRUCT SQL TUPLE ---
            # The line `tags = f"'{tags_str}'"` has been removed.
            # The 'tags_str' variable is now correctly quoted directly within the f-string.
            sql = (
                f"('{title}', '{description}', {price}, '{image_url}', "
                f"'{tags_str}', '{category}', '{sub_category}', '{metal}', '{purity}', "
                f"'{stone_type}', '{dimensions}', {gold_weight}, {stone_weight})"
            )
            sql_statements.append(sql)

    if not sql_statements:
        return ""

    # --- FINAL SQL STATEMENT ---
    full_sql_statement = (
        f"INSERT INTO public.{table_name} "
        f"(title, description, price, image_url, tags, category, sub_category, metal, purity, stone_type, dimensions, gold_weight, stone_weight) VALUES\n"
        + ",\n".join(sql_statements)
        + ";\n"
    )
    return full_sql_statement


# --- SCRIPT EXECUTION ---
CSV_FILE = 'Jewelry-data.csv' 
TABLE_NAME = 'products'
OUTPUT_FILE = 'seed.sql'

sql_output = create_sql_insert_from_csv(CSV_FILE, TABLE_NAME)

with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    f.write(sql_output)

print(f"✅ Successfully generated '{OUTPUT_FILE}'. You can now move this file to your 'supabase' directory.")