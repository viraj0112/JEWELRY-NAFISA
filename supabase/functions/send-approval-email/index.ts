import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { to, subject, html } = await req.json();
  const resendApiKey = Deno.env.get("RESEND_API_KEY");

  const emailPayload = { from: "youremail@example.com", to, subject, html };

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${resendApiKey}`,
    },
    body: JSON.stringify(emailPayload),
  });

  if (res.ok) {
    return new Response("Email sent successfully", { status: 200 });
  } else {
    const errorData = await res.json();
    return new Response(`Failed to send email: ${JSON.stringify(errorData)}`, { status: 500 });
  }
});