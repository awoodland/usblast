#!/usr/bin/perl -T

# (c) 2010, Alan Woodland
# Licensed under the terms of the GPLv2 or newer, see GPL-2.txt for details
# You should compile and setuid the drop_cache program if you want 
# to be sure the md5 verification works

use strict;
use warnings;

use POSIX;
use IO::Select;

my $DEVDIR="/dev/";
my $BLACKLIST=qr/sd[ab]/;
my $DEVPAT=qr/sd[a-z]/;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)}; # Make %ENV safer

my $image_file=$ARGV[0] || "master.img";
my $verify_md5=`/usr/bin/md5sum $image_file` || die "Failed to compute md5 for $image_file";
$verify_md5 =~ s/\s+.*$//;
chomp $verify_md5;

print "MD5 of $image_file is: $verify_md5\n";

local $| = 1;

my $egid = getegid();
my $euid = geteuid();

($euid && $egid) || die "Don't run as root - ever!";

print "Running as gid: $egid\n";

sub untaint {
	 my $input = shift;
	 # perlsec for setgid things!
	 if ($input =~ /^([-\@\w.\/]+)$/) {
		  $input = $1;                     # $data now untainted
	 } else {
		  die "Bad data in $input";        # log this somewhere
	 }
	 return $input;
}

sub correct_group {
	 my $dev = shift;
	 my (undef, undef, undef, undef, undef, $gid) = stat("$DEVDIR$dev");
	 return $egid == $gid;
}

while (1) {
	 my $go = 0;

	 my @devices = ();

	 my $s = IO::Select->new();
	 $s->add(\*STDIN);

	 print "Press <ENTER> to start a write cycle\n";
	 while (!$go) {
		  opendir(my $devh, "$DEVDIR") || die "can't opendir $DEVDIR: $!";
		  # maybe if you wanted to write to other devices this regex could be more generalised
		  @devices = grep {/^$DEVPAT$/ && correct_group($_) && ($_ ="$DEVDIR$_")} readdir($devh);
		  print scalar @devices . " device" . ((scalar @devices  != 1) && 's') . " ready to write \r";
		  closedir($devh);
		  $go = <STDIN> while ($s->can_read(1));
	 }

	 print "Starting write cycle on: " . join (', ', @devices) . "\n";

	 if (!scalar @devices) {
		  print "No devices selected!\n";
		  next;
	 }

	 $s = IO::Select->new();
	 foreach my $dev (@devices) {
		  $dev = untaint($dev);
		  # This shouldn't be writeable anyway if udev rules are sane!
		  die if ($dev =~ /$BLACKLIST/i);
		  open(my $h, "/bin/dd if\=$image_file of\=$dev 2>&1 |") || die "Problem starting dd job: $!";
		  $s->add($h);
	 }

	 while ($s->count()) {
		  my @ready;
		  print "." while (!(@ready = $s->can_read(10)) && !$s->has_exception(0.1));
		  foreach my $fh (@ready) {
				my $msg = <$fh>; 
				chomp $msg;
				#print "read some stuff ($msg)\n";
				if (eof($fh)) {
					 $s->remove($fh);
					 close $fh;
					 #print "Now eof\n";
				}
				#sleep 3;
		  }
		  foreach my $fh ($s->has_exception(0.001)) {
				#print "Exception on $fh!\n";
				#sleep 3;
		  }
	 }

	 print "\n";

	 print "Verifying contents\n";
	 `/bin/sync`;
	 `/usr/local/bin/drop_cache`; # this is a very simple C++ program that's setuid root!
	 print "Dropped caches\n";

	 my %handlemap;

	 $s = IO::Select->new();
	 foreach my $dev (@devices) {
		  $dev = untaint($dev);
		  open(my $h, "/usr/bin/md5sum $dev 2>&1 |") || die "Problem starting md5 job: $!";
		  $s->add($h);
		  $handlemap{$h} = $dev;
	 }

	 while ($s->count()) {
		  my @ready;
		  print "." while (!(@ready = $s->can_read(10)));
		  foreach my $fh (@ready) {
				#print "$fh is ready:\n";
				my $result = <$fh>;
				my ($sum, $oldrdev) = ($result =~ /^([0-9A-Za-z]+)\s*([\/a-zA-Z0-9]+)\s*$/);
				my $rdev = untaint($handlemap{$fh});
				print substr($rdev, length($rdev)-1);
				print "\nDevice: $rdev - $sum != $verify_md5\n" if (!defined $sum || lc($sum) ne lc($verify_md5));
				if (lc($sum) eq lc($verify_md5) && defined $rdev) {
					 #print "/usr/bin/eject $rdev\n";
					 `/usr/bin/eject $rdev`;
				}
				$s->remove($fh);
				close $fh;
		  }
	 }

	 print "\n";

	 print "\aWrite cycle completed\n";
}
