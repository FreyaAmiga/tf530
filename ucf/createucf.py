import sys,re

ucfheader = """# Copyright (C) 2016-2017, Stephen J. Leary
# All rights reserved.
#
# This file is part of TF530 (Terrible Fire 030 Accelerator)
#
# TF530 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# TF530 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with TF530. If not, see <http://www.gnu.org/licenses/>.

"""

if len(sys.argv) != 2:
        print "Usage: %s <netlist>" % (sys.argv[0])
        sys.exit(-1)

fname = sys.argv[1]

currentNet = None

cplds = ["XC9572XL(RAM)","XC9572XL(BUS)"]
ucfs = {}

exclude = ["GND","VCC33","TCK","TDO","TMS","TDINT","TDI"]
busre = re.compile(r'(\d+$)')
notbus = ["DS20","INT2","AS20","CLK20", "RW20","BG20"] 

with open(fname) as f:
        content = f.readlines()
        for line in content:
                tokens = (line).split()
                if len(tokens) == 0:
                        continue
                if len(tokens) == 5:
                        currentNet = tokens[0].replace("/","")
                        tokens = tokens[1:]
                if (currentNet is not None) and not currentNet in exclude:
                        chip = tokens[0]
                        if chip in cplds:
                                try:
                                        ucf = ucfs[chip]
                                except:
                                        ucf = ""
                                if currentNet in notbus:
                                        netname = currentNet
                                else:
                                        netname = busre.sub(r'<\1>', currentNet)
                                ucf += 'NET "%s"      LOC="%s";\n' % (netname,tokens[1])
                                ucfs[chip] = ucf


for ucfkey in ucfs.keys():
        f = open(ucfkey+".ucf","w")
        f.write(ucfheader)
        f.write(ucfs[ucfkey])
        f.close()
        
