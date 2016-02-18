#!/bin/bash

# Setup the obvious
ffprobe="/usr/local/bin/ffprobe"
ffmpeg="/usr/local/bin/ffmpeg"
LogFile="/tmp/sab.log"
RC="-1"
EmailTo="pcrosthwaite@gmail.com"

function WriteLog {
 # This is what will record our brave deeds into the history books

  # If we only have a message to record, then set our prophet accordingly
  case $# in
    1)
      if [ ${#1} -gt 0 ]
      then
        IN="$1"
      fi

    ;;

    2)
      if [ ${#2} -gt 0 ]
      then
        IN="$2"
      fi
    ;;

    *)

      IN="Too many arguments to WriteLog - $#"
    ;;
  esac

# As long as we have the information passed to us, then ensure our message is heard on all required mediums
if [ ${#IN} -ne 0 ]; then
  DateTime=`date "+%d/%m/%Y %H:%M:%S"`
  echo $DateTime' : '$IN >> "$LogFile"

  if [ "$1" != "-noscreen" ]
  then
    echo $DateTime' : '$IN
  fi
fi

IN=""
}

function StartConversion {
 # This vehicle will cast its steely eye over the flock and do what must be done
 # to bring them back to th elight
  f="$1"
  WriteLog "Processing File $f"

  ##  Detect what audio codec is being used:
  audio=$($ffprobe "$f" 2>&1 | sed -n '/Audio:/s/.*: \([a-zA-Z0-9]*\).*/\1/p' | sed 1q)
  aopts="-c:a ac3 -b:a 640k"

  ##  Set default video settings:
  vopts="-c:v copy"
  #vopts="-c:v libx264 -profile:v high -level 4.0"

  ##  Set default subtitle settings:
  sopts="-c:s copy"

  WriteLog "Audio detected is $audio"

  case "$audio" in
        aac|alac|mp3|mp2|ac3 )

            ##  If the audio is one of the MP4-supported codecs
            WriteLog "No Audio Processing Needed."
            mv "$f" "$f-1"
            fname="$CleanNZBName" #`basename "$f" .mkv`
            WriteLog "Executing $ffmpeg -i '$f-1' -vcodec copy -acodec copy '$OutputDir/$fname.mp4'"
            Process="Renamed to MP4"
            $ffmpeg -i "$f-1" -vcodec copy -acodec copy "$OutputDir/$fname.mp4"
            RC=$?
            CheckRC $RC $f
        ;;

        "" )
          ##  If there is no detected audio stream, don't bother
          WriteLog "Can't Determine Audio, Skipping $f"
          Process="Skipped"
        ;;

        * )

          ##  anything else, convert
          mv "$f" "$f-1"
          fname="$CleanNZBName" #`basename "$f" .mkv`
          WriteLog "Audio Processing Required"
          WriteLog "Executing $ffmpeg -y -i '$f-1' -map 0 $sopts $vopts $aopts '$OutputDir/$fname.mp4'"
          Process="Converted"
          $ffmpeg -hwaccel auto -nostdin -y -i "$f-1" -map 0 $sopts $vopts $aopts "$OutputDir/$fname.mp4" 2>&1
          RC=$?
          CheckRC $RC $f
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
case "$Mode" in

  "CleanUp")
   fileArray=($(find "$DIR" -type f \( -name "*.db" -or -name "*.nfo" -or -name "*sample*.mkv" -or -name "*Sample*.mkv" -or -name "*SAMPLE*.mkv" \)))

  ;;

  "ProcessMKV")
    fileArray=($(find "$DIR" -name "*.mkv" -type f))
  ;;

  *)
    WriteLog "Invalid Mode passed to ReadFiles - $Mode"

  ;;

esac

# restore it to the old ways
IFS=$OLDIFS

# get number in  the flock
tLen=${#fileArray[@]}

# Inspect the flock and conduct what is needed to be done
for (( i=0; i<${tLen}; i++ ));
do
  f="${fileArray[$i]}"

  case "$Mode" in
    "CleanUp")
      WriteLog "Deleteing $f"
      result="$(rm ""$f"" 2>&1)"
      Ret=$?
      WriteLog -noscreen "rm completed with [$result] : RC ($Ret)"
    ;;

    "ProcessMKV")
      StartConversion "$f"
    ;;

    *)
     WriteLog "Not processing any file changes due to invalid mode"
    ;;
  esac
done

}

function SendNotification {
 # Notify the world that we have completed our tasks
  WriteLog "Sending email to $EmailTo"
  EmailMsgFile="`dirname $0`/EmailMsg"

  rm -rf $EmailMsgFile

  # Insert a message header
  echo "convert.sh has finished $Process - $CleanNZBName, Result = $ProcessingResult" >> $EmailMsgFile
  echo "Other Processing Messages :" >> $EmailMsgFile

  if [ $FlagUnknownCategory -eq 1 ]; then
     echo "File processing into Plex has failed as we were unable to determine the NZB category. The file is located in $OutputDir" >> $EmailMsgFile
  fi

  #mutt -a $LogFile -s "$CleanNZBName $Process RC=$RC" -- $EmailTo < $EmailMsgFile
  mpack -s "$CleanNZBName $Process RC=$RC" -d "$EmailMsgFile" $LogFile $EmailTo
}

function CheckRC {
 # This vehicle will confirm our success or failure, and act appropriately

  case "$1" in
       "0" )
          ##  put new file in place
          WriteLog "Conversion = SUCCESS"
          ProcessingResult="Success"
          #rm -rf "$f"-1
          #chmod 666 "$2"
       ;;

       * )
          WriteLog "Conversion = FAIL - $1"
          ProcessingResult="Failed - $1"
          ##  revert back
          rm -rf "$2"
          mv "$2"-1 "$2"
       ;;
  esac
}

# Transform the passed messages into something believable
FinalDir="$1"
OrigNameNZB="$2"
CleanNZBName="$3"
IndexersReportNbr="$4"
Category="$5"
Group="$6"
PostProcessStatus="$7"
FailURL="$8"

# Ensure our path is clear to record future events
if [ $CleanNZBName = "" ]; then
  mv $LogFile `dirname $0`/Logs/$LogFile-`date +"%d%m%y-%H%M%S"`
else
  mv $LogFile `dirname $0`/Logs/$LogFile-$CleanNZBName
fi

touch $LogFile
chmod 666 $LogFile

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
case "$Category" in

   "tv" | "TV")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/TV"

   ;;

   "movie" | "MOVIE" | "movies" | "MOVIES")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/Movies"
   ;;

   *)
    # Someone is trying to lead us down the category path, so log the lies
    # and output to our home.
    WriteLog "Unknown Category [$Category]"
    Category="Unknown"
    FlagUnknownCategory=1

    OutputDir="`dirname $0`"

esac

# Record the present
WriteLog -noscreen "------------------------"
WriteLog -noscreen "FinalDir........... $FinalDir"
WriteLog -noscreen "OrigNameNZB........ $OrigNameNZB"
WriteLog -noscreen "CleanNZBName....... $CleanNZBName"
WriteLog -noscreen "IndexersReportNbr.. $IndexersReportNbr"
WriteLog -noscreen "Category........... $Category"
WriteLog -noscreen "Group.............. $Group"
WriteLog -noscreen "PostProcessStatus.. $PostProcessStatus"
WriteLog -noscreen "FailURL............ $FailURL"
WriteLog -noscreen "OutputDir.......... $OutputDir"
WriteLog -noscreen "------------------------"

# Check that our destination exists and is not a black hole
if [ -d "$FinalDir" ]
then
  ##  cleanup by deleting unwanted files
  WriteLog -noscreen "Begin File Cleanup"

  ReadFiles "$FinalDir" "CleanUp"

  WriteLog -noscreen "End File Cleanup"

  # Begin changing the world
  ReadFiles "$FinalDir" "ProcessMKV"

else
  WriteLog "$FinalDir doesn't exist bitches"
fi

# Make sure that information is free for all who seek it
chmod 666 $LogFile

# Send out the notications on what we saw here today
SendNotification

# Write to the log and to the screen so SABNzbd displays this message in the history.
WriteLog "Processing $ProcessingResult"
exit 0

