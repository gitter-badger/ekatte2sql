#!/bin/bash

URL="http://www.nsi.bg/sites/default/files/files/EKATTE/Ekatte.zip"
INPUT_FILE="schema.json"
DIR_NAME="dir"$(date +%s)

while [[ $# > 1 ]]
do
key="$1"
shift

case $key in
    -i|--input-file)
    INPUT_FILE="$1"
    shift
    ;;
    --url)
    URL="$1"
    shift
    ;;
    -d|--dir-name)
    DIR_NAME="$1"
    shift
    ;;
    -u|--db-user)
    DB_USER="$1"
    shift
    ;;
    -p|--db-pass)
    DB_PASS="$1"
    shift
    ;;
    --db-host)
    DB_HOST="$1"
    shift
    ;;
    --db-driver)
    DB_DRIVER="$1"
    shift
    ;;
    -n|--db-name)
    DB_NAME="$1"
    shift
    ;;
    *)
            # unknown option
    ;;
esac
done


echo "Creating directory:" $DIR_NAME;
mkdir $DIR_NAME;

# Enter working dir
echo "Entering directory:" $DIR_NAME;
cd $DIR_NAME;


# Download archive
echo "Downloading ekatte from:" URL
wget $URL


# Unzip
echo "Unzipping archive"
unzip  Ekatte.zip -d . 


# Unzip xls files
echo "Unzipping xls"
mkdir xls
unzip Ekatte_xls.zip -d xls 


# Convert to csv
echo "Loop trough xls files"
for i in xls/*.xls; do
    unoconv -v -f csv $i
done


PLSCRIPT_ARGS="--input-file ../$INPUT_FILE --input-dir xls/ --db-user $DB_USER --db-pass $DB_PASS"

if [[ "$DB_NAME" ]]
then
   PLSCRIPT_ARGS="$PLSCRIPT_ARGS --db-name $DB_NAME"
fi 

if [[ $DB_DRIVER ]]
then 
    PLSCRIPT_ARGS="$PLSCRIPT_ARGS --db-driver $DB_DRIVER"
fi

if [[ $DB_HOST ]]
then 
    PLSCRIPT_ARGS="$PLSCRIPT_ARGS --db-host $DB_HOST"
fi


# Running command
echo "Running \"$(which perl) ../spreadsheet2sql.pl $PLSCRIPT_ARGS\""
$(which perl) ../spreadsheet2sql.pl $PLSCRIPT_ARGS

 
   
