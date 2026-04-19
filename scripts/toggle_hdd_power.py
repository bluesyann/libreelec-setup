#!/usr/bin/python
import sys
import RPi.GPIO as GPIO
from time import sleep

HDD_PIN = 19

sys.path.append('/storage/.kodi/addons/virtual.rpi-tools/lib')
GPIO.setmode(GPIO.BCM)
GPIO.setup(HDD_PIN, GPIO.OUT)

# Toggle power
print(f"Setting pin {HDD_PIN} to high")
GPIO.output(HDD_PIN, True)
sleep(10)
print(f"Setting pin {HDD_PIN} to low")
GPIO.output(HDD_PIN, False)
