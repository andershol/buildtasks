buildtasks
==========

To create a table of times and costs from the text file tasks.txt, using the default cost of $0.12/hour:
```sh
perl tasks-txt-csv.pl -i tasks.txt -o tasks.csv
perl tasks-csv-html.pl -i tasks.csv -o tasks.html -c 0.12
````

To scrape ftp.mozilla.org for buildlogs and get more information in the tooltips and better mapping of jobs to hardware:
```sh
python fetch.py -o tasks2.csv
perl tasks-csv-html.pl -i tasks2.csv -o tasks2.html -c 0.12
```

To extract data from a json file (optionally gzipped) from http://builddata.pub.build.mozilla.org/buildjson/ use:
```sh
python buildlog.py -i builds-4hr.js.gz -o tasks.csv
perl tasks-csv-html.pl -i tasks2.csv -o tasks2.html -c 0.12
```
