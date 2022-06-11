#!/usr/bin/env perl

use utf8;
use warnings;
use strict;
use LWP::Simple qw<get $ua>;
use Term::ReadLine;
use Term::ReadKey;
use Switch;

use feature 'state';
use experimental 'smartmatch';

my $height = qx[tput lines];
my $width = qx[tput cols];

binmode(STDOUT, ':utf8');

$ua->agent("Firefox (jk lol im scraping your website)");

sub torrents {
	my @result;
	my $content = shift;
	while($content =~ m#<a href="/?torrent/(\d+)" title="([^"]+)" [^>]*>.*?</a>.<div class="poid">([^<]+)</div>.<div class="up"><span class="seed_ok">(\d+)</span></div>.<div class="down">(\d+)</div></td>#sg) {
		push @result, [$1, $2, $3, $4, $5];
	}
	return @result
}

my $content = get('https://cpasbien.ch');
die 'oh no, can\'t access teh website ;(' unless defined $content;

my $cur = 0;
my $query = '';
my @torrents = torrents $content;
my $link = 'Uhm?';

# modes:
#  0 = default
#  1 = fetch link
#  2 = show link
#  3 = search
my $mode = 0;

my @bottommessage = (
	sub {
		my $cur = $cur + 1;
		my $totaltorrents = $#torrents + 1;
		return "$cur/$totaltorrents, press space to get link, / for search";
	},
	sub {
		$|++;
		my $s = "Fetching link..."; 
		my $w = ' ' x ($width - length$s);
		print "$s$w";
		my $id = $torrents[$cur]->[0];
		my $linkpage = "https://cpasbien.ch/torrent/$id";
		get($linkpage) =~ /telecharger\/[^']+/;
		$link = "https://cpasbien.ch/" . $&;
		return "\x1b[0GPress t to open with Transmission, c to copy magnet link, s to show"
	},
	sub {
		return $link;
	},
	sub {
		ReadMode 0;
		my $term = new Term::ReadLine 'search';
		$query = $term->readline('Search: ');
		print "\x1b[1A\x1b[2K\x1b[0GSearching $query...\x1b[1A";
		ReadMode 3;
		return ''
	}
);

sub search {
	my $query = shift;
	my $content = get('https://cpasbien.ch/recherche/'.$query);
	die 'oh no, can\'t access teh website ;(' unless defined $content;
	@torrents = torrents $content;
	$mode = 0;
	my $f = 'printtorrents';
	\&{$f};
}

sub printtorrents {
	print "\x1b[H\x1b[2J";
	my $i = 0;
	foreach(@torrents) {
		if($i ~~ [$cur..$cur+$height-1]) {
			my @torrent = @$_;
			my ($id, $title, $size, $seed, $leech) = @torrent;
			$cur == $i ? print '> ' : print '  ';

			my $left = substr($title, 0, int($width/2));
			my $right = "$size  S $seed  L $leech";
			my $goodlookingright = "\x1b[1m$size\x1b[0m  S \x1b[1m$seed\x1b[0m  L \x1b[1m$leech\x1b[0m";
			my $spacing = ' ' x ($width - (length $left) - (length $right) - 2);
			print $left . $spacing . $goodlookingright . $/;
		}
		$i++
	}
	my $s = $bottommessage[$mode]->();
	my $w = ' ' x ($width - length$s);
	print "\x1b[$height;0H$s$w";
	if($mode == 3) {
		search $query;
	}
}

printtorrents;

ReadMode 3;
for(;;) {
	switch(my $key = ReadKey(0)) {
		if($mode == 2) { $mode = 0; }
		if($mode == 0) {
			case 'j' {
				if($cur <= $#torrents-1) {
					$cur++;
					printtorrents;
				}
			}
			case 'k' {
				if($cur > 0) {
					$cur--;
					printtorrents;
				}
			}
			case ' ' {
				$mode = 1;
				printtorrents;
			}
			case '/' {
				$mode = 3;
				printtorrents;
			}
		} elsif($mode == 1) {
			case 's' {
				$mode = 2;
				printtorrents;
			}
			case 't' {
				`transmission-gtk $link`
			}
			case 'c' {
				`printf %s "$link" | wl-copy`
			}
			$mode = 0;
		}
		case 'q' { exit }
	};
}
ReadMode 0;
