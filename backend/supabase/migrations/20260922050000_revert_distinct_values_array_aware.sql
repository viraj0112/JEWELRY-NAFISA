-- Reverts 20260922040000_distinct_values_array_aware.sql.
-- Restores get_distinct_product_values exactly as it was in production
-- (backend/database/prod_schema.sql): products + designerproducts, scalar
-- comparison, plpgsql, SECURITY DEFINER, default volatility and search_path.

CREATE OR REPLACE FUNCTION "public"."get_distinct_product_values"("column_name" "text") RETURNS SETOF "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY EXECUTE format(
    'SELECT DISTINCT %I::TEXT FROM public.products WHERE %I IS NOT NULL AND %I <> ''''
     UNION
     SELECT DISTINCT %I::TEXT FROM public.designerproducts WHERE %I IS NOT NULL AND %I <> ''''',
    column_name, column_name, column_name, column_name, column_name, column_name
  );
END;
$$;

-- Make sure the search_path the reverted version set is gone.
ALTER FUNCTION "public"."get_distinct_product_values"("column_name" "text") RESET search_path;

ALTER FUNCTION "public"."get_distinct_product_values"("column_name" "text") OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."get_distinct_product_values"("column_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_distinct_product_values"("column_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_distinct_product_values"("column_name" "text") TO "service_role";
