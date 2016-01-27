#!/bin/sh

ffprobe="/usr/local/bin/ffprobe"
ffmpeg="/usr/local/bin/ffmpeg"

FinalDir="$1"
OrigNameNZB="$2"
CleanNZBName="$3"
IndexersReportNbr="$4"
Category="$5"
Group="$6"
PostProcessStatus="$7"
FailURL="$8"
LogFile="/tmp/sab.log"

case "$Category" in

   "tv" | "TV")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/TV"

   ;;

   "movie" | "MOVIE" | "movies" | "MOVIES")

       OutputDir="/mnt/rdisk/Downloads/Watch/Rename/Movies"
   ;;

   *)
    echo "Unknown Category [$Category]" >> $LogFile
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

##  cleanup by deleting unwanted files
find "$FinalDir" -name "*.txt" -type f -print0 | xargs -0 rm -rf
find "$FinalDir" -name "*.db" -type f -print0 | xargs -0 rm -rf
find "$FinalDir" -name "*.nfo" -type f -print0 | xargs -0 rm -rf
find "$FinalDir" -name "*sample*.mkv" -type f -print0 | xargs -0 rm -rf
find "$FinalDir" -name "*Sample*.mkv" -type f -print0 | xargs -0 rm -rf
find "$FinalDir" -name "*SAMPLE*.mkv" -type f -print0 | xargs -0 rm -rf

##  go over all MKVs
find "$FinalDir" -name "*.mkv" -type f | while read f
do
echo "Processing File $f" >> $LogFile

##  Detect what audio codec is being used:
audio=$($ffprobe "$f" 2>&1 | sed -n '/Audio:/s/.*: \([a-zA-Z0-9]*\).*/\1/p' | sed 1q)
aopts="-c:a ac3 -b:a 640k"

##  Set default video settings:
vopts="-c:v copy"
#vopts="-c:v libx264 -profile:v high -level 4.0"

##  Set default subtitle settings:
sopts="-c:s copy"

echo "Audio detected is $audio" >> $LogFile

    case "$audio" in
        aac|alac|mp3|mp2|ac3 )
        
          ##  If the audio is one of the MP4-supported codecs
	  echo "No Audio Processing Needed." >> $LogFile
          mv "$f" "$f-1"
          fname="$CleanNZBName" #`basename "$f" .mkv`
          echo "Executing $ffmpeg -i '$f-1' -vcodec copy -acodec copy '$OutputDir/$fname.mp4'" >> $LogFile
          $ffmpeg -i "$f-1" -vcodec copy -acodec copy "$OutputDir/$fname.mp4"
        ;;
        
        "" )
          ##  If there is no detected audio stream, don't bother
          echo "Can't Determine Audio, Skipping $f" >> $LogFile
        ;;
        
        * )

          ##  anything else, convert
	  mv "$f" "$f-1"
          fname="$CleanNZBName" #`basename "$f" .mkv`
          echo "Audio Processing Required" >> $LogFile
          echo "Executing $ffmpeg -y -i '$f-1' -map 0 $sopts $vopts $aopts '$OutputDir/$fname.mp4'" >> $LogFile
          $ffmpeg -hwaccel auto -nostdin -y -i "$f-1" -map 0 $sopts $vopts $aopts "$OutputDir/$fname.mp4" 2>&1
          fail=$?

          case "$fail" in
               "0" )
                  ##  put new file in place
	  	  echo "Conversion = SUCCESS" >> $LogFile
                  #rm -rf "$f"-1
		  chmod 666 "$f"
               ;;
	
               * )
                 echo "Conversion = FAIL - $fail" >> $LogFile
                 ##  revert back
                 rm -rf "$f"
                 mv "$f"-1 "$f"
               ;;
	  esac
        ;;
    esac
done

echo "Done." >> $LogFile
chmod 666 $LogFile
cat $LogFile
exit 0
