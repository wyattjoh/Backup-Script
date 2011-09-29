readme.txt: Backup-Script 
 
Background

Wyatt Johnson 2011

Usage: backup.sh [Location] [Name] [Days Old]

Location:	Location of the local backup source
Name:		Name of the backup source (basename location default)
Days Old:	Amount of days before old backups are deleted (10 default)

Description:
The function of the backup script is to create a local archive store of designated files within a bz2 archive, complete with restore scripts and file listings. The script has many options which are mostly hardcoded, allowing for ease of use when it comes to adding the job as a cron.

Future Plans:
- Add automatic back up to networked resources
