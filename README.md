# ekatte2sql

ekatte2sql е срипт, който превръща информацията на Национален статистически институт (НСИ) от xls файлове в sql база данни. 

### Описание
Всъщност скриптовете са два:
- **ekatte2sql.sh** - shell скрипт изтегляне и подготвяне на данните за конвертиране;
- **spreadsheet2sql** - perl скрипт за същинското преобразуване на данните и вкарването им в postgresql база данни;


### Изисквания
Скриптовете имат няколко дипендънсита (отбелязаните версии са тестваните, може да работи и с по-стари, както и да не работи с по-нови):
- postgresql 9.3
- perl 5.12
- libreoffice 4.2
- unoconv 0.6 - cli инструмент за превръщане на xls в csv
- libspreadsheet-read-perl

За Debian базирани операционни системи (Ubuntu/Linux mint):

    $ sudo apt-get install libspreadsheet-read-perl libreoffice unoconv postgresql git

### Употреба

**tldr:** Импортнете схемата от `db/*` в предварително създадена от вас база:

    psql=# \i db/**
    
След което просто пуснете скрипта:

    ./execute.sh -u $DB_USER -p $DB_PASSWORD -n $DB_NAME


##### Употреба for dummies

1. Предварително сме инсталирали всички дипендънсита от по-горе;
2. Създаваме директория в хоума на вашия юзър;
3. Клонираме скрипта на локалната машина;
4. Влизаме в директорията;
5. Разрешаваме на скрипта да бъде изпълним;
6. Настройваме си базата данни - импорт на `./db/*', даване на права на таблиците и сикуънсите (и ако е необходимо създаване на юзър);
7. Изпълняваме скрипта и чакаме да завърши;
8. Готови сме!


```sh
$ mkdir ~/project-ekatte
$ git clone https://github.com/suricactus/ekatte2psql
$ cd ekatte2psql
$ chmod +x execute.sh
$ # sql database magic here!
$ ./execute.sh -u $DB_USERNAME -p $DB_PASSWORD 
$ echo "Such script, very wow"
```

## Документация
И двата скрипта поддържат набор от CLI аргументи:
##### ekatte2sql.sh
- `--db-driver` **psql** - каква база се поддържа, тествано е единствено с postgresql;
- `--db-host` **localhost** - хост на базата
- `-n --db-name` **ekatte** - име на базата;
- `-u --db-user` - юзър на базата;
- `-p --db-pass` - парола на юзъра на базата;
- `-i --input-file` **schema.json** - файл, в който е описана връзката между електронната таблица и таблицата в базата данни;
- `--url` - url, откъдето да се изтегли архива с ekatte;

##### spreadsheet2sql.pl
- `--db-driver` **psql** - каква база се поддържа, тествано е единствено с postgresql;
- `--db-host` **localhost** - хост на базата
- `--db-name` **ekatte** - име на базата;
- `--db-user` - юзър на базата;
- `--db-pass` - парола на юзъра на базата;
- `--input-dir` - директория, в която да се търсят електронните таблици (spreadsheets);
- `--input-file` - файл, в който е описана връзката между електронната таблица и таблицата в базата данни;


### TODOs
- Трябва да се документира формата на schema файла;


### Лиценз
Само не го затваряйте. И да, отворете си настоящия код :)
GPL 2.0
