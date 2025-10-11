import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    const { record: newUser } = await req.json();

    if (!newUser || newUser.role !== "designer") {
      console.log(`Not a designer, skipping email for user: ${newUser?.id}`);
      return new Response("ok - not a designer, skipping email", {
        status: 200,
      });
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      throw new Error("RESEND_API_KEY is not set in Supabase secrets.");
    }

    const emailHtml = `
      <h1>Welcome to Dagina Designs!</h1>
      <p>Hi ${newUser.full_name || "Designer"},</p>
      <p>We have received your details to get you on board. Our team will review your application and get back to you soon!</p>
      <p>Best Regards,<br/>The Dagina Team</p>
    `;

    const emailPayload = {
      from: "adminuser0112@gmail.com",
      to: newUser.email,
      subject: "Welcome to Dagina Designs! We've received your application.",
      html: emailHtml,
    };

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify(emailPayload),
    });

    if (res.ok) {
      console.log("Welcome email sent successfully to:", newUser.email);
      return new Response("ok - email sent", { status: 200 });
    } else {
      const errorData = await res.json();
      console.error("Failed to send email:", errorData);
      throw new Error(`Resend API error: ${JSON.stringify(errorData)}`);
    }
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : "An unknown error occurred";

    console.error("Error processing request:", errorMessage, error);

    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
