#!/bin/bash
# Simple script that shows how to work with dates and times
# Jose Vicente Nunez Zuleta
#

test -x /usr/bin/date || exit 100

function is_week_day {
  local -i day_of_week
  day_of_week=$(/usr/bin/date +%u)|| exit 100
  # 1 = Monday .. 5 = Friday
  test "$day_of_week" -ge 1 -a "$day_of_week" -le 5 && return 0 || return 1
}

function too_early {
    local -i hour
    hour=$(/usr/bin/date +%H)|| exit 100
    test "$hour" -gt 18 && return 0|| return 1 
}

# No updates during the weekend, so don't bother (not an error)
is_week_day || exit 0

# Don't bother to check before 6:00 PM
too_early || exit 0

report_file="$HOME/covid19-vaccinations-town-age-grp.csv"
# COVID-19 Vaccinations by Town and Age Group
/usr/bin/curl \
    --silent \
    --location \
    --fail \
    --output "$report_file" \
    --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD'

echo "Downloaded: $report_file"
