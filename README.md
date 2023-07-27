# auto_bisect_llvm_openmc

The way this works is you specify the known good and bad commits
in the bisect.sh script. This starts the git bisection and passes
the run.sh script, that actually does the work of compiling things
and testing for correctness.

The script was written specifically for my environment on JLSE
but with minimal effort could be made to be more general.

The script builds LLVM and loads the "llvm/ci" module, so as not
to clobber the experimental build and install.

The script also has a totally separate openmc source tree so
as not to clobber my main working one. I could have done this
with LLVM itself as well, but given the size of the LLVM repo,
this seemed easier.

Could be valuable to make it more self contained, perhaps
with a prelude script that downloads and clones everything
into the folder (e.g., OpenMC XS data, benchmark repo, etc).
