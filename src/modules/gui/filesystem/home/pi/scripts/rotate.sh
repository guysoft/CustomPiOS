#!/bin/bash

if [ -z "$1" ] ; then
  echo "Usage: $0 [normal|inverted|left|right]"
  echo " "
  exit 1
fi

function do_rotate
{
  xrandr --output $1 --rotate $2

  TRANSFORM='Coordinate Transformation Matrix'

  POINTERS=`xinput | grep 'slave  pointer'`
  POINTERS=`echo $POINTERS | sed s/↳\ /\$/g`
  POINTERS=`echo $POINTERS | sed s/\ id=/\@/g`
  POINTERS=`echo $POINTERS | sed s/\ \\\[slave\ pointer/\#/g`
  iIndex=2
  POINTER=`echo $POINTERS | cut -d "@" -f $iIndex | cut -d "#" -f 1`
  while [ "$POINTER" != "" ] ; do
    POINTER=`echo $POINTERS | cut -d "@" -f $iIndex | cut -d "#" -f 1`
    POINTERNAME=`echo $POINTERS | cut -d "$" -f $iIndex | cut -d "@" -f 1`
    #if [ "$POINTER" != "" ] && [[ $POINTERNAME = *"TouchPad"* ]]; then    # ==> uncomment to transform only touchpads
    #if [ "$POINTER" != "" ] && [[ $POINTERNAME = *"TrackPoint"* ]]; then  # ==> uncomment to transform only trackpoints
    #if [ "$POINTER" != "" ] && [[ $POINTERNAME = *"Digitizer"* ]]; then   # ==> uncomment to transform only digitizers (touch)
    #if [ "$POINTER" != "" ] && [[ $POINTERNAME = *"MOUSE"* ]]; then       # ==> uncomment to transform only optical mice
    if [ "$POINTER" != "" ] ; then                                         # ==> uncomment to transform all pointer devices
        case "$2" in
            normal)
              [ ! -z "$POINTER" ]    && xinput set-prop "$POINTER" "$TRANSFORM" 1 0 0 0 1 0 0 0 1
              ;;
            inverted)
              [ ! -z "$POINTER" ]    && xinput set-prop "$POINTER" "$TRANSFORM" -1 0 1 0 -1 1 0 0 1
              ;;
            left)
              [ ! -z "$POINTER" ]    && xinput set-prop "$POINTER" "$TRANSFORM" 0 -1 1 1 0 0 0 0 1
              ;;
            right)
              [ ! -z "$POINTER" ]    && xinput set-prop "$POINTER" "$TRANSFORM" 0 1 0 -1 0 1 0 0 1
              ;;
        esac      
    fi
    iIndex=$[$iIndex+1]
  done
}

XDISPLAY=`xrandr --current | grep primary | sed -e 's/ .*//g'`
if [ "$XDISPLAY" == "" ] || [ "$XDISPLAY" == " " ] ; then
  XDISPLAY=`xrandr --current | grep connected | sed -e 's/ .*//g' | head -1`
fi

do_rotate $XDISPLAY $1
