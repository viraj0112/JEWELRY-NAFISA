import json

def generate_sql_from_json(json_file_path, table_name):
    """
    Reads a JSON file and generates a complete SQL script to truncate
    the table and insert new data.
    """
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading {json_file_path}: {e}")
        return ""

    if not data or not isinstance(data, list):
        return ""

    # Get column names from the first item, excluding 'id'
    first_item_keys = [key for key in data[0].keys() if key != 'id']
    columns_str = ', '.join(f'"{key}"' for key in first_item_keys)

    insert_values = []
    for item in data:
        values = []
        for key in first_item_keys:
            value = item.get(key)
            if value is None:
                values.append("NULL")
            elif isinstance(value, str):
                escaped_value = value.replace("'", "''")
                values.append(f"'{escaped_value}'")
            elif isinstance(value, list):
                # Correctly format the list as a PostgreSQL array literal
                escaped_items = [str(v).replace("'", "''") for v in value]
                array_literal = "ARRAY['" + "','".join(escaped_items) + "']"
                values.append(array_literal)
            else:
                values.append(str(value))
        
        values_str = ', '.join(values)
        insert_values.append(f"({values_str})")

    if not insert_values:
        return ""

    # Using TRUNCATE is efficient and resets the auto-incrementing ID
    full_sql_statement = (
        f"TRUNCATE public.{table_name} RESTART IDENTITY CASCADE;\n\n"
        f"INSERT INTO public.{table_name} ({columns_str}) VALUES\n"
        + ",\n".join(insert_values)
        + ";\n"
    )
    return full_sql_statement

if __name__ == "__main__":
    json_file = 'C:/Users/Viraj Sawant/Desktop/_Flutter_/scraped_jewelry_data.json'
    table = 'products'
    sql_script = generate_sql_from_json(json_file, table)

    if sql_script:
        output_file = 'supabase/seed.sql'
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(sql_script)
        print(f"✅ Successfully generated {output_file}")