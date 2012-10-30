# Copyright 2000 Eric Bock
# This software may be distributed freely provided this notice appears in
# all copies.

package Bot;

$SIG{CHLD} = sub {wait};


use Net::IRC;


my $self;


# Message log
sub mlog
{
	print "[".localtime()."] ", @_;
}


# React to a message
sub react
{
	my $self = shift;

	return "" if $self->{'shutup'} ;

	return "" if $self->data->total < $self->{'lurk'} ;

	return "" if time - $self->{'time'} < $self->{'delay'} ;

	$self->{'time'} = time;

	return 1;
}

# Paste a message to somebody
sub paste
{
	my $bot = shift;

	my $nick = shift;
	my @lines = split "\n", shift;
	my $peek = shift;

	return if @lines > 5;

	for (@lines)
	{
		if (/^\xFF\xFE (.*)/)
		{
			$bot->me($nick, $1);
			$bot->me($self->{'owner'}, $1) if $peek and lc($nick) ne lc($self->{'owner'});
			mlog "* @{[$self->{'name'}]} $1\n";
		}
		else
		{
			$bot->privmsg($nick, $_);
			$bot->privmsg($self->{'owner'}, $_) if $peek and lc($nick) ne lc($self->{'owner'});
			mlog "<@{[$self->{'name'}]}> $_\n";
		}
	}

	sleep(@lines * @lines);

	return 1;
}

# Process a bot command
sub do_command
{
	my ($bot, $event) = @_;

	my $nick = $event->nick;
	my $arg = ($event->args)[0];


	return if $self->{'peek'} and lc $nick ne lc $self->{'owner'} ;

	my $res;

   my $now = time;

	mlog "Reacting to $arg\n";
	$bot->privmsg($self->{'owner'}, "<$nick> $arg");

	### Public commands ###

	for ($arg)
	{
		/^!words/ and return eval
		{
			return "I know @{[$self->data->total]} words, @{[$self->data->unique]} of them unique.\n".
				(($self->{'lurk'} > $self->data->total) ? "I want @{[$self->{'lurk'} - $self->data->total]} more." : "");
		};

		s/^!dice +// and return eval
		{
			sub roll
			{
				my $x = my $r = shift;
				my $y = shift;
				my $type = shift;

				if (!$type)
				{
					$r += int rand $y while --$x;
					return $r;
				}

				{
					next if $type == 1;
					$r *= $y and next if $type == 2;
					$r = int ($x * ($y + 1) / 2) and next if $type == 3;
				}

				return $r;
			}

			sub dice
			{
				$_ = lc shift;
            my $type = shift;

				s/\s/ /gs;
				s/ .*//g;

				return "'$_' doesn't look like a dice roll." if !/[cdkm]/ or m<[^-\dcdkm+*/()]>g;

				my $now = time;

				{
					last if time - $now > 10;
					print "Rolling $_...\n";
					redo if s<\((-?\d+)\)><$1>g;
					redo if s<(\d+)d(\d+)><roll($1, $2, $type)>ge;
					redo if s<(\d+)(d+)(\d+)><roll($1, $3, $type).("d" x (length($2) - 1)).$3>ge;
					redo if s<((\d+\*\*)*)(\d+)\*\*(\d+)><($1 || "").$3**$4>ge;
					redo if s<(\d+)([*/])(\d+)><"int $1$2$3">gee;
					redo if s<(\d+)([-+])(\d+)><"$1$2$3">gee;
					redo if s<d(\d+)><1 + int rand $1>ge;
					redo if s<(\d+)c><$1*100>ge;
					redo if s<(\d+)k><$1*1000>ge;
					redo if s<(\d+)m><$1*1000000>ge;
					redo if s<([-+])(\d+)(\D)><"$1$2$3">gee;
				}

				return $_;
			}

         my @dice;

         for my $roll (split ',')
			{
				my $try = dice($roll, 0);

            @dice = ($try) and last if $try =~ /^'/;

				@dice = ("Too many dice!") and last unless time - $now <= 10;

				my $min = dice($roll, 1);
				my $max = dice($roll, 2);
				($min, $max) = ($max, $min) if $min > $max;
            my $avg = dice($roll, 3);

				push @dice, "$try (min $min, max $max, avg $avg)";
			}

			return join '; ', @dice;
		};

		s/^!eval // and return eval
		{
			# Maximum security
			open SAFE, ">safe$$~";
			print SAFE (
							"#!/usr/bin/perl\n",
							"use Safe;\n",
							"mkdir 'safe', 0777;\n",
							"chroot 'safe';\n",
							"chdir '/';\n",
							"\$vault = new Safe;\n",
							"\$vault->permit(qw{null stub scalar pushmark wantarray const gvsv gv gelem padsv\n",
							"padav padhv padany pushre rv2gv rv2sv av2arylen rv2cv anoncode prototype refgen srefgen\n",
							"ref bless regcmaybe regcreset regcomp match qr subst substcont trans sassign aassign\n",
							"chop schop chomp schomp defined undef study pos preinc i_preinc predec i_predec postinc\n",
							"i_postinc postdec i_postdec pow multiply i_multiply divide i_divide modulo i_modulo\n",
							"repeat add i_add subtract i_subtract concat stringify left_shift right_shift lt i_lt\n",
							"gt i_gt le i_le ge i_ge eq i_eq ne i_ne ncmp i_ncmp slt sgt sle sge seq sne scmp bit_and\n",
							"bit_xor bit_or negate i_negate not complement atan2 sin cos rand srand exp log sqrt\n",
							"int hex oct abs length substr vec index rindex sprintf formline ord chr crypt ucfirst\n",
							"lcfirst uc lc quotemeta rv2av aelemfast aelem aslice each values keys delete exists\n",
							"rv2hv helem hslice unpack pack split join list lslice anonlist anonhash splice push\n",
							"pop shift unshift sort reverse grepstart grepwhile mapstart mapwhile range flip flop\n",
							"and or xor cond_expr andassign orassign method entersub leavesub leavesublv caller\n",
							"warn die reset lineseq nextstate dbstate unstack enter leave scope enteriter iter\n",
							"enterloop leaveloop return last next redo time tms localtime gmtime});\n",
							"\$vault->deny(qw{print prtf});\n",
							"open OUT, '>output';\n",
							"alarm(10);\n",
							"print OUT \$vault->reval('$_');\n",
							"close OUT;\n",
							"chmod 0666, 'output';\n",
						  );
			close SAFE;

			# Make executable
			chmod 0777, "safe$$~";

			# Execute the code
			system("safe$$~");

			open OUT, "<safe/output";

			undef $/;

			read OUT, $res, 256;

			close OUT;

			$/ = "\n";

			# Send the answer back
			return $res;
		};

		/^!shutup/ and return eval
		{
			return "\xFF\xFE sniffles quietly." if $self->{'shutup'};
			$self->{'shutup'} = 1;
			return "awww...";
		};

		/^!wakeup/ and return eval
		{
			return "But I'm already awake!" unless $self->{'shutup'};
			$self->{'shutup'} = 0;
			return "Thanks, that was getting boring.";
		};

		/^!help/ and return eval
		{
			$bot->privmsg($nick, "Hi, I'm the Perl Borg!  Available commands are:");
			$bot->privmsg($nick, "!dice - Borg dice");
			$bot->privmsg($nick, "!eval - Perl interpreter");
			$bot->privmsg($nick, "!shutup - Shut the bot up");
			$bot->privmsg($nick, "!wakeup - Opposite of shutup");
			$bot->privmsg($nick, "!words - Show number of words in memory");
			$bot->privmsg($nick, "!help - What you just did");
		};
	}

	return "" unless ${$self->{'master'}}{lc $nick};


	### Master commands ###

	for ($arg)
	{
		/^!ignore\s+(\S+)/ and return eval
		{
			${$self->{'ignore'}}{lc $1} = 1;
			return "Ignoring $1.";
		};

		/^!unignore\s+(\S+)/ and return eval
		{
			delete ${$self->{'ignore'}}{lc $1};
			return "Unignoring $1.";
		};

		/^!master\s+(\S+)/ and return eval
		{
			${$self->{'master'}}{lc $1} = 1;
			return "$1 is now a master.";
		};

		/^!unmaster\s+(\S+)/ and return eval
		{
			delete ${$self->{'master'}}{lc $1};
			return "$1 is not a master.";
		};

		/^!nick\s+(\S+)/ and return eval
		{
			return "$1 is in use!" unless $bot->nick($1);

			$self->{'name'} = $1;

			return "Changed nick to $self->{'name'}.";

			$self->{'abbr'}->{$self->{'name'}} = 1;
		};

		/^!lurk\s+(\d+)/ and return eval
		{
			$self->{'lurk'} = $1;
			return "Okay, I'll lurk until I get $self->{'lurk'} words.";
		};

		/^!delay\s+(\d+)/ and return eval
		{
			$self->{'delay'} = $1;
			return "Changed delay to $self->{'delay'}.";
		};

		/^!known '?(.+)'?/ and return eval
		{
			return "'$1' is ".($self->data->known_word($1) ? "" : "un")."known.";
		};

		/^!peek/ and return eval
		{
			$self->{'peek'} = 1;
			return "Peeking channel $self->{'chan'}.";
		};

		/^!unpeek/ and return eval
		{
			$self->{'peek'} = undef;
			return "Unpeeking channel $self->{'chan'}.";
		};

		/^!lock/ and return eval
		{
			$self->data->{'lock'} = 1;
			return "Database locked.";
		};

		/^!unlock/ and return eval
		{
			$self->data->{'lock'} = undef;
			return "Database unlocked.";
		};

		/^!depth\s+(\d+)/ and return eval
		{
			$self->relate->{'depth'} = $1;
			return "Depth set to @{[$self->relate->depth]}.";
		};

      /^!goaway now/ and die "$nick told me to die.\n";
	}

	return "";
}

### Handlers ###

sub on_connect
{
	my $bot = shift;

	$bot->join($self->{'chan'}) and mlog "Bot joined channel $self->{'chan'}\n";

	$bot->privmsg(nickserv, "identify 12121212");
}

sub quit
{
	my $bot = shift;

	mlog "Disconnected.\n";

	$bot->quit;
}

sub restart
{
	my $bot = shift;

	$bot->quit;

	mlog "Bot Restarted!\n";

	$bot->start;
}

sub on_nick_taken
{
	my $bot = shift;

	$bot->nick("teh_borg");
	mlog "Changed nick.\n";
}

sub reopen
{
	my $self = shift;

	{
		mlog "Opening connection to $self->{'serv'}...\n";

		$self->{'conn'} = $self->irc->newconn(
														  Server   => $self->serv,
														  Port     => $self->port,
														  Nick     => $self->name,
														  Ircname  => $self->name,
														  Username => $self->user,
														 );

		$self->{'conn'} and next;

		mlog "Can't connect, retrying...\n";

		sleep(15);

		redo;
	}
}

sub on_version
{
	my ($bot, $event) = @_;
	my $nick = $event->nick;
	$bot->ctcp_reply($nick, "VERSION Angband 3.0");
}

sub on_kick
{
	my $bot = shift;

	sleep(5 + rand(5));

#	$self->{'delay'} += 10 unless $self->{'shutup'} ;
#	$self->{'lurk'} *= 2 unless $self->{'shutup'} ;

	$bot->join($self->{'chan'});
}

sub on_join
{
	my $random = 0;

	$random = int rand (2);

	if ($random = 1) {
		my ($bot, $event) = @_;

		my $nick = $event->nick;

		return if $self->{'shutup'} ;

		sleep(6);

		paste($bot, $self->{'chan'}, $self->relate->construct("$nick is here!", 0, 1));
	}
}

sub on_public
{
	my $rand = 0;

	$rand = int rand (2);

	if ($rand = 1) {
		my ($bot, $event) = @_;

		my $nick = $event->nick;
		my $arg = ($event->args)[0];
		my $line;

		return if ${$self->{'ignore'}}{lc $nick} ;

		mlog "<$nick> $arg\n";
		$bot->privmsg($self->{'owner'}, "<$nick> $arg") if $self->{'peek'} ;

		paste($bot, $self->{'chan'}, do_command($bot, $event)) and return if $arg =~ s/^!//;

		if ($arg =~ /^(\S+)\S+\s/ and ${$self->{'abbr'}}{lc $1})
		{
			$arg =~ s/^\S+//;
			$line = $self->relate->construct($arg, 0, 1) or return;
		}
		else
		{
			$line = $self->relate->construct($arg, 0, $self->react) or return;
		}

		sleep(4);

		paste($bot, $self->{'chan'}, $line, $self->{'peek'});

		open(FILEZ, ">/home/borg/last");
			print FILEZ $line;
		close (FILEZ);
	}
}

sub on_msg
{
	sleep(4);
	my ($bot, $event) = @_;

	my $arg = ($event->args)[0];
	my $nick = $event->nick;

	return if ${$self->{'ignore'}}{lc $nick} ;

	mlog "<$nick> $arg\n";

	$bot->privmsg($self->{'owner'}, "<$nick> $arg") unless lc($nick) eq lc($self->{'owner'});

	paste($bot, $nick, do_command($bot, $event), 1) and return if $arg =~ /^!/;

	if ($arg =~ /^(\S+)\S+\s/ and ${$self->{'abbr'}}{lc $1})
	{
		$arg =~ s/^\S+//;
		$line = $self->relate->construct($arg, 0, 1) or return;
	}
	else
	{
		$line = $self->relate->construct($arg, 0, 1) or return;
	}

	paste($bot, $nick, $line, 1);
}

sub on_action
{
	my ($bot, $event) = @_;

	my $nick = $event->nick;
	my $arg = join ' ', $event->args;

	$arg =~ s/ACTION\s+//;

	return if ${$self->{'ignore'}}{lc $nick} ;

	mlog "* $nick $arg\n";
	$bot->privmsg($self->{'owner'}, "* $nick $arg") if $self->{'peek'} ;

	paste($bot, $self->{'chan'}, $self->relate->construct($arg, 1, $self->react), $self->{'peek'});
}


sub bot
{
	$self = shift;

	$self->irc->start;
}

sub init
{
	my $self = shift;

	$self->reopen;

	$self->conn->add_handler('msg',    \&on_msg);
	$self->conn->add_handler('public', \&on_public);
	$self->conn->add_handler('caction', \&on_action);
	$self->conn->add_handler('join', \&on_join);

	$self->conn->add_global_handler('kick', \&on_kick);
	$self->conn->add_global_handler('cversion', \&on_version);
	$self->conn->add_global_handler('disconnect', \&on_disconnect);
	$self->conn->add_global_handler(376, \&on_connect);
	$self->conn->add_global_handler(433, \&on_nick_taken);
}


my %data = (
				"owner"  => undef,

				"delay"  => undef,
				"lurk"   => undef,
				"relate" => undef,
				"data"   => undef,

				"name"   => undef,
				"abbr"   => undef,
				"ignore" => undef,
				"master" => undef,

				"serv"   => undef,
				"port"   => undef,
				"user"   => undef,
				"chan"   => undef,

				"shutup" => undef,
            "peek"   => undef,

				"irc"    => undef,
				"conn"   => undef,

				"time"   => undef,
			  );


sub new
{
	my $type = shift;
	my $class = ref($type) || $type;
	my $self = bless {%data}, $class;

	$self->{'owner'} = shift;

	$self->{'delay'} = shift;
	$self->{'lurk'} = shift;
	$self->{'relate'} = shift;
	$self->{'data'} = shift;

	$self->{'name'} = shift;
	$self->{'abbr'} = shift;
	$self->{'ignore'} = shift;
	$self->{'master'} = shift;

	$self->{'serv'} = shift;
	$self->{'port'} = shift;
	$self->{'user'} = shift;
	$self->{'chan'} = shift;

	$self->{'shutup'} = shift;
	$self->{'peek'} = shift;

	$self->{'irc'} = new Net::IRC;

	$self->{'time'} = time;

	$self->{'abbr'}->{$self->{'name'}} = 1;

	$self->init;

	return $self;
}


sub on_disconnect
{
	$self->irc->removeconn($self->{'conn'});

	mlog "Disconnected.\n";

   $self->init;
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

