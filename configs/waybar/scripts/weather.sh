#!/usr/bin/env bash

set -e

token=$(secret-tool lookup eww-widget weather || true)
if [[ -z "$token" ]]; then
    echo '{}'
    exit 0
fi

curl -s "https://api.openweathermap.org/data/2.5/weather?q=Kyiv,ua&APPID=$token" \
    | jq --unbuffered --compact-output '{
          text: (.main.temp - 273.15 | . * 10 | round | . / 10 | tostring),
          tooltip: ("Humidity: " + (.main.humidity | tostring) + "%\nWind speed: " + (.wind.speed | tostring) + " m/s\n\nSunrise: " + (.sys.sunrise | strflocaltime("%H:%M")) + "\nSunset: " + (.sys.sunset | strflocaltime("%H:%M"))),
      }'
