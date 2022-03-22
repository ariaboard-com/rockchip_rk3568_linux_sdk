#!/bin/sh
#

TRY_CNT=0
check_uvc_buffer()
{
  if [ "$TRY_CNT" -gt 0 ];then
     let TRY_CNT=TRY_CNT-1
     #echo "++++++++TRY_CNT:$TRY_CNT"
  fi
  if [ "$TRY_CNT" -gt 10 ];then
     echo "+++check_uvc_buffer recovery fail,reboot to recovery now+++"
     reboot &
  fi
  if [ -e /tmp/uvc_camera_no_buf ];then
     let TRY_CNT=TRY_CNT+10
     echo "uvc no buf to send 200 frames,try to recovery isp time,timeout:$TRY_CNT"
     killall ispserver
     killall aiserver
     rm /tmp/uvc_camera_no_buf -rf
  fi
}
check_alive()
{
  PID=`busybox ps |grep $1 |grep -v grep | wc -l`
  if [ $PID -le 0 ];then
     if [ "$1"x == "uvc_app"x ];then
       echo " uvc app die ,restart it and usb reprobe !!!"
       sleep 1
       rm -rf /sys/kernel/config/usb_gadget/rockchip/configs/b.1/f*
       echo ffd00000.dwc3  > /sys/bus/platform/drivers/dwc3/unbind
       echo ffd00000.dwc3  > /sys/bus/platform/drivers/dwc3/bind
       /oem/usb_config.sh rndis off #disable adb
       usb_irq_set
       uvc_app &
     else
       if [ "$1"x == "ispserver"x ];then
          ispserver -n &
       else
         if [ "$1"x == "aiserver"x ];then
            echo "aiserver is die,tell uvc to recovery"
            killall -3 uvc_app
            aiserver &
         else
            $1 &
         fi
       fi
     fi
  fi
}

stop_unused_daemon()
{
  killall -9 adbd
  killall -9 ntpd
  killall -9 connmand
  killall -9 dropbear
  killall -9 start_rknn.sh
  killall -9 rknn_server
}

usb_irq_set()
{
  #for usb uvc iso
  usbirq=`cat /proc/interrupts |grep dwc3| awk '{print $1}'|tr -cd "[0-9]"`
  echo "usb irq:$usbirq"
  echo 1 > /proc/irq/$usbirq/smp_affinity_list
}
#ulimit -c unlimited
dbserver &
ispserver -n &
stop_unused_daemon
/oem/usb_config.sh rndis
usb_irq_set
uvc_app &
aiserver &
while true
do
  check_alive dbserver
  check_alive ispserver
  check_alive uvc_app
  check_alive aiserver
  check_uvc_buffer
  sleep 2
  check_alive smart_display_service
done
