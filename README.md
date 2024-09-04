# uberclone

Here is an Uber clone on Flutter + Google Map and Supabase as a backend.

|                       Selecting destination                       |                              Driver is on way                               |
|:-----------------------------------------------------------------:|:---------------------------------------------------------------------------:|
| ![List](https://en.proft.me/media/android/flutter_uberclone1.jpg) | ![Details screen](https://en.proft.me/media/android/flutter_uberclone2.jpg) | 

# Preparing

## Google 

1. Open https://console.cloud.google.com/apis/dashboard
2. Enable Route Api and Maps for iOS

## Install Docker Desktop on Mac

Open https://docs.docker.com/desktop/install/mac-install/

## Install Supabase CLI with Homebrew

```
brew install supabase/tap/supabase
```

## Open Terminal in your Android Studio and run

```
supabase init
supabase functions new routes
```

## Create database 

Open database.new in your browser 

## Login and Link

```
supabase login
supabase link --project-ref=xXx
```

## Deploy functions to the backend

```
supabase secrets set --env-file ./supabase/.env
supabase functions deploy
```

## Enable Auth

Go to Settings > Authentication. Click Allow anonymous sign-ins. Hit Save.

## Setup database

Go to https://supabase.com/dashboard/
Select Database > Extensions and enable Postgis