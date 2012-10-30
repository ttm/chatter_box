# Copyright 2000 Eric Bock
# This software may be distributed freely provided this notice appears in
# all copies.

package Dropin;


my %data = (
			  );


sub new
{
	my $type = shift;
	my $class = ref($type) || $type;
	my $self = bless {%data}, $class;

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

