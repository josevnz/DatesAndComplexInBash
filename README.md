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

Let's switch to another type of problem: You are waiting for a file named "$HOME/lshw.json" to arrive and once is there you want to start processing it. I wrote this ([v1](https://github.com/josevnz/DatesAndComplexInBash/blob/main/WaitForFile.sh)):

```shell=
#!/bin/bash
# Wait for a file to arrive and once is there process it
# Author: Jose Vicente Nunez Zuleta
test -x /usr/bin/jq || exit 100
LSHW_FILE="$HOME/lshw.json"
# Enable the debug just to show what is going on...
trap "set +x" QUIT EXIT
set -x
while [ ! -f "$LSHW_FILE" ]; do
    sleep 30
done
/usr/bin/jq ".|.capabilities" "$LSHW_FILE"|| exit 100
```

And some magic process generate the file for us while we are waiting:
```shell=
sudo /usr/sbin/lshw -json > $HOME/lshw.json
```

And we wait... until the file arrives
```shell=
 ./WaitForFile.sh 
+ '[' '!' -f /home/josevnz/lshw.json ']'
+ sleep 30
+ '[' '!' -f /home/josevnz/lshw.json ']'
+ /usr/bin/jq '.|.capabilities' /home/josevnz/lshw.json
{
  "smbios-3.2.1": "SMBIOS version 3.2.1",
  "dmi-3.2.1": "DMI version 3.2.1",
  "smp": "Symmetric Multi-Processing",
  "vsyscall32": "32-bit processes"
}
+ set +x

```

There are a few problems with this approach:
* You may be waiting too much. If the file arrives 1 second after you start sleeping you wait 29 seconds doing nothing
* If you sleep too little you are wasting CPU cycles
* What happens if the file never arrives? You could use the timeout tool and a more complex logic to handle this scenario.

Or you can just use the [Inotify API](https://www.man7.org/linux/man-pages/man7/inotify.7.html) with [inotify-tools](https://github.com/inotify-tools/inotify-tools/wiki) and [do better](https://www.man7.org/linux/man-pages/man1/inotifywait.1.html), [version 2 of the script](https://github.com/josevnz/DatesAndComplexInBash/blob/main/WaitForFile2.sh):

```shell=
#!/bin/bash
# Wait for a file to arrive and once is there process it
# Author: Jose Vicente Nunez Zuleta
test -x /usr/bin/jq || exit 100
test -x /usr/bin/inotifywait|| exit 100
test -x /usr/bin/dirname|| exit 100
LSHW_FILE="$HOME/lshw.json"
while [ ! -f "$LSHW_FILE" ]; do
    test "$(/usr/bin/inotifywait --timeout 28800 --quiet --syslog --event close_write "$(/usr/bin/dirname "$LSHW_FILE")" --format '%w%f')" == "$LSHW_FILE" && break
done
/usr/bin/jq ".|.capabilities" "$LSHW_FILE"|| exit 100
```

So if a random file shows up on $HOME it won't break the wait cycle,but if our file shows up there and is fully written we will exit the loop:
```shell=
/usr/bin/touch $HOME/randomfilenobodycares.txt
sudo /usr/sbin/lshw -json > $HOME/lshw.json
```

Note the timeout in seconds (28,800 = 8 hours). inotifywait will exit after that if the file is not there...

## Do it once by hand. Do it twice with Cron

Do you remember the script we wrote to download the Covid 19 data early on? If we want to automate that we can make it part of a [cron-job](https://www.redhat.com/sysadmin/automate-linux-tasks-cron), without the hour and day of the week logic:

As a reminder, this is the command we want to run:
```shell=
report_file="$HOME/covid19-vaccinations-town-age-grp.csv"
# COVID-19 Vaccinations by Town and Age Group
/usr/bin/curl \
    --silent \
    --location \
    --fail \
    --output "$report_file" \
    --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD'
```

To run it every weekday at 6:00 PM and save the output to a log:

```shell=
# minute (0-59),
#    hour (0-23),
#       day of the month (1-31),
#          month of the year (1-12),
#             day of the week (0-6, 0=Sunday),
#                command
0 18 * * 1-5 /usr/bin/curl --silent --location --fail --output "$HOME/covid19-vaccinations-town-age-grp.csv"  --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD' > $HOME/logs/covid19-vaccinations-town-age-grp.log
```

Cron gives you also flexibility to do things that you can only achieve with other tools like systemd units. For example, say that I want to download the vaccination details as soon my Linux server is rebooted (This worked for me on Fedora 29):

```shell=
@reboot /usr/bin/curl --silent --location --fail --output "$HOME/covid19-vaccinations-town-age-grp.csv"  --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD' > $HOME/logs/covid19-vaccinations-town-age-grp.log
```

So how do you edit/ maintain your cron jobs? ```crontab -e``` gives you an interactive editor with some syntax checks). [I prefer to use Ansible cron module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/cron_module.html) to automate my cron editing, plus that ensures I can keep my jobs on Git for proper review and deploy.

Finally, cron syntax is very powerful and that can lead to unexpected complexity.You can use tools like [Crontab-Generator](https://crontab-generator.org/) to get the proper syntax, without having to think too much the meaning of each field.

Now ... *what if I need to run something but not right away*? Generating a crontab for that may be too complicated so lets see what else we can do.


## Running on the background is not enough, using atq

The unix tool atq is very similar to cron, but its beauty is that it support a ver loose and rich syntax on how to schedule jobs for execution.

Imagine the following example: You need to go out to run an errand in 50 minutes and you want to leave your server downloading a file. Let's say than it is OK to download the file in 60 minutes from now:


```shell=
cat aqt_job.txt
/usr/bin/curl --silent --location --fail --output "$HOME/covid19-vaccinations-town-age-grp.csv"  --url 'https://data.ct.gov/api/views/gngw-ukpw/rows.csv?accessType=DOWNLOAD'
at 'now + 1 hour' -f aqt_job.txt
warning: commands will be executed using /bin/sh
job 10 at Sat Aug 14 06:59:00 2021
```

We can confirm our job was indeed schedule for run (remember the job id = 10?):
```shell=
atq
10	Sat Aug 14 06:59:00 2021 a josevnz
```

And if we changed our mind, we can remove it:
```shell=
atrm 10
atq
```

Back to our original script. Let's rewrite it ([v3](https://github.com/josevnz/DatesAndComplexInBash/blob/main/WorkingWithDateAndTimeAt.sh)) to use 'at' instead of just 'date' for scheduling the data file download:

```shell=
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
```

So atq is a very convenient 'fire and forget' scheduler, who can also work with the load of the machine. You're more than welcome to go deeper and find out [more details about 'at'](https://linux.die.net/man/1/at).


## Multiple task dependencies, running on multiple hosts: Airflow to the rescue

This last example has little less to do with cron and Bash and more to how to create a complex pipeline of tasks, that can run on different machines and have interdependencies.

Crob specifically is not very good at  putting together multiple tasks that depend on each other. Luckyly for us, there are sophisticated tools like [Apache Airflow](https://airflow.apache.org/) that we can use to create complex pipelines and workflows.

I want to show you a different example: I have different git repositories across my machines at my home network. I want to ensure I commit changes on some of those repositores automatically, pushing some of those changes remotely if needed.

In Airflow you define your tasks using Python. This is great as you can add your own modules, the syntax is familiar and you can also keep your job definitions under version control (like Git).

So how does our new job looks like? Here [is the DAG](https://github.com/josevnz/DatesAndComplexInBash/blob/main/git_tasks.py) (heavily documented in Markup format):

```python=
# pylint: disable=pointless-statement,line-too-long
"""
# Make git backups on different hosts in Nunez family servers
## Replacing the following cron jobs on dmaf5
----------------------------------------------------------------------
MAILTO=kodegeek.com@protonmail.com
*/5 * * * * cd $HOME/Documents && /usr/bin/git add -A && /usr/bin/git commit -m "Automatic check-in" >/dev/null 2>&1
*/30 * * * * cd $HOME/Documents && /usr/bin/git push --mirror > $HOME/logs/codecommit-push.log 2>&1
----------------------------------------------------------------------
"""
from datetime import timedelta
from pathlib import Path
from os import path
from textwrap import dedent
from airflow import DAG
from airflow.providers.ssh.operators.ssh import SSHOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'josevnz',
    'depends_on_past': False,
    'email': ['myemail@kodegeek.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 5,
    'retry_delay': timedelta(minutes=30),
    'queue': 'git_queue'
}

TUTORIAL_PATH = f'{path.join(Path.home(), "DatesAndComplexInBash")}'
DOCUMENTS_PATH = f'{path.join(Path.home(), "Documents")}'

with DAG(
    'git_tasks',
    default_args=default_args,
    description='Git checking/push/pull across Nunez family servers, during week days 6:00-19:00',
    schedule_interval='*/30 6-19 * * 1-5',
    start_date=days_ago(2),
    tags=['backup', 'git'],
    ) as git_backup_dag:
    git_backup_dag.doc_md = __doc__

    git_commit_documents = SSHOperator(
        task_id='git_commit_documents',
        depends_on_past=False,
        ssh_conn_id="ssh_josevnz_dmaf5",
        params={'documents': DOCUMENTS_PATH},
        command=dedent(
        """
        cd {{params.documents}} && \
        /usr/bin/git add --ignore-errors --all \
        &&
        /usr/bin/git commit --quiet --message 'Automatic Document check-in @ dmaf5 {{ task }}'
        """
        )
    )
    git_commit_documents.doc_md = dedent(
    """
    #### Jose git commit PRIVATE documents on dmaf5 machine
    * Add and commit with a default message.
    * Templated using Jinja2 and f-strings
    """
    )

    git_push_documents = SSHOperator(
        task_id='git_push_documents',
        depends_on_past=False,
        ssh_conn_id="ssh_josevnz_dmaf5",
        params={'documents': DOCUMENTS_PATH},
        command=dedent(
        """
        cd {{params.documents}} && \
        /usr/bin/git push
        """
        )
    )
    git_push_documents.doc_md = dedent(
    """
    #### Jose git push PRIVATE documents from dmaf5 machine into private remote repository
    """
    )

    remote_repo_git_clone = BashOperator(
        task_id='remote_repo_git_clone',
        depends_on_past=False,
        params={'tutorial': TUTORIAL_PATH},
        bash_command=dedent(
        """
        cd {{params.tutorial}} \
        && \
        /usr/bin/git pull --quiet
        """
        )
    )
    remote_repo_git_clone.doc_md = dedent(
    """
    You need to clone the repository first:
    git clone --verbose git@github.com:josevnz/DatesAndComplexInBash.git
    Uses BashOperator as it runs on the same machine where Airflow runs.
    """
    )

    # Task relantionships
    # Git documents is a dependency for push documents
    git_commit_documents >> git_push_documents
    # No dependency except the day of the week and time
    remote_repo_git_clone
```

The relationships of these tasks can be seen on the GUI (In this case the graph mode)

![Git task relationships](https://github.com/josevnz/DatesAndComplexInBash/raw/main/git_tasks_dag.png "Git task DAG with 3 tasks")


There is a lot more to learn about Airflow. You are more than welcome to [look around](https://kodegeek-com.medium.com/using-airflow-to-replace-cron-on-your-home-network-7dbd2a35293) to get more details and learn more.

# Wrap up

That was a lot of ground to cover in one article. Dealing with dates and time is a complex task, but luckly you have plenty tools out there to help you in your coding tasks. Here are the things you learned how to do:

* Formatting options in /usr/bin/date that can be used to alter the way your scripts behave
* Using inotify-tools to efficiently listen for events related with the filesystem, like waiting for a file to be copied
* Automating periodic repetitive taks with 'cron' and using 'at' when a little bit more of flexibility is required
* When cron fails short you can resort to more advanced frameworks like Airflow.
* As usual, [statically check your scripts with pylint or bash SpellCheck](https://www.redhat.com/sysadmin/bash-error-handling). Save yourself some headaches.

