# pylint: disable=pointless-statement,line-too-long
"""
# Make git backups on different hosts in Nunez family servers
## Replacing the following cron jobs on dmaf5

```shell
MAILTO=kodegeek.com@protonmail.com
*/5 * * * * cd $HOME/Documents && /usr/bin/git add -A && /usr/bin/git commit -m "Automatic check-in" >/dev/null 2>&1
*/30 * * * * cd $HOME/Documents && /usr/bin/git push --mirror > $HOME/logs/codecommit-push.log 2>&1
```
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
