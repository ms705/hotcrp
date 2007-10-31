#! /bin/sh
## createdb.sh -- HotCRP database setup program
## HotCRP is Copyright (c) 2006-2007 Eddie Kohler and Regents of the UC
## Distributed under an MIT-like license; see LICENSE

## Create the database. The assumption is that database
## name and user name and password are all the same

export PROG=$0
export FLAGS=""
while [ $# -gt 0 ]; do
    case "$1" in
    -*)	FLAGS="$FLAGS $1";;
    *)	echo "Usage: $PROG [MYSQL-OPTIONS]" 1>&2; exit 1;;
    esac
    shift
done

PROGDIR=`echo "$0" | sed 's,[^/]*$,,'`


echo "This will create the database for your conference."
echo "The database name and database user are set to the same thing."
echo "Access is allowed only from the local host."
echo

echo -n "Enter database name (NO SPACES): "
read DBNAME

if echo -n "$DBNAME" | grep '[^-.a-zA-Z0-9_]' >/dev/null; then
    echo "Database name contains special characters!  Only [-.a-zA-Z0-9_], please." 1>&2
    exit 1
fi

echo -n "Enter password for mysql user $DBNAME [default $DBNAME]: "
read -r DBPASS
if [ -z "$DBPASS" ]; then DBPASS="$DBNAME"; fi

sedquoter () {
    sed -e 's,\\,\\\\,g' | sed -e 's,\([ \n'"'"'"]\),\\\1,g'
}

DBPASS_SQL=`echo -n "$DBPASS" | sedquoter`
DBPASS_DBLQUOTE=`echo -n "$DBPASS_SQL" | sedquoter`
echo "$DBPASS : $DBPASS_SQL"

echo
echo "Creating database."
if [ -z "$FLAGS" ]; then
    echo "This should work if you are root and haven't changed the default mysql"
    echo "administrative password.  If you have changed the password, you will need to"
    echo "run '$PROG -p' or '$PROG -pPASSWD' (no space)."
fi
echo "+ echo 'show databases;' | mysql | grep $DBNAME"
echo 'show databases;' | mysql $FLAGS | grep $DBNAME >/dev/null 2>&1
dbexists="$?"
echo "+ echo 'select User from user group by User;' | mysql mysql | grep $DBNAME"
echo 'select User from user group by User;' | mysql $FLAGS mysql | grep '^'$DBNAME'$' >/dev/null 2>&1
userexists="$?"
if [ $dbexists = 0 -o $userexists = 0 ]; then
    echo
    test $dbexists = 0 && echo "A database named '$DBNAME' already exists!"
    test $userexists = 0 && echo "A user named '$DBNAME' already exists!"
    echo "Hit Enter to delete and recreate, Control-C to cancel." 
    read foo

    echo "+ mysqladmin $FLAGS -f drop $DBNAME"
    mysqladmin $FLAGS -f drop $DBNAME
fi
echo "+ mysqladmin $FLAGS --default-character-set=utf8 create $DBNAME"
mysqladmin $FLAGS --default-character-set=utf8 create $DBNAME || exit 1

echo
echo "Creating $DBNAME user and password."
mysql $FLAGS mysql <<__EOF__ || exit 1
DELETE FROM user WHERE user='$DBNAME';
INSERT INTO user SET
    Host='127.0.0.1',
    User='$DBNAME',
    Password=PASSWORD('$DBPASS_SQL'),
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

INSERT INTO user SET
    Host='localhost.localdomain',
    User='$DBNAME',
    Password=PASSWORD('$DBPASS_SQL'),
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

INSERT INTO user SET
    Host='localhost',
    User='$DBNAME',
    Password=PASSWORD('$DBPASS_SQL'),
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

DELETE FROM db WHERE db='$DBNAME';
INSERT INTO db SET
    Host='127.0.0.1',
    Db='$DBNAME',
    User='$DBNAME',
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    References_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

INSERT INTO db SET
    Host='localhost.localdomain',
    Db='$DBNAME',
    User='$DBNAME',
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    References_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

INSERT INTO db SET
    Host='localhost',
    Db='$DBNAME',
    User='$DBNAME',
    Select_priv='Y',
    Insert_priv='Y',
    Update_priv='Y',
    Delete_priv='Y',
    Create_priv='Y',
    Drop_priv='Y',
    Index_priv='Y',
    References_priv='Y',
    Alter_priv='Y',
    Lock_tables_priv='Y',
    Create_tmp_table_priv='Y';

__EOF__
##

echo
echo "Reloading grant tables."
mysqladmin $FLAGS reload || exit 1

if [ ! -r "${PROGDIR}schema.sql" ]; then
    echo "Can't read schema.sql!  You'll have to populate the database yourself."
    exit
fi

##
## Populate the database schema
##
echo
echo "Now, we will populate the database with the schema."
echo "If the preceeding steps worked, you won't need to enter a password."

echo "Hit <RETURN> to populate the database, Control-C to cancel."
echo "(If you need to restore from a backup you don't want to populate.)"
read foo

echo mysql -u $DBNAME -p"$DBPASS" $DBNAME "<" ${PROGDIR}schema.sql
mysql -u "$DBNAME" -p"$DBPASS" "$DBNAME" < ${PROGDIR}schema.sql || exit 1

##
## Create options.inc
##

if [ -r "${PROGDIR}options.inc" ]; then
    echo "Your Code/options.inc file already exists."
    echo "Edit it to correspond to the database name, username, and password you chose."
elif [ -r "${PROGDIR}distoptions.inc" ]; then
    echo "Creating Code/options.inc..."
    awk '/^\$Opt\[.dbName.\]/ { print "$Opt[\"dbName\"] = \"'"$DBNAME"'\";" 
	print "$Opt[\"dbPassword\"] = \"'"$DBPASS_DBLQUOTE"'\";"
	next }
{ print }' < ${PROGDIR}distoptions.inc > ${PROGDIR}options.inc
    if [ -n "$SUDO_USER" ]; then
	echo chown $SUDO_USER ${PROGDIR}options.inc
	chown $SUDO_USER ${PROGDIR}options.inc
    fi
fi
