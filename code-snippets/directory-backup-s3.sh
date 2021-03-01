#! /bin/sh
# Directory Backup to AWS S3

echo "Starting Directory Backup..."

# Ensure all required environment variables are present
if [ -z "$GPG_KEY" ] || \
    [ -z "$GPG_KEY_ID" ] || \
    [ -z "$DIR_PATH" ] || \
    [ -z "$BACKUP_NAME" ] || \
    [ -z "$AWS_ACCESS_KEY_ID" ] || \
    [ -z "$AWS_SECRET_ACCESS_KEY" ] || \
    [ -z "$AWS_DEFAULT_REGION" ] || \
    [ -z "$S3_BUCKET" ]; then
    >&2 echo 'Required variable unset, backup failed'
    exit 1
fi

# Make sure required binaries are in path (YMMV)
export PATH=/snap/bin:/usr/local/bin:$PATH

# Import gpg public key from env
echo "$GPG_KEY" | gpg --batch --import

# Create backup params
backup_dir="$(mktemp -d)"
backup_file_name="$BACKUP_NAME--$(date +%d'-'%m'-'%Y'--'%H'-'%M'-'%S).tar.bz2.gpg"
backup_path="$backup_dir/$backup_file_name"

# Create, compress, and encrypt the backup
cp -R "$DIR_PATH" "$backup_dir/$BACKUP_NAME"
tar -cf - -C "$backup_dir" "./$BACKUP_NAME" | bzip2 | gpg --batch --recipient "$GPG_KEY_ID" --trust-model always --encrypt --output "$backup_path"

# Check backup created
if [ ! -e "$backup_path" ]; then
    echo 'Backup file not found'
    exit 1
fi

# Push backup to S3
aws s3 cp "$backup_path" "s3://$S3_BUCKET"
status=$?

# Remove tmp backup path
rm -rf "$backup_dir"

# Indicate if backup was successful
if [ $status -eq 0 ]; then
    echo "$BACKUP_NAME backup completed to '$S3_BUCKET'"

    # Remove expired backups from S3
    if [ "$ROTATION_PERIOD" != "" ]; then
        aws s3 ls "$S3_BUCKET" --recursive | while read -r line;  do
            stringdate=$(echo "$line" | awk '{print $1" "$2}')
            filedate=$(date -d"$stringdate" +%s)
            olderthan=$(date -d"-$ROTATION_PERIOD days" +%s)
            if [ "$filedate" -lt "$olderthan" ]; then
                filetoremove=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//')
                if [ "$filetoremove" != "" ]; then
                    aws s3 rm "s3://$S3_BUCKET/$filetoremove"
                fi
            fi
        done
    fi
else
    echo "$BACKUP_NAME backup failed"
    exit 1
fi