#!/usr/bin/perl

# Many thanks to Matt Stanton for the inspiration to create this;
#             to the denizens of #caml-anime and #angband for suggestions,
#             to Ross Morgan-Linial and Jay Kominek for stresstesting,
#             and to everyone who has had fun with it  ^_^
#
# Copyright 2000 Eric Bock
# This software may be distributed and modified freely provided this notice
# appears in its entirety in all copies and deriviative works.
#
# Please send bug reports and comments to ebock@uswest.net
# I would appreciate being sent modified versions as well.

### Defaults ###

my $owner = "hybrid";

# Speech Defaults
my $depth = 10;
my $idiom = "data";
my $lurk = 7000;
my $delay = 333;

# Bot Defaults
my $name = "cibeleborg";
my %abbr = (
				"perlborg" => 1,
				"perlbot"  => 1,
				"perl"     => 1,
				"borg"     => 1,
				"bot"      => 1,
				"borgbot"  => 1,
				"borgypants" => 1
			  );
my %ignore;
my %master = (
				  lc $owner => 1,
				  substr(lc $owner, 0, 3) => 1,
				 );
my %dropin;

# IRC Defaults
my $serv = "irc.freenode.net";
my $port = 6667;
my $user = "borg";
my $chan = "#labmacambira";

my $babble = "";
my $console = "";
my $lock = "";
my $shutup = "";
my $peek = "";

my @usage = (
				 "Usage: $0 <options>\n",
				 "\n",
				 "   Speech Options\n",
				 "      -d<word depth>\n",
				 "      -i<language idiom>\n",
				 "      -l<lurk until n words\n",
				 "      -w<wait time>\n",
				 "      -t<add text file to database>\n",
				 "\n", "   Bot Options\n",
				 "      -n<bot name>\n",
				 "      -a<short name>\n",
				 "      -g<ignore name>\n",
				 "      -m<master name>\n",
				 "      -e<extra module>\n",
				 "      -C [console only]\n",
				 "      -L [lock database]\n",
				 "      -S [shutup]\n",
				 "      -P [peek]\n",
				 "\n",
				 "   IRC Options\n",
				 "      -s<server>\n",
				 "      -p<port>\n",
				 "      -u<user>\n",
				 "      -c<channel>\n",
				);

# Home
my $home = "$ENV{'HOME'}/.perlborg";

# Make data directory
mkdir $home, 0755;


### Include modules ###

use Bot;
use Data;
use Reject;
use Relate;

my $reject = new Reject;
my $data = new Data($idiom, $home, $reject);
my $relate = new Relate($depth, $data, $reject);


sub text_tokenize
{
	$_ = lc shift;

   s/[^\S\n]/ /gs;

	s/\n{3,}/\n\n/gs;

   s/(?<!\n)\n(?!\n)/ /gs;

	s/['`]{2,}/"/gs;

	s/\s['`]/ /gs;
	s/['`]\s/ /gs;

   y/,/ /s;

	y/.?!;:"()[]<>{}/./s;

   s/\s*\././gs;

   y/ .//s;
}


# Read a text file
sub read_text
{
	my $back = 4;

	my $text;

	my $tty = "";

	use POSIX;
	$tty = POSIX::isatty STDOUT;

	undef $/;

	for (glob $_[0])
	{
		open FILE, "<$_" or next;

		print ((" " x 80, "\n") x 10, "\x1B[A" x 10) if $tty;

		print "Reading $_...";

		$text .= <FILE>;
		close FILE;

		# Efficiency - clean entire text before parsing individual sentences
		$text = text_tokenize($text);

		print "done.\n";
	}

	$/ = "\n";

	print "\n";

	my $len = length $text;
	my $newlen = 0;

	while ($text ne "")
	{
		$text =~ s/^(.*?)\n\n//s;
		$line = $1;

		$newlen = length $text;

		next unless my @list = split '.', $line;

		if ($tty)
		{
			$line = join '', @list;

			print ((" " x 80, "\n") x 4, "\x1B[A" x 4);

			printf "Progress: %7.3f%%\n", 100 - $newlen / $len * 100;
			printf "Bytes: %-10d   Total : %d\n", $len - $newlen, $len;
			printf "Words: %-10d   Unique: %d\n", $data->total, $data->unique;
			print "\n";

			print ((" " x 80, "\n") x ($back - 4), "\x1B[A" x ($back - 4)) if $back > 4;

			$back = 4;

			$line =~ s/\t/   /g;

			for ($line)
			{
				while ($_ ne "")
				{
					print substr($_, 0, 80), "\n";
					substr($_, 0, 80) = "";
					$back++;
				}
			}

			print "\x1B[A" x ($back - 4);
		}

		$relate->relate(@list);

		print "\x1B[A" x 4 if $tty;
	}

	print "\n" x ($back + 1) if $tty;
}


### Init ###

for (@ARGV)
{
	/^-d(\d+)/ and $relate->{'depth'} = $1, next;
	/^-i(\S+)/ and $data = new Data($1, $home, $reject), $relate->{'data'} = $data, next;
	/^-l(\d+)/ and $lurk = $1, next;
	/^-w(\d+)/ and $delay = $1, next;
	/^-t(\S+)/ and read_text($1), next;

	/^-n(\S+)/ and $name = $1, next;
	/^-a(\S+)/ and $abbr{lc $1} = 1 and next;
	/^-g(\S+)/ and $ignore{lc $1} = 1, next;
	/^-m(\S+)/ and $master{lc $1} = 1, next;
	/^-e(\S+)/ and $dropin{$1} = 1, next;

	/^-s(\S+)/ and $serv = $1, next;
	/^-p(\d+)/ and $port = $1, next;
	/^-u(\w+)/ and $user = $1, next;
	/^-c(\S+)/ and $chan = $1, next;

	/^-B/ and $babble = 1, next;
	/^-C/ and $console = 1, next;
	/^-L/ and $lock = 1, next;
	/^-S/ and $shutup = 1, next;
	/^-P/ and $peek = 1, next;

	/^-(w)/ and die @usage;
}

$data->{'lock'} = $lock if $data->{'unique'};

# Oops...
eval {chdir $home} or die "$@\n";

if (!$console)
{
	# Become IRC Bot
	$bot = new Bot(
						$owner,
						$delay, $lurk, $relate, $data,
						$name, \%abbr, \%ignore, \%master,
						$serv, $port, $user, $chan,
						$shutup, $peek
					  );

	# Process IRC
	$bot->bot;
}
else
{
	print "Read $data->{'total'} words, $data->{'unique'} unique.\n";
	print	"Coherency @{[$data->unique ? $data->total/$data->unique : 0]}.\n";
	print "> " unless $babble;

	my $line = <STDIN> if $babble;

	while ($babble or defined ($line = <STDIN>))
	{
		$_ = $relate->construct($line, 0, 1);

		next if $_ eq "";

		$line = $_;

		print "$_\n";
	}
	continue
	{
		if ($babble)
		{
			sleep (length($_) / 10);
			$_ = $line;
		}
		else
		{
			print "> ";
		}
	}
}


