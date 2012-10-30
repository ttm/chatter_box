# Copyright 2000 Eric Bock
# This software may be distributed freely provided this notice appears in
# all copies.

package Reject;

# Tokenize a line
sub tokenize
{
	my $self = shift;

	for (lc shift)
	{
		# Ensure surrounding space
		$_ = " $_ ";

		# Remove ellipsis
		s/\.{2,}/ /g;

		# Squash most characters
		y</0-9a-z><>cs;

		# Clean excess characters
		s<([/\da-z])\1{3,}><$1>g;

		# Reduce redundant sequences
		s/(\S{2,}?)\1{2,}/$1$1/g;

		# Remove commas between letters
		s/([a-z]),([a-z])/$1 $2/g;

		# Remove ticks not between letters
		s/([^a-z])'/$1 /g;
		s/'([^a-z])/ $1/g;

		# Remove empty brackets
		s/\((\D*)\)/ $1 /g;
		s/[<(\[{]+[}\])>]+/ /g;

		# Remove misplaced mathematical symbols
		s/[+\$](\D)/ $1/g;

		# Remove large brackets
		s/<([^>]*?\s[^<]*?)>/ $1 /g;
		s/{([^}]*?\s[^{]*?)}/ $1 /g;
		s/\(([^\)]*?\s[^\(]*?)\)/ $1 /g;
		s/\[([^\]]*?\s[^\[]*?)\]/ $1 /g;

		# Remove unclosed brackets
		s/[(<\[{]+(\w+\s)/ $1/g;
		s/(\s\w+)[}\]>)]+/$1 /g;

		# Remove leading commas, underscores, queries, quotes
		s/\s[,_?"]+/ /g;

		# Remove trailing commas, dots, underscores, slashes, bangs, queries, quotes
		s/[,._\/!?"]+\s/ /g;

		# Remove leading colons or semicolons
		s/\s[:;]([^\Wobp]|\w\w|\S{3})/ $1/g;

		# Remove trailing colons
		s/([^\Wodq]|\w\w|\S{3}):\s/$1 /g;

		# Remove leading hyphens not forming negative numbers
		s/\s-(\D)/ $1/g;

		# Remove trailing hyphens
		s/-\s/ /g;

		# Remove carets and tildes not forming verticons
		s/\s[~^]([^-._])/ $1/g;
		s/([^-._])[~^]\s/$1 /g;

		# Remove trailing semicolons not part of verticons
		s/\s(\S[^-._]\S);\s/$1 /g;

		# Remove trailing semicolons not forming smilies
		s/\s([^\Wodq]|\w\w);\s/ $1 /g;

		# Replace leading www. with http://www.
		s<\swww\.>< http://www.>g;

		# Replace leading ftp. with ftp://ftp.
		s<\sftp\.>< http://ftp.>g;

		# Squash spaces
		y/ //s;

		# Squash repeated words
		{redo if s/((\s\S+)+?)\1+\s/$1 /g}

		return $_;
	}
}


# Return TRUE if the given string is a word
sub isword
{
	my $self = shift;

	for (shift)
	{
		# Remove strange single characters
		return "" if (length == 1) and /[\W_]/;

		# Remove strings with interior carets, hashes, semicolons, brackets
		return "" if /.[#=;()<>\[\]{}]./;

		# Remove strings with interior colons not between p and //
		return "" unless !/\S:\S/ or /http:\/\// or /ftp:\/\//;

		# Remove strings with ands, ats, backslashes, backticks, bangs, queries
		return "" if /[&\@\\`!?]/;

		# Remove strings with leading slashes, dots, bangs
		return "" if /^[.\/!]/;

		# Remove numbers with bad interior characters
		return "" if /\d[^\da-z,.]+\d/;

		# Remove very large numbers
		return "" if /[\d,.]{4,}/;
	}

	# Success
	return 1;
}


# Reject words (and lines if necessary)
# Return the list of valid words
sub reject
{
	my $self = shift;
	my @list = @_;

	# Require multiple words
	return () unless (@list = grep {length && $self->isword($_)} @list) > 2;


	### Check duplicates ###

	my $line = join ' ', @list;

	# Ignore repeated lines within a length of 10
	return () if grep {$line eq $_} @{$self->prev};

	# Add this to the stack
	push @{$self->prev}, $line;

	# Remove first line after we have 10 lines
	shift @{$self->prev} if @{$self->prev} > 10;

	# Success
	return @list;
}


my %data = (
				'prev'  => [],
			  );


sub new
{
	my $type = shift;
	my $class = ref($type) || $type;
	return bless {%data}, $class;
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

