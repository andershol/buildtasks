perl tasks-txt-csv.pl -i tasks.txt -o tasks.csv
perl tasks-csv-html.pl -i tasks.csv -o tasks.html -c 0.12

python fetch.py -o tasks2.csv
perl tasks-csv-html.pl -i tasks2.csv -o tasks2.html -c 0.12
