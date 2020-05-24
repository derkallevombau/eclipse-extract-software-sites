#!/usr/bin/perl

# Author: derkallevombau
# Created 2020-05-17 15:37:19

use strict;
use warnings;

use File::Spec::Functions qw(catfile splitpath);
use List::Util 'first';

my $InFileName = 'org.eclipse.equinox.p2.artifact.repository.prefs';
my $OutFileName = 'eclipse-bookmarks.xml';

my ($InFilePath, $OutFilePath);

my $DontPromptForOverwrite = '';

sub getHelpString()
{
	my (undef, undef, $script) = splitpath(__FILE__);

"Usage: $script [OPTION]...\n\n" .
"Options:\n" .
" -i, --in\tLocation of '$InFileName'\n" .
"\t\t('<eclipse dir>/p2/org.eclipse.equinox.p2.engine/profileRegistry\n" .
"\t\t/<profile>/.data/.settings/') or full path of file to read from.\n" .
"\t\tIf omitted, '$InFileName'\n" .
"\t\tmust be in cwd.\n" .
" -o, --out\tLocation to place '$OutFileName' or full path of file\n" .
"\t\tto write to.\n" .
"\t\tIf omitted, output will be written to '$OutFileName'\n" .
"\t\tin cwd.\n" .
" -y, --yes\tDon't ask whether to overwrite an existing output file.\n" .
" -h, --help\tPrint this help.\n";
}

sub dieWithHelp { die("$_[0]\n\n" . getHelpString()); }

## Prompting functions

# Supports only what we need here.
# I know about Curses and Term::ANSIScreen modules,
# but I want to avoid external dependencies.
sub tput
{
	my (@capnames) = @_;

	# Example: 'tput sc | xxd' -> '1b37   .7', 'echo -en "\e" | xxd -p' -> '1b'.
	# => sc is "\e7".
	my %AnsiCodeFromCapname =
	(
		sc => "\e7",  # Save cursor pos
		rc => "\e8",  # Restore cursor pos
#		cr => "\x0d", # Carriage return
		el => "\e[K"  # Clear to end of line
	);

	my $codes = join('', map { $AnsiCodeFromCapname{$_} } @capnames);

	print($codes);
}

sub prompt
{
	my ($promptString, @choices) = @_;

	my $invalidChoice = first { length != 1 } @choices;

	croak("prompt(): Invalid choice: '$invalidChoice'. Please provide single chars only. Exiting.") if $invalidChoice;

	my $defaultChoice    = first { /^[A-Z]$/ } @choices;
	my $choicesPromptStr = join('/', @choices);
	my $choicesRE        = '^(?:|[' . join('', map { (lcfirst, ucfirst) } @choices) . '])$';
	   $choicesRE        = qr/$choicesRE/;

	my $ans;

	print($promptString . " [$choicesPromptStr] ");
	tput('sc');

	while (1)
	{
		chomp($ans = <STDIN>);

		if ($ans =~ $choicesRE)
		{
			print("\n");

			$ans = $defaultChoice if $ans eq '';

			return lcfirst($ans);
		}
		else
		{
			tput('rc', 'el');
		}
	}
}

sub promptForOverwriteAndExitIfDeclined
{
	return if $DontPromptForOverwrite;

	my ($path) = @_;

	my $ans = prompt("Overwrite '$path'?", 'y', 'N');

	if ($ans eq 'n')
	{
		print("Aborted.\n");
		exit;
	}
}

## Process command line args, if any.

if (@ARGV && $ARGV[0] =~ /--?h(?:elp)?/)
{
	print(getHelpString());
	exit;
}

if (@ARGV && $ARGV[0] =~ /--?y(?:es)?/)
{
	$DontPromptForOverwrite = 1;
	shift(@ARGV);
}

for (my $i = 0; $i + 1 < @ARGV; $i += 2)
{
	my ($opt, $arg) = @ARGV[$i, $i + 1];

	if ($opt =~ /--?in?/)
	{
		# $arg must be an existing dir or file.
		dieWithHelp("$opt: '$arg' doesn't exist, exiting.") unless -e $arg;

		if (-d $arg) # Got a dir => Append standard input file name and check if file exists.
		{
			$InFilePath = catfile($arg, $InFileName);

			dieWithHelp("$opt: No '$InFileName' found in '$arg', exiting.") unless -f $InFilePath;
		}
		else # $arg is an existing file.
		{
			$InFilePath = $arg;
		}
	}
	elsif ($opt =~ /--?o(?:ut)?/)
	{
		if (-d $arg) # Got a dir => Append standard output file name and check if file exists.
		{
			$OutFilePath = catfile($arg, $OutFileName);

			promptForOverwriteAndExitIfDeclined($OutFilePath);
		}
		else # Got a full path.
		{
			$OutFilePath = $arg;

			if (-f $OutFilePath) # $OutFilePath is an existing file, ask user what to do.
			{
				promptForOverwriteAndExitIfDeclined($OutFilePath);
			}
			else # Check if parent dir exists.
			{
				my (undef, $dir, $file) = splitpath($OutFilePath);

				$file = $OutFileName unless $file;

				die("Cannot write to '$file' in non-existing dir '$dir', exiting.\n") unless -e $dir;
			}
		}
	}
}

$InFilePath  //= $InFileName;
$OutFilePath //= $OutFileName;

my $CR = "\N{CR}"; # Auto-loads charnames module.
my $LF = "\N{LF}";

my %SiteFromRepo;
my @Sites;
my @InFileLines;
my $WriteInFile = '';

## Extract sites from input file

print("Processing '$InFilePath'...\n\n");

open(my $fh, '<', $InFilePath) or die("Could not open file '$InFilePath' for read, exiting.\n");
{
	# Process file without assuming it uses the line terminator of the OS
	# under which this script runs.

	# Line terminator is either $LF or $CR$LF.
	# Since both end in $LF, we set the Input Record Separator to $LF.
	# It defaults to \n, but the actual definition of \n depends on the OS,
	# so we cannot assume \n to be equal to $LF.
	local $/ = $LF;

	while (<$fh>)
	{
		# Check for invalid line.

		my $pushLine = 1;

		unless (m{^eclipse.preferences.version=|^repositories/})
		{
			if ($WriteInFile)
			{
				print('F');
			}
			else
			{
				print('File seems to be corrupted; f');
			}

			print("ound invalid data:\n\nLine $.: $_\n");

			if (prompt('Do you want me to remove this line?', 'Y', 'n') eq 'y')
			{
				$pushLine = '';
				$WriteInFile = 1;
			}
		}

		push(@InFileLines, $_) if $pushLine;

		# Remove the line terminator.
		s/$CR?$LF//;

		# Only process lines specifying 'nickname', 'uri' or 'enabled' of a http[s] repo.
		# The nickname may be empty.
		my $propNameCapture = qr/(nickname(?==.*)|(?:uri|enabled)(?==.+))/;
		my ($repo, $propName) = m{^repositories/(http.+?)/$propNameCapture};
		next if !$repo || !$propName;

		my ($propValue) = m{^repositories/http.+?/$propName=(.*)};

		# Remove the backslash after http[s] if we have an uri.
		$propValue =~ s/\\// if $propName eq 'uri';

		# $repo is used merely to collect props belonging together.
		$SiteFromRepo{$repo}->{$propName} = $propValue;
	}
}
close ($fh);

undef $fh;

if ($WriteInFile)
{
	open(my $fh, '>', $InFilePath) or die("Could not open file '$InFilePath' for write, exiting.\n");

	# This is NOT a "Useless use of $_"!
	# We get an empty file without it.
	$fh->print($_) for @InFileLines;

	close($fh);
}

print("Extracted sites:\n\n");

for my $site (values %SiteFromRepo)
{
	# There are many entries without a nickname.
	# These are not from "Available Software Sites", so skip them.
	next unless exists $site->{nickname};

	print("nickname:\t$site->{nickname}\nuri:\t\t$site->{uri}\nenabled:\t$site->{enabled}\n\n");

	push(@Sites, $site);
}

undef %SiteFromRepo;

## Write XML file

print("Writing bookmarks to '$OutFilePath'...\n");

open($fh, '>:utf8', $OutFilePath) or die("Could not open file '$OutFilePath' for write, exiting.\n");

$fh->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<bookmarks>\n");
$fh->print("   <site url=\"$_->{uri}\" selected=\"$_->{enabled}\" name=\"$_->{nickname}\"/>\n") for @Sites;
$fh->print('</bookmarks>');

close($fh);

print("\nDone.\n");
