# Design of a Digital Signal Processor for wireless communications
Student: Christian PALMIERO  
Academic supervisor: Renaud PACALET  
Semester: Spring 2017 - EURECOM Sophia Antipolis

----
## Abstract
[Embb](http://embb.telecom-paristech.fr/) is a Digital Signal Processor (DSP) designed by Telecom ParisTech researchers and dedicated to Software Defined Radio (SDR) applications. It is a collection of DSP units, each dedicated to a family of DSP algorithms (vector processing, Fourier transforms, interleaving...) interconnected around a communication network and controlled by a general-purpose processor.  
In the previous Embb version the communication between DSP units makes use of the standard Virtual Component Interface (VCI) point-to-point communication protocol. The goal of this project is to rework the communication infrastructure in order to use the more recent AMBA AXI4 protocol.
## List of contents
## Introduction
All DSP units of Embb share the same generic hardware architecture, the DU Shell, which comprises 3 components:  
* Processing Sub-System (PSS), a custom processing unit;
* Memory Sub-System (MSS), a local storage facility;
* Control Sub-System (CSS), responsible for interfacing with the host system and for acting as a controller of the whole DSP unit.

The CSS is a generic module and is composed of several configuration registers, two FIFO queues dedicated to the communication with the host system, two FIFO queues dedicated to the communication with the MSS and/or a Direct Memory Access engine (DMA).  
This project mainly focuses on the rework of the communication infrastructure between all CSS internal components. Furthermore, it defines new functional specifications for the execution of DMA data transfers inside MSS or between MSS and other memory locations in the
whole system.  
Therefore, the first chapter of the current report describes in details the new CSS architecture; the second chapter specifies the new interface between DMA and MSS.
## Chapter 1 - Control Sub-System

## Chapter 2 - Direct Memory Access engine

## References
