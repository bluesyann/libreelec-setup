#!/usr/bin/python
import logging
import os
import sys
from time import sleep

import RPi.GPIO as GPIO

HDD_PIN = 19
LOG_DIR = "/storage/.config/logs"
LOG_FILE = os.path.join(LOG_DIR, "toggle_hdd_power.log")

os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
	filename=LOG_FILE,
	level=logging.INFO,
	format="%(asctime)s [toggle_hdd_power] %(levelname)s %(message)s",
)

sys.path.append('/storage/.kodi/addons/virtual.rpi-tools/lib')
GPIO.setmode(GPIO.BCM)
GPIO.setup(HDD_PIN, GPIO.OUT)

# Toggle power
logging.info("Setting pin %s to high", HDD_PIN)
GPIO.output(HDD_PIN, True)
sleep(10)
logging.info("Setting pin %s to low", HDD_PIN)
GPIO.output(HDD_PIN, False)
