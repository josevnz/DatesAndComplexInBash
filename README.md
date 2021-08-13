# Handling dates and performing complex or timed tasks in Bash

> Most of the time you run your script and you care about the result of that task. However, if the task becomes complex or it if it needs to execute to a particular time, there are other ways to achieve the same

Ideally by the end of this article you should be able to do the following:

* Learn how to format dates and use that as conditions to make your program to wait before moving to a next stage
* Sometimes we need to wait for a file, we don't know exactly how long. There is a better way than sleeping and retrying? (using inotify tools)
* What if you need to run your program at a specific time, based on some conditions? You can with ATQ
* If is a task you need to do more than one then Cron may be sufficient
* And finally, what if you have many tasks, running on different machines? Some of the tasks with complex relationships? Apache Airflow is a excelent tool for this type of situations.



## Getting the date inside a Bash script, formatting tricks

TODO

## Waiting for a file using inotify tools

TODO

## Running on the background is not enough, using atq

TODO

## Do it once by hand. Do it twice with Cron

TODO

## Multiple task dependencies, running on multiple hosts: Airflow to the rescue

TODO


