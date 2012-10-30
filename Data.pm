# Copyright 2000 Eric Bock
# This software may be distributed freely provided this notice appears in
# all copies.

package Data;


sub find_word
{
	my $self = shift;
	my $idiom = $self->{'idiom'};
	my $home = $self->{'home'};

	my $word = shift;
	my $dir = shift;
	my $depth = shift;

	my $line = shift;

	my $char = ord $word;

	open LIST, "<$home/$idiom/$dir/$char.$depth" or return "";

	while (<LIST>)
	{
		($line = $_) and last if /^(\S+): \d+ / and $word eq $1;
	}

	close LIST;

	return $line;
}


# Return TRUE if the given word can be found
sub known_word
{
	my $self = shift;

	my $word = shift;

	# In next directory
	return 1 if $self->find_word($word, "next", 0);

	# In prev directory
	return 1 if $self->find_word($word, "prev", 0);

	# Unknown
	return "";
}


sub add_word
{
	my $self = shift;
	my $idiom = $self->{'idiom'};
	my $home = $self->{'home'};

	# Forbid updates to the database
	return if $self->{'lock'} ;

	my $word = shift;
	my $dir = shift;
	my $depth = shift;
	my $next = shift;

	my $char = ord $word;

	my $line;
	my $freq;
	my $this;
	my %total;
	my $out;

	# Make adjacency directories
	mkdir "$home/$idiom", 0755;
	mkdir "$home/$idiom/prev/", 0755;
	mkdir "$home/$idiom/next/", 0755;

	open LIST, "<$home/$idiom/$dir/$char.$depth" or open LIST, "+>$home/$idiom/$dir/$char.$depth" or return;

	open TEMP, ">$home/add$$~" or return;

	while (<LIST>)
	{
		/^(\S+): (\d+) (.+)$/ or next;
		$this = $1;
		$freq = $2;
		$line = "$3 ";
		next if ord($this) != $char;
		next if $this eq "\xFF\xFE" and $dir eq "prev";
		last if $this ge $word;

		$out .= $_;
	}

	$self->{'total'}++ unless $depth;

	# Old word
	if (defined($this) and $this eq $word)
	{
		my $flag = "";
		my $prep = "";
		my $real = 0;

		$out .= "$word: ";

		# Count this word
		while ($line =~ s/^(\S+) (\d+) //)
		{
			my ($symbol, $count) = ($1, $2);

			next if $symbol eq "\xFF\xFE" and $dir eq "next";

			$count++ and $flag = 1 if $symbol eq $next;
			$prep .= "$symbol $count ";
			$real += $count;
		}

		$prep .= "$next 1 " and $real++ unless $flag;

		$out .= "$real $prep\n";
	}
	# New word
	else
	{
		$self->{'unique'}++ unless $depth;
		$out .= "$word: 1 $next 1 \n";
		$out .= "$this: $freq $line \n" unless eof LIST;
	}

	# Write the known data
	print TEMP $out;

	# Finish writing
	while (<LIST>)
	{
		print TEMP;
	}

	# Replace the original
	close LIST;
	close TEMP;

	rename "$home/add$$~", "$home/$idiom/$dir/$char.$depth";
}


# Enumerate the possibilities
sub init
{
	my $self = shift;
	my $idiom = $self->{'idiom'};
	my $home = $self->{'home'};
	my $reject = $self->{'reject'};

	$self->{'total'} = 0;
	$self->{'unique'} = 0;

	for my $dir ("$home/$idiom/next", "$home/$idiom/prev")
	{
		# Verify the database
		while (<$dir/*>)
		{
			# Ignore non-data files
			next unless /(\d+)\.(\d+)$/;

			# Extract the symbol
			my $char = $1;
			my $depth = $2;

			my $file = $_;

			open FILE, "<$file";
			open INIT, ">$home/init$$~" or next;

			# Validate
			while (<FILE>)
			{
				# Ignore improper format
				/^(\S+): (\d+) (.+)$/ or next;

				my $word = $1;
				my $freq = $2;
				my $line = "$3 ";
				my $prep = "";
				my $real = 0;

				# Ignore incorrect letters
				print STDERR "$word found in $file!\n" and next if ord $word != $char or !$reject->isword($word);

				# Count this word
				while ($line =~ s/^(\S+) (\d+) //)
				{
					my ($symbol, $count) = ($1, $2);

               print STDERR "$symbol found after $word!\n" and next if !$reject->isword($symbol);

					$prep .= "$symbol $count ";

					$real += $count;
				}

				# Okay, use this line
				print INIT "$word: $real $prep\n";
			}

			close FILE;
			close INIT;

			# Rewrite the file
			rename "$home/init$$~", "$file";
		}

		# Read the words - all words are followed by at least one other
		while (<$dir/*.0>)
		{
			open FILE, "<$_";

			while (<FILE>)
			{
				# Verify the format
				next unless /^(\S+): (\d+) /;

				my $count = $2;

				# Extract the frequency
				$self->{'total'} += $count;
				$self->{'unique'}++;
			}

			close FILE;
		}
	}
}


my %data = (
				"idiom"        => undef,
				"total"        => undef,
				"unique"       => undef,
				"home"         => undef,
				"lock"         => undef,
				"reject"			=> undef,
			  );


sub new
{
	my $type = shift;
	my $class = ref($type) || $type;
	my $self = bless {%data}, $class;

	$self->{'idiom'} = shift;
	$self->{'home'} = shift;
	$self->{'reject'} = shift;
	$self->init;

	return $self;
}


sub AUTOLOAD
{
	my $self = shift;
	my $type = ref($self) or die "$self is not a reference.\n";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;

	die "Can't access $name in $type.\n" unless exists $self->{$name};

	return $self->{$name} = shift if @_;
	return $self->{$name};
}


1;

