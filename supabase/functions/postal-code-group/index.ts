// Setup type definitions for built-in Supabase Runtime APIs
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    // Parse request body
    const body = await req.json();
    const pincode = body?.pincode;

    if (!pincode) {
      return new Response(
        JSON.stringify({ error: "Pincode is required" }),
        { status: 400 }
      );
    }

    // Call India Post API
    const apiResponse = await fetch(
      `https://api.postalpincode.in/pincode/${pincode}`
    );

    const data = await apiResponse.json();

    // Validate API response
    if (!data || data.length === 0 || data[0].Status !== "Success") {
      return new Response(
        JSON.stringify({ error: "Invalid pincode" }),
        { status: 404 }
      );
    }

    const postOffices = data[0].PostOffice;

    if (!postOffices || postOffices.length === 0) {
      return new Response(
        JSON.stringify({ error: "No post office found" }),
        { status: 404 }
      );
    }

    // Just take first entry (simple analytics usage)
    const office = postOffices[0];

    const result = {
      pincode: office.Pincode,
      state: office.State,
      district: office.District
    };

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    );
  }
});
// https://cxnkagfbymztpwszfaiw.supabase.co/functions/v1/pincode-lookup