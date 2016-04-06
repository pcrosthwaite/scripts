#!/bin/bash

# Setup the obvious
ffprobe="/usr/local/bin/ffprobe"
ffmpeg="/usr/local/bin/ffmpeg"
BaseLogFile="/tmp/sab.log"
RC="-1"
NotificationsEnabled="true"
EmailTo="pcrosthwaite@gmail.com"

# VerboseMode
# 1 = Log Everything. Display to screen everything
# 2 = Basic Logging, Display to screen as designed
VerboseMode=2

# This controls what messages are logged when the VerboseMode is only doing Basic Logging
# and should be set to the same value as Log Everything
AlwaysLog=1

function WriteLog {
 # This is what will record our brave deeds into the history books
  ScreenMode=""
  _VerboseMode=$VerboseMode

  # If we only have a message to record, then set our prophet accordingly
  case $# in
    1)
      if [ ${#1} -gt 0 ]; then
        ScreenMode=""
        IN="$1"
      fi
    ;;

    2)
      if [ ${#2} -gt 0 ]; then
        ScreenMode="$1"
        IN="$2"
      fi
    ;;

    3)
      if [ ${#3} -gt 0 ]; then
         ScreenMode="$1"
         IN="$2"
         _VerboseMode="$3"
      fi
    ;;

    *)
      IN="Too many arguments to WriteLog - $#"
    ;;
  
  esac

# As long as we have the information passed to us, then ensure our message is heard on all required mediums
if [ ${#IN} -ne 0 ]; then
  DateTime=`date "+%d/%m/%Y %H:%M:%S"`

  if [ $_VerboseMode -eq 1 ]; then
     echo $DateTime' : '$IN >> "$LogFile"
  fi

  if [ "$ScreenMode" != "-noscreen" ] || [ $_VerboseMode -eq 1 ]; then
    echo $DateTime' : '$IN
  fi
fi

IN=""
}

function LogCmd {
 # This vessel will execute the commandment and log the results to the bible
 Cmd="$1" 
 LogPrefix="$2"
 
 if [ ${#3} -gt 0 ]; then
    _VerboseMode=$3
 else
    _VerboseMode=$VerboseMode
 fi

 if [ $_VerboseMode -eq 1 ]; then
    WriteLog -noscreen "LogCmd is running $Cmd"
 fi

 Ret=`$Cmd 2>&1`
 RC=$?

 if [ $_VerboseMode -le 2 ]; then
    WriteLog -noscreen "$LogPrefix : Cmd Output : $Ret"
    WriteLog -noscreen "$LogPrefix : RC         : $RC"
 fi

}

function StartConversion {
 # This vehicle will cast its steely eye over the flock and do what must be done
 # to bring them back to th elight
  f="$1"
  WriteLog -screen "Processing File $f" $AlwaysLog

  ##  Detect what audio codec is being used:
  audio=$($ffprobe "$f" 2>&1 | sed -n '/Audio:/s/.*: \([a-zA-Z0-9]*\).*/\1/p' | sed 1q)
  aopts="-c:a ac3 -b:a 640k"

  ##  Set default video settings:
  vopts="-c:v copy"
  #vopts="-c:v libx264 -profile:v high -level 4.0"

  ##  Set default subtitle settings:
  sopts="-c:s copy"

  WriteLog -screen "Audio detected is $audio"

  case "$audio" in
        aac|alac|mp3|mp2|ac3 )

            ##  If the audio is one of the MP4-supported codecs
            WriteLog -screen "No Audio Processing Needed." $AlwaysLog 
            LogCmd "mv ""$f"" ""$f-1"" " "[StartConversion()]"
            fname="$CleanNZBName" #`basename "$f" .mkv`
            WriteLog -noscreen "Executing $ffmpeg -i '$f-1' -y -vcodec copy -acodec copy '$OutputDir/$fname.mp4'"
            Process="Renamed to MP4"
            LogCmd "$ffmpeg -i ""$f-1"" -y -vcodec copy -acodec copy ""$OutputDir/$fname.mp4""" "[StartConversion()]"
            RC=$?
            CheckRC $RC $f $ErrMsg

            # Remember that uTorrent will be expecting the original file, so return it to once it was.
            if [ "${Group,,}" = "utorrent" ]; then
               LogCmd "mv ""$f-1"" ""$f"" " "[StartConversion()]"
            fi
        ;;

        "" )
          ##  If there is no detected audio stream, don't bother
          WriteLog -screen "Can't Determine Audio, Skipping $f" $AlwaysLog 
          Process="Skipped"
        ;;

        * )

          ##  anything else, convert
          LogCmd "mv ""$f"" ""$f-1"" " "[StartConversion()]"
          fname="$CleanNZBName" #`basename "$f" .mkv`
          WriteLog -screen "Audio Processing Required" $AlwaysLog
          WriteLog -noscreen "Executing $ffmpeg -y -i '$f-1' -map 0 $sopts $vopts $aopts '$OutputDir/$fname.mp4'"
          Process="Converted"
          ErrMsg=`$ffmpeg -hwaccel auto -nostdin -y -i "$f-1" -map 0 $sopts $vopts $aopts "$OutputDir/$fname.mp4" 2>&1`
          RC=$?
          CheckRC $RC $f $ErrMsg

          # Remember that uTorrent will be expecting the original file, so return it to once it was.
          if [ "${Group,,}" = "utorrent" ]; then
             LogCmd "mv ""$f-1"" ""$f"" " "[StartConversion()]"
          fi

        ;;

  esac
}

function ReadFiles {
 # Conduct the clearing of the misguided, and ensure that the files are consistently good.

DIR="$1"

Mode="$2"

# save and change IFS
OLDIFS=$IFS
IFS=$'\n'

# read all file name into an array

# Based on our Mode, find the flock to inspect
case "${Mode,,}" in

  "cleanup")
    fileArray=($(find "$DIR" -type f \( -name "*.db" -or -name "*.nfo" -or -name "*sample*.mkv" -or -name "*Sample*.mkv" -or -name "*SAMPLE*.mkv" \)))
  ;;

  "processrar")
    fileArray=($(find "$DIR" -name "*.rar" -type f))
  ;;

  "processmkv")
    fileArray=($(find "$DIR" -name "*.mkv" -type f))
  ;;

  "processmp4")
    fileArray=($(find "$DIR" -name "*.mp4" -type f))
  ;;

  *)
    WriteLog -noscreen "Invalid Mode passed to ReadFiles - $Mode" $AlwaysLog
  ;;

esac

# restore it to the old ways
IFS=$OLDIFS

# get number in  the flock
tLen=${#fileArray[@]}

WriteLog "Found $tLen to process."

# Inspect the flock and conduct what is needed to be done
for (( i=0; i<${tLen}; i++ ));
do
  f="${fileArray[$i]}"
  ProcessFile="$(basename ""$f"")"
  FileExt="${ProcessFile##*.}"
  FileName="${ProcessFile%.*}"

  WriteLog -noscreen "[ReadFiles()] ProcessFile : $ProcessFile" 
  WriteLog -noscreen "[ReadFiles()] FileExt     : $FileExt"
  WriteLog -noscreen "[ReadFiles()] FileName    : $FileName"

  case "${Mode,,}" in
    "cleanup")
      WriteLog -noscreen "Deleteing $f"
      
      if [ "${Group,,}" != "utorrent" ]; then
        LogCmd "rm ""$f"" " "[ReadFiles()]"
      else
        WriteLog -noscreen "Skipping Cleanup for $Group"
      fi
    ;;

    "processrar")
      WriteLog -noscreen "Unrar $f" $AlwaysLog
      unrar e -idq -p- -y "$f" "$(dirname ""$f"")" 
      ProcessingResult=$?
    ;;
 
    "processmkv")
      StartConversion "$f"
    ;;

    "processmp4")
      WriteLog -noscreen "Copying $f to $OutputDir/$CleanNZBName.$FileExt" $AlwaysLog
      LogCmd "cp $f $OutputDir/$CleanNZBName.$FileExt" "[ReadFiles()]"
    ;;

    "software")
      WriteLog -noscreen "Nothing to do for $Mode" $AlwaysLog
    ;;

    *)
      WriteLog -noscreen "Not processing any file changes due to invalid mode" $AlwaysLog
    ;;
  esac
done

}

function SendNotification {
 # Notify the world that we have completed our tasks
  WriteLog -screen "Sending email to $EmailTo"
  EmailMsgFile="`dirname $0`/EmailMsg"

  LogCmd "rm -rf ""$EmailMsgFile""" "[SendNotification()]"

  # Insert a message header
  echo "convert.sh has finished $Process - $CleanNZBName, Result = $ProcessingResult" >> $EmailMsgFile
  echo "Other Processing Messages :" >> $EmailMsgFile

  if [ $FlagUnknownCategory -eq 1 ]; then
     echo "File processing into Plex has failed as we were unable to determine the NZB category. The file is located in $OutputDir" >> $EmailMsgFile
  fi

  if [ ${NotificationsEnabled,,} = "true" ]; then
     mpack -s "$CleanNZBName $Process RC=$RC" -d "$EmailMsgFile" $LogFile $EmailTo
  else
     WriteLog -screen "Notifications Disabled : mpack -s ""$CleanNZBName $Process RC=$RC"" -d ""$EmailMsgFile"" $LogFile $EmailTo"
     WriteLog -screen "Body : "
     WriteLog -screen "$(cat ""$EmailMsgFile"")"
  fi

}

function CheckRC {
 # This vehicle will confirm our success or failure, and act appropriately

  ProcessFile="$(basename ""$2"")"
  FileExt="${ProcessFile##*.}"
  FileName="${ProcessFile%.*}"

  WriteLog -noscreen "[CheckRC()] ProcessFile : $ProcessFile"
  WriteLog -noscreen "[CheckRC()] FileExt     : $FileExt"
  WriteLog -noscreen "[CheckRC()] FileName    : $FileName"

  case "$1" in
       "0" )
          ##  put new file in place
          WriteLog -noscreen "Conversion = SUCCESS" $AlwaysLog
          ProcessingResult="Success"
          #rm -rf "$f"-1
          #chmod 666 "$2"
       ;;

       * )
          WriteLog -noscreen "Conversion = FAIL - $1" $AlwaysLog
          WriteLog -noscreen "$3" $AlwaysLog
          WriteLog -noscreen "$ErrMsg" $AlwaysLog
          ProcessingResult="Failed - $1"
          ##  revert back
          WriteLog -noscreen "Removing failed output $OutputDir/$fname.mp4"
          LogCmd "rm -rf ""$OutputDir/$fname.mp4"" " "[CheckRC()]"
          LogCmd "rm -rf ""$2"" " "[CheckRC()]"
          
          LogCmd "mv ""$2""-1 ""$2"" " "[CheckRC()]"
          
          WriteLog -noscreen "Copying $2 to $OutputDir/$CleanNZBName.$FileExt"
          LogCmd "cp ""$2"" ""$OutputDir/$CleanNZBName.$FileExt"" " "[CheckRC()]"
       ;;
  esac
}

# If we have been poked, show them the path to enlightenment only
if [ $# -eq 0 ]; then
   echo "1. FinalDir"
   echo "2. OrigNameNZB"
   echo "3. NZBName"
   echo "4. IndexersReportNbr"
   echo "5. Category"
   echo "6. Group"
   echo "7. PostProcessStatus"
   echo "8. FailURL"

   exit 0
fi

# Transform the passed messages into something believable
FinalDir="$1"
CleanDir=`echo $FinalDir | sed -r 's/\(/\\(/g' | sed -r 's/\)/\\)/g'`
OrigNameNZB="$2"
NZBName="$3"
CleanNZBName=`echo $NZBName | sed -r 's/\(/\\(/g' | sed -r 's/\)/\\)/g'`
IndexersReportNbr="$4"
Category="$5"
Group="$6"
PostProcessStatus="$7"
FailURL="$8"

# Ensure our path is clear to record future events
rm -rf $LogFile

LogFileExt="${BaseLogFile##*.}"
LogFileName="${BaseLogFile%.*}"

if [ "$CleanNZBName" = "" ]; then
  LogFile="$LogFileName-`date +%d%m%y-%H%M%S`.$LogFileExt"
else
  LogFile="$LogFileName-$CleanNZBName.$LogFileExt"
fi

touch "$LogFile" 
WriteLog -noscreen "-------------------------" $AlwaysLog
WriteLog -noscreen "Begin Download Processing" $AlwaysLog
LogCmd "chmod 666 ""$LogFile""" "[Main()]"

# Initiate the uninitiated
ProcessingResult="-1"
Process="none"

# These flags determine if the script was able to process things correctly
# They are set during the various stages, and will determine what message is sent in the notification
# Values
# 0 = Off
# 1 = On
FlagUnknownCategory=0

# Locate paradise based on the category of our path
case "${Category,,}" in

   # We have to assume that if the category is uTorrent, it has come from SickRage
   # CouchPotato should be configured to send a label of Movies

   "tv" | "utorrent")
       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/TV"
   ;;

   "movie" | "movies")
       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/Movies"
   ;;

   "software")
       OutputDir="/mnt/rdisk/Downloads"
       Process="Extract Software"
   ;;
   
   *)
    # Someone is trying to lead us down the category path, so log the lies
    # and output to our home.
    WriteLog -noscreen "Unknown Category [$Category]" $AlwaysLog
    Category="Unknown"
    FlagUnknownCategory=1

    OutputDir="`dirname $0`"

esac

# Record the present
WriteLog -noscreen "------------------------" $AlwaysLog
WriteLog -noscreen "1.  FinalDir........... $CleanDir" $AlwaysLog
WriteLog -noscreen "2.  OrigNameNZB........ $OrigNameNZB" $AlwaysLog
WriteLog -noscreen "3.  NZBName............ $CleanNZBName" $AlwaysLog
WriteLog -noscreen "4.  IndexersReportNbr.. $IndexersReportNbr" $AlwaysLog
WriteLog -noscreen "5.  Category........... $Category" $AlwaysLog
WriteLog -noscreen "6.  Group.............. $Group" $AlwaysLog
WriteLog -noscreen "7.  PostProcessStatus.. $PostProcessStatus" $AlwaysLog
WriteLog -noscreen "8.  FailURL............ $FailURL" $AlwaysLog
WriteLog -noscreen "    OutputDir.......... $OutputDir" $AlwaysLog
WriteLog -noscreen "------------------------" $AlwaysLog

# Check that our destination exists and is not a black hole
if [ -d "$FinalDir" ]
then
  ##  cleanup by deleting unwanted files
  WriteLog -screen "Begin File Cleanup"
  ReadFiles "$FinalDir" "CleanUp"
  WriteLog -noscreen "End File Cleanup"

  WriteLog -screen "Begin UnRAR Files"
  ReadFiles "$FinalDir" "ProcessRAR"
  WriteLog -noscreen "End UnRAR Files"

  # Begin changing the world
  WriteLog -screen "Begin ProcessMKV"
  ReadFiles "$FinalDir" "ProcessMKV"
  WriteLog -noscreen "End ProcessMKV"

  WriteLog -screen "Begin ProcessMP4"
  ReadFiles "$FinalDir" "ProcessMP4"
  WriteLog -noscreen "End ProcessMP4"

else
  WriteLog -screen "$FinalDir doesn't exist bitches" $AlwaysLog
fi

# Make sure that information is free for all who seek it
LogCmd "chmod 666 ""$LogFile""" "[Main()]"

# Send out the notications on what we saw here today
SendNotification

WriteLog -noscreen "Executing mv $LogFile `dirname $0`/Logs/"
mv "$LogFile" "`dirname $0`/Logs/"

# Write to the log and to the screen so ihistory knows my great deeds.
echo "Processing $ProcessingResult"

exit 0

