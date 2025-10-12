-- Rename existing columns to match your new naming convention
ALTER TABLE public.products RENAME COLUMN "description" TO "Description";
ALTER TABLE public.products RENAME COLUMN "price" TO "Price";
ALTER TABLE public.products RENAME COLUMN "image" TO "Image";
ALTER TABLE public.products RENAME COLUMN "Metal Purity / Carat" TO "Metal Purity";
ALTER TABLE public.products RENAME COLUMN "Stone Weight (Carat / ct)" TO "Stone Weight";
ALTER TABLE public.products RENAME COLUMN "Dimensions" TO "Dimension";
ALTER TABLE public.products RENAME COLUMN "scraped_url" TO "Scraped URL";
ALTER TABLE public.products RENAME COLUMN  "Total Product Weight" TO "NET WEIGHT";
ALTER TABLE public.products RENAME COLUMN "Enamel Work / Embellishment" TO "Enamel Work";


-- Drop the old columns that are no longer needed
ALTER TABLE public.products DROP COLUMN "category";
ALTER TABLE public.products DROP COLUMN "Sub Category";
ALTER TABLE public.products DROP COLUMN "size";
ALTER TABLE public.products DROP COLUMN "Occasion";
ALTER TABLE public.products DROP COLUMN "style";
ALTER TABLE public.products DROP COLUMN "Product Code";

