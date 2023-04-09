# rclone-backup for Windows

Basic script that uses **rclone** to backup important files to the cloud.

## Requirements

- [rclone](https://rclone.org/) available in `PATH`
- [shadowrun](https://github.com/albertony/vss/tree/master/shadowrun) (to transfer locked files by using VSS)

## Usage

Execute it like this: `C:\Users\%USERNAME%\.backup\rclone-backup.bat C:\Users\%USERNAME%\.backup\config.conf`, specifying `sync-wait` as second parameter makes the script wait for user confirmation before continuing.  
Example `config.conf`, `filter.txt` files are provided in the repository.  
You should fiddle with the filter to exclude trash files, especially from AppData.  
Use Rclone's [crypt storage backend](https://rclone.org/crypt/) for security.  
