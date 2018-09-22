"""
Multithreaded processing (code copyrighted but modified but from from Ingenico)
"""

import sys
import threading
import time
import popen2
import re
import subprocess
from time import sleep

class dumbb (threading.Thread):

  def __init__(self,lo,li):
    self.loc = lo
    self.liste = li
    self.cour = None
    threading.Thread.__init__(self)

  def run(self):
    while True:
      self.loc.acquire()
      if len(self.liste) > 0:
        self.cour = self.liste.pop(0)
      else:
	self.loc.release()
        break
      self.loc.release()
      CmdLine = 'echo; ls ' + self.cour
#     + ' 2>&1>/dev/null'
      retcode = subprocess.call(CmdLine  , shell=True)
      print str(self.cour) +  ";" + str(retcode)
      sleep (2.0)

# Parallelism value
NB_FIL = 3
ste = []
ecv = []

# Parameters (ad infinitum)
ste = ['a*', 'b*', 'c*', 'd*', 'e*', 'f*']

goulot = threading.Lock()

for g in range(NB_FIL):
  i = dumbb(goulot,ste)
  ecv.append(i)
  i.start()

for h in ecv:
  h.join()
  sleep(0.75)

sys.exit(0)
