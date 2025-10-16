
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!
);

serve(async (req) => {
  const { file_id } = await req.json();
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0];

  let country = 'Unknown';
  if (ip) {
    try {
      const geoResponse = await fetch(`https://ipapi.co/${ip}/json/`);
      const geoData = await geoResponse.json();
      country = geoData.country_name || 'Unknown';
    } catch (error) {
      console.error('Error fetching geolocation:', error);
    }
  }

  const { error } = await supabase.from('views').insert([
    { file_id, country },
  ]);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});