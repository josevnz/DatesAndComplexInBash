#!/bin/bash
# Simple script that shows how to work with dates and times, and Unix 'at'
# Jose Vicente Nunez Zuleta
#
test -x /usr/bin/date || exit 100
test -x /usr/bin/at || exit 100

report_file="$HOME/covid19-vaccinations-town-age-grp.csv"
export report_file

function create_at_job_file {
    /usr/bin/cat<<AT_FILE>"$1"
    # COVID-19 Vaccinations by Town and Age Group
    /usr/bin/curl \
        --silent \
        --location \
        --fail \
        --output "$report_file" \
        --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD'
AT_FILE
}

function is_week_day {
  local -i day_of_week
  day_of_week=$(/usr/bin/date +%u)|| exit 100
  # 1 = Monday .. 5 = Friday
  test "$day_of_week" -ge 1 -a "$day_of_week" -le 5 && return 0 || return 1
}

function already_there {
    # My job is easy to spot as it has a unique footprint...
    for job_id in $(/usr/bin/atq| /usr/bin/cut -f1 -d' '| /usr/bin/tr -d 'a-zA-Z'); do
      if [ "$(/usr/bin/at -c "$job_id"| /usr/bin/grep -c 'COVID-19 Vaccinations by Town and Age Group')" -eq 1 ]; then
        echo "Hmmm, looks like job $job_id is already there. Not scheduling a new one. To cancel: '/usr/bin/atrm $job_id'"
        return 1
      fi
    done
    return 0
}

# No updates during the weekend, so don't bother (not an error)
is_week_day || exit 0

# Did we schedule this before?
already_there|| exit 100

ATQ_FILE=$(/usr/bin/mktemp)|| exit 100
export ATQ_FILE
trap '/bin/rm -f $ATQ_FILE' INT EXIT QUIT
echo "$ATQ_FILE"
create_at_job_file "$ATQ_FILE"|| exit 100
/usr/bin/at '6:00 PM' -f "$ATQ_FILE"
