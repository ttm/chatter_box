# Copyright 2000 Eric Bock
# This software may be distributed freely provided this notice appears in
# all copies.

package Relate;


# Build relationships
sub relate
{
	my $self = shift;

	my @list = ("\xFF\xFF", @_, "\xFF\xFF");
	my $len = @list;
	my $max = ($len < 100) ? $len : 100;

	use POSIX;
	my $tty = POSIX::isatty STDOUT;

	# Count the frequencies
	for (my $i = 0; $i < $len; $i++)
	{
		my $cur = $list[$i];

		print "." if $tty and (int ($i * 10 / $len) != int (($i - 1) * 10 / $len));

		for (my $off = 1; $off < $max; $off++)
		{
			# This word is before the current word
			$self->data->add_word($cur, "prev", $off - 1, $list[$i - $off]) if $off <= $i;

			# This word is after the current word
			$self->data->add_word($cur, "next", $off - 1, $list[$i + $off]) if $i + $off < $len;
		}
	}

	print "\b \b" x 10 if $tty;
}


# Build sentences
sub build
{
	my $self = shift;

	my @words = @_;
	my @freq;

	# No good words yet
	my $tot;
	my $val;
	my $mid;

	# Calculate total rarity
	for ($i = 0; $i < @words; $i++)
	{
		my $line = $self->data->find_word($words[$i], "prev", 0);

		# Extract the freqnency
		$line =~ /^\S+: (\d+) / or next;

		# Store the frequency
		$freq[$i] = $1 or next;

		# Calculate the rarity
		$tot += ($self->data->total) / $1;
	}

	# Pick a random word weighted by rarity
	my $num = rand $tot;

	for ($mid = 0; $mid < @words; $mid++)
	{
		next unless $freq[$mid];
		last if $num < ($val += ($self->data->total) / $freq[$mid]);
	}

	# Add the center word
	@words = ($words[$mid]);

	# Start with the middle word
	my $cur = $words[0];

	# Scan backward
	{
		my $tot = 0;
		my %pick;
		my $len = @words;

		# Collect previous words
		for (my $i = 0; ($i < $self->{'depth'}) and ($i < $len); $i++)
		{
			my $word = $words[$i];

			last unless my $line = $self->data->find_word($word, "prev", $i);

			$line =~ s/^\S+: \d+ (.*)/$1 /;

			while ($line =~ s/^(\S+) (\d+) //)
			{
				my ($symbol, $count) = ($1, $2);
				$tot += $count / ($i + 1);
				$pick{$symbol} += $count / ($i + 1);
			}
		}

		last unless $tot;

		my $val;

		# Pick a random word weighted by potential previous words
		my $num = rand $tot;

		for (keys %pick)
		{
			last if $num < ($val += $pick{$cur = $_});
		}

		# Add it to the beginning
		unshift @words, $cur and redo if $cur ne "\xFF\xFF";
	}

	# Start with the middle word
	$cur = $words[-1];

	# Scan forward
	{
		my $tot = 0;
		my %pick;
		my $len = @words;

		# Collect next words
		for (my $i = 0; ($i < $self->{'depth'}) and ($i < $len); $i++)
		{
			my $word = $words[-1 - $i];

			last unless my $line = $self->data->find_word($word, "next", $i);

			$line =~ s/^\S+: \d+ (.*)/$1 /;

			while ($line =~ s/^(\S+) (\d+) //)
			{
				my ($symbol, $count) = ($1, $2);
				$tot += $count / ($i + 1);
				$pick{$symbol} += $count / ($i + 1);
			}
		}

		last unless $tot;

		my $val;

		# Pick a random word weighted by potential next words
		my $num = rand $tot;

		for (keys %pick)
		{
			last if $num < ($val += $pick{$cur = $_});
		}

		# Add it to the end
		push @words, $cur and redo if $cur ne "\xFF\xFF";
	}

	# Return the string
	return join ' ', grep {length} @words;
}


# Read input and produce output
sub construct
{
	my $self = shift;

	my $line = shift;
	my $act = shift;
	my $speaking = shift;

	# Lines may not be empty
	return "" unless $line =~ /\S/;

	# Ignore single-word messages
	return "" unless $line =~ /\S\s\S/;

	# Ignore irc commands
	return "" if $line =~ /^[!\/.][a-z]/;

	# Tokenize the line
	my @list = split /\s+/, $self->reject->tokenize($line);

	# Reject words in the line
	return "" unless (@list = $self->reject->reject(@list)) > 1;

	unshift @list, "\xFF\xFE" if $act;

	$self->relate(@list);

	return "" unless $speaking;

	$line = $self->build(@list);

	return $line;
}


my %data = (
				"depth"  => undef,
				"data"   => undef,
				"reject" => undef,
			  );


sub new
{
	my $type = shift;
	my $class = ref($type) || $type;
	my $self = bless {%data}, $class;

	$self->{'depth'} = shift;
	$self->{'data'} = shift;
	$self->{'reject'} = shift;

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

