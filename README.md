# Handling dates and performing complex or timed tasks in Bash

> Most of the time you run your script and you care about the result of that task. However, if the task becomes complex or it if it needs to execute to a particular time, there are other ways to achieve the same

Ideally by the end of this article you should be able to do the following:

* Learn how to format dates and use that as conditions to make your program to wait before moving to a next stage
* Sometimes we need to wait for a file, we don't know exactly how long. There is a better way than sleeping and retrying? (using inotify tools)
* What if you need to run your program at a specific time, based on some conditions? You can with ATQ
* If is a task you need to do more than one then Cron may be sufficient
* And finally, what if you have many tasks, running on different machines? Some of the tasks with complex relationships? Apache Airflow is a excelent tool for this type of situations.



## Getting the date inside a Bash script, formatting tricks

Say that you want to run a script and only try to download the 'COVID-19 Vaccinations by Town and Age Group' data from the state of CT, if the following conditions are met:

* It is during the week, no updates on the data are made over the weekend
* Run after 6:00 PM, no point of doing it sooner because there are no updates either

GNU /usr/bin/date supports [special format flags](https://www.redhat.com/sysadmin/formatting-date-command) with the special sign '+'. If you want to see the full list just type:

```shell=
/usr/bin/date --help
```

So anyways, back to our script we can get the current day of the week and hour of the day and perform a few simple comparisons with a simple [script](https://github.com/josevnz/DatesAndComplexInBash/blob/main/WorkingWithDateAndTime.sh):

```shell=
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
```

The output will be something like this when the right conditions are met:
```shell=
./WorkingWithDateAndTime.sh 
Downloaded: /home/josevnz/covid19-vaccinations-town-age-grp.csv
```


## Waiting for a file using inotify tools

TODO

## Running on the background is not enough, using atq

TODO

## Do it once by hand. Do it twice with Cron

TODO

## Multiple task dependencies, running on multiple hosts: Airflow to the rescue

TODO



