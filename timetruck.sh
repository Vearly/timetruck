#!/bin/sh

logfile="/home/tsaalfeld/10_Arbeitszeiterfassung/locklogs/screenlocks"
timedir="/home/tsaalfeld/10_Arbeitszeiterfassung"

#Arbeitszeit Variablen
mittagspause=0 #sec

function usage
{
  echo "usage: timetruck.sh [[[-l] | [-lx]] [-p]]]"
  echo "-l   --listen             Horcht auf dbus nach org.gnome.ScreenSaver."
  echo "-lx  --listenx            Nutzt stattdessen xscreensaver-command -watch."
  echo "-p   --poke               Timetruck anstupsen (simulierter unlock & lock)."
  echo "-h   --help               Zeigt diese Hilfe an."
  echo ""
  echo "Beispiel für normale Nutzung:"
  echo "timetruck.sh -i -l &            #Initialisiert & Horcht nach gnome ScreenSaver"
  echo "timetruck.sh -p                 #Simuliert unlock mit anschließendem lock"
}

function unlockedScreen ()
{
  krzl=$1
  # Initial Login already occurred today?
  if [ $( head -1 $logfile | grep -o -P "(?<=\s)[0-9]{3,3}(?=\s)" ) -eq $(date +%j) ] ; then
      # Mittagspause Suchen
      brktime=$( cat $logfile | grep -E "[B]{1}" | grep -E -o "[0-9]{4,}")
      if [ -z "${brktime-}" ]; then
        # Mittagspausenerkennung in der Zeit von 11:00 bis 12:59
        if [ $(date +'%k') -ge 11 ] && [ $(date +'%k') -lt 13 ] ; then
          lunchlock=$( tail -1 $logfile | grep -o -E "[0-9]{4,}" )
          lunchlock=$(( $( date +'%s' ) - $lunchlock ))
          # Schwelle fuer Mittagspause ist 30 Minuten
          if [ $lunchlock -ge $(( 30 * 60 )) ] ; then
            mittagspause=$lunchlock
            dmin=$(( $mittagspause / 60 ))
            dhrs=$(( $dmin  / 60 ))
            dmin=$(( $dmin - $dhrs * 60))
            echo "B $(date +'%u %j') $(printf %02d $dhrs):$(printf %02d $dmin) $(printf %10d $mittagspause)" >> $logfile
          fi
        fi
      fi
    echo "$krzl $(date +'%u %j %H:%M %s')" >> $logfile
  else
    # Differenz zum letzten screenlock in h bestimmen
    locktime=`tail -2 $logfile | grep -E "[L]{1}" | grep -E -o "[0-9]{4,}"`
    delta=$(( ( $(date +%s) - $locktime ) / 60 / 60 ))
    # Falls >=6h her bestimme letzten Arbeitstag
    if [ $delta -ge 6 ]; then
      # Letzte Initialisierung
      ulcktime=`head -1 $logfile | grep -E "[I]{1}" | grep -E -o "[0-9]{4,}"`
      # Mittagspause Suchen & Berechnen
      brktime=$( cat $logfile | grep -E "[B]{1}" | grep -E -o "[0-9]{4,}")
      if [ -z "${brktime-}" ]; then
        mittagspause=0
      else
        mittagspause=$brktime
      fi
      bmin=$(( $mittagspause / 60 ))
      bhrs=$(( $bmin  / 60 ))
      bmin=$(( $bmin - $bhrs * 60))
      # Berechnung der Arbeitszeit in HH:MM:SS
      delta=$(( $locktime - $ulcktime - $mittagspause ))
      dmin=$(( $delta / 60 ))
      dhrs=$(( $dmin  / 60 ))
      dmin=$(( $dmin - $dhrs * 60))
      dsec=$(( $delta - $dmin * 60 - $dhrs * 60 * 60 ))
      ulckday=`date --date="@$ulcktime" +'%A, %d.%m.%y, %H:%M'`
      lockday=`date --date="@$locktime" +'%H:%M'`
      # Zeiterfassung in csv Datei speichern
      mname=$( date --date="@$locktime" +%Y-%B )
      timefile="$timedir/$mname.csv"
      # Falls Datei vorhanden anhängen ansonsten neu erstellen
      if [ -f "$timefile" ];then
        echo "$ulckday, $lockday, $dhrs:$(printf %02d $dmin), $bhrs:$(printf %02d $bmin)" >> $timefile
      else
        touch $timefile
        echo "Zeiterfassung für den $(date +'%B %Y') gestartet."
        echo "Wochentag, Datum, Eingestempelt, Ausgestempelt, Arbeitsstunden, Pause" > $timefile
        echo "$ulckday, $lockday, $dhrs:$(printf %02d $dmin), $bhrs:$(printf %02d $bmin)" >> $timefile
      fi
      # Backup und reset des logfile
      yesterday=$( date --date="@$ulcktime" +%y-%m-%d )
      cp -f $logfile "$logfile-$yesterday.txt"
      date +'I %u %j %H:%M %s' > $logfile
      # Reset der Mittagspause
      mittagspause=0
    else
      # Weiterhin selber Arbeitstag
      echo "$krzl $(date +'%u %j %H:%M %s')" >> $logfile
    fi
  fi
}

while [ "$1" != "" ]; do
    case $1 in
        -i  | --init )            initialize=1
                                  ;;
        -d  | --display )         displayinfo=1
                                  ;;
        -l  | --listen )          listen=1
                                  ;;
        -lx | --listenx )         listenx=1
                                  ;;
        -p  | --poke )            poke=1
                                  ;;
        --debug )                 debug=1
                                  ;;
        -h  | --help )            usage
                                  exit
                                  ;;
        * )                       usage
                                  exit 1
    esac
    shift
done

if [ "$poke" = "1" ]; then
  unlockedScreen "P"
fi

if [ "$debug" = "1" ]; then
  echo "No debug mode."
  usage
fi

if [ "$displayinfo" = "1" ]; then
      ulcktime=`head -10 $logfile | grep -E "[I]{1}" | grep -E -o "[0-9]{4,}"`
      # Mittagspause Suchen
      brktime=$( cat $logfile | grep -E "[B]{1}" | grep -E -o "[0-9]{4,}")
      if [ -z "${brktime-}" ]; then
        mittagspause=0
      else
        mittagspause=$brktime
      fi
      # Berechnung der Arbeitszeit in HH:MM:SS
      delta=$(( $( date +'%s' ) - $ulcktime - $mittagspause ))
      dmin=$(( $delta / 60 ))
      dhrs=$(( $dmin  / 60 ))
      dmin=$(( $dmin - $dhrs * 60))
      dsec=$(( $delta - $dmin * 60 - $dhrs * 60 * 60 ))
      ulckday=`date --date="1970-01-01 00:00:00 UTC +$ulcktime seconds" +'%H:%M'`
      echo "First login:   $ulckday"
      wh="Working hours: $(printf %02d $dhrs):$(printf %02d $dmin)"
      dmin=$(( $mittagspause / 60 ))
      dhrs=$(( $dmin  / 60 ))
      dmin=$(( $dmin - $dhrs * 60))
      echo "Lunch break:   $(printf %02d $dhrs):$(printf %02d $dmin)"
      ulcktime=`tail -1 $logfile | grep -E -o "[0-9]{4,}"`
      delta=$(( $(date +%s) - $ulcktime ))
      dmin=$(( $delta / 60 ))
      dhrs=$(( $dmin  / 60 ))
      dmin=$(( $dmin - $dhrs * 60))
      echo "Last change:   $(printf %02d $dhrs):$(printf %02d $dmin)"
      echo $wh
fi

if [ "$initialize" = "1" ]; then
  cp -f $logfile "$logfile-$( date +%y-%m-%d ).txt"
  date +'I %u %j %H:%M %s' > $logfile
fi

if [ "$listen" = "1" ]; then
#  dbus-monitor --session "type='signal',interface='org.gnome.ScreenSaver'" |
   dbus-monitor --session "type='signal',interface='org.cinnamon.ScreenSaver'" |
    while read x; do
      case "$x" in
        *"boolean true"*)  date +'L %u %j %H:%M %s' >> $logfile
                           ;;
        *"boolean false"*) unlockedScreen "U"
                           ;;
      esac
    done
else
  if [ "$listenx" = "1" ]; then
    xscreensaver-command -watch |
      while read x; do
        case "$x" in
          BLANK* | LOCK* )  date +'L %u %H:%M %s' >> $logfile ;;
          UNBLANK* )        unlockedScreen "U";;
        esac
      done
  fi
fi

