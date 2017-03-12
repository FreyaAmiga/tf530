TF530 Binary Files
==================

These are binary files that i create to make life easy for people bringing up the TF530.

File Description

The .xsvf is a single file containing both JED files that should be playable by an xsvf player. If you dont have one you will need the jed files.


<date>_tf530_bus.jed - File for the first CPLD in the chain.
<date>_tf530_ram.jed - File for the second CPLD in the chain.

~~~~
  Chain Diagram
  
            -------         -------        
  TDI ---- |       |-->----|       | - - -|
           |  BUS  |       |  RAM  |      |
           |       |       |       |      |
            -------         -------       |
                                          |
  TDO -----<-------------------------<-----
~~~~
