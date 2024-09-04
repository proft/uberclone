// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
// import "jsr:@supabase/functions-js/edge-runtime.d.ts"
//
// type Coordinates = {
//   latitude: number;
//   longitude: number;
// };
//
// Deno.serve(async (req) => {
//   const {origin, destination}: {
//     origin: Coordinates;
//     destination: Coordinates;
//   } = await req.json();
//
//   const response = await fetch(`https://routes.googleapis.com/directions/v2:computeRoutes?key=${Deno.env.get('GOOGLE_MAPS_API_KEY')}`, {
//     method: 'POST',
//     headers: {
//       "Content-Type": "application/json",
//       "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline,routes.legs.polyline"
//     },
//     body: JSON.stringify({
//       origin: { location: {latLng: origin} },
//       destination: { location: {latLng: destination} },
//       travelMode: 'DRIVE',
//       polylineEncoding: 'GEO_JSON_LINESTRING',
//     })
//   });
//
//   if (!response.ok) {
//     const error = await response.json();
//     console.error(error)
//     throw new Error('HTTP ERROR')
//   }
//
//   const data = await response.json();
//   const res = data.routes[0];
//
//   return new Response(
//     JSON.stringify(res),
//     { headers: { "Content-Type": "application/json" } },
//   )
// })

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'https://xXx.supabase.co/functions/v1/routes' \
    --header 'Authorization: Bearer xXx' \
    --header 'Content-Type: application/json' \
    --data '{"origin":{"latitude": 37.7749, "longitude": -122.4149}, "destination": {"latitude": 37.7849, "longitude": -122.4294}}'

*/

type Coordinates = {
  latitude: number;
  longitude: number;
};

Deno.serve(async (req) => {
  const { origin, destination }: {
    origin: Coordinates;
    destination: Coordinates;
  } = await req.json();

  const response = await fetch(
    `https://routes.googleapis.com/directions/v2:computeRoutes?key=${
      Deno.env.get("GOOGLE_MAPS_API_KEY")
    }`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-FieldMask":
          "routes.duration,routes.distanceMeters,routes.polyline,routes.legs.polyline",
      },
      body: JSON.stringify({
        origin: { location: { latLng: origin } },
        destination: { location: { latLng: destination } },
        travelMode: "DRIVE",
        polylineEncoding: "GEO_JSON_LINESTRING",
      }),
    },
  );

  if (!response.ok) {
    const error = await response.json();
    console.error({ error });
    throw new Error(`HTTP error! status: ${response.status}`);
  }

  const data = await response.json();

  const res = data.routes[0];

  return new Response(
    JSON.stringify(res),
    { headers: { "Content-Type": "application/json" } },
  );
});