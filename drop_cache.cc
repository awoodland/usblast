#include <fstream>
#include <iostream>
#include <cstdlib>
#include <unistd.h>
#include <sys/types.h>

// (c) 2010, Alan Woodland
// Distributed under the terms of the GPLv2 or newer, see GPL-2.txt
// In order for the md5sum checking to work there must be no caches
// This file produces a very simple binary which can be installed setuid 
// root to help the imager.pl script

int main() {
  if (geteuid()) {
	 std::cerr << "drop_cache must be setuid root!" << std::endl;
	 exit(-1);
  }

  system("/bin/sync");

  std::ofstream ctrl("/proc/sys/vm/drop_caches");
  ctrl << "3" << std::endl;
}
