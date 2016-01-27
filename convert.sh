#!/bin/bash

ffprobe="/usr/local/bin/ffprobe"
ffmpeg="/usr/local/bin/ffmpeg"
LogFile="/tmp/sab.log"
RC="-1"
EmailTo="pcrosthwaite@gmail.com"

function WriteLog {
echo "i am $# - $1 - ${#1}"

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

echo "size is ${#IN}"
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
            $ffmpeg -i "$f-1" -vcodec copy -acodec copy "$OutputDir/$fname.mp4"
            RC=$?
            CheckRC $RC $f
        ;;

        "" )
          ##  If there is no detected audio stream, don't bother
          WriteLog "Can't Determine Audio, Skipping $f"
        ;;

        * )

          ##  anything else, convert
          mv "$f" "$f-1"
          fname="$CleanNZBName" #`basename "$f" .mkv`
          WriteLog "Audio Processing Required"
          WriteLog "Executing $ffmpeg -y -i '$f-1' -map 0 $sopts $vopts $aopts '$OutputDir/$fname.mp4'"
          $ffmpeg -hwaccel auto -nostdin -y -i "$f-1" -map 0 $sopts $vopts $aopts "$OutputDir/$fname.mp4" 2>&1
          RC=$?
          CheckRC $RC $f
        ;;

  esac
}

function ReadFiles {

#  go over all MKVs
DIR="$1"

Mode="$2"

# failsafe - fall back to current directory
#[ "$DIR" == "" ] && DIR="."

# save and change IFS
OLDIFS=$IFS
IFS=$'\n'

# read all file name into an array

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

# restore it
IFS=$OLDIFS

# get length of an array
tLen=${#fileArray[@]}
echo "len is $tLen"

# use for loop read all filenames
for (( i=0; i<${tLen}; i++ ));
do
  f="${fileArray[$i]}"
  echo "i is $i"

  case "$Mode" in
    "CleanUp")
      #f="/tmp/test/gsdfsdfsd"
      WriteLog "Deleteing $f"
      result="$(rm ""$f"" 2>&1)"
      Ret=$?
      WriteLog -noscreen "rm completed with [$result] : RC ($Ret)"
    ;;

    "ProcessMKV")
      StartConversion "$f"
    ;;

    *)
     WriteLog "Not processing any file changes dur to invalid mode"
    ;;
  esac
done

}

function SendNotification {
  WriteLog "Sending email to $EmailTo"
#  echo "convert.sh has finished" | mutt -a $LogFile -s "File Converted RC=$RC" -- $EmailTo
}

function CheckRC {
  case "$1" in
       "0" )
          ##  put new file in place
          WriteLog "Conversion = SUCCESS"
          #rm -rf "$f"-1
          chmod 666 "$2"
       ;;

       * )
          WriteLog "Conversion = FAIL - $1"
                 ##  revert back
          rm -rf "$2"
          mv "$2"-1 "$2"
       ;;
  esac
}

rm -rf $LogFile
touch $LogFile
chmod 666 $LogFile

echo "------------------------" >> $LogFile
echo "1.... $1" >> $LogFile
echo "2.... $2" >> $LogFile
echo "3.... $3" >> $LogFile
echo "4.... $4" >> $LogFile
echo "5.... $5" >> $LogFile
echo "6.... $6" >> $LogFile
echo "7.... $7" >> $LogFile
echo "8.... $8" >> $LogFile
echo "------------------------" >> $LogFile

FinalDir="$1"
OrigNameNZB="$2"
CleanNZBName="$3"
IndexersReportNbr="$4"
Category="$5"
Group="$6"
PostProcessStatus="$7"
FailURL="$8"

case "$Category" in

   "tv" | "TV")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/TV"

   ;;

   "movie" | "MOVIE" | "movies" | "MOVIES")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/Movies"
   ;;

   *)
    WriteLog "Unknown Category [$Category]"
    OutputDir="`dirname $0`"

esac

echo "------------------------" >> $LogFile
echo "FinalDir........... $FinalDir" >> $LogFile 
echo "OrigNameNZB........ $OrigNameNZB" >> $LogFile
echo "CleanNZBName....... $CleanNZBName" >> $LogFile
echo "IndexersReportNbr.. $IndexersReportNbr" >> $LogFile
echo "Category........... $Category" >> $LogFile
echo "Group.............. $Group" >> $LogFile
echo "PostProcessStatus.. $PostProcessStatus" >> $LogFile
echo "FailURL............ $FailURL" >> $LogFile
echo "OutputDir.......... $OutputDir" >> $LogFile
echo "------------------------" >> $LogFile

if [ -d "$FinalDir" ]
then
  ##  cleanup by deleting unwanted files
  WriteLog -noscreen "Begin File Cleanup"

  ReadFiles "$FinalDir" "CleanUp"

  WriteLog -noscreen "End File Cleanup"

  ReadFiles "$FinalDir" "ProcessMKV"

else
  WriteLog "$FinalDir doesn't exist bitches"
fi

WriteLog "Done."
chmod 666 $LogFile
SendNotification

exit 0

