systemroller
============

A System Stress Testing and basic Diagnostics Tool

SystemRoller is a minimal Fedora LiveCD to stress test and verify
system hardware. The main objective is to put load on multiple
system components in multiple threads concurrently and check for
errors. It attempts to ensure complete coverage by stressing every
subsystem and parts of subsystems. For example it uses different
instruction sets to stress virtually every component of the CPU.

The tests cover CPU, Memory, Disk and Network. Network testing
stresses the NIC but does not require a separate responder system
and does not flood the network with packets. It is also possible
to select which components to stress.

SystemRoller in full blast can generate enough load to increase
system temperatures by a few to several degrees celsius even on
enterprise servers in a datacenter. As such it can help to expose
veiled problems in faulty components that appear to work okay
but can suddenly fail during actual use.

